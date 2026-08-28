//! GraphQLite connection wrapper.

use crate::query_builder::CypherQuery;
use crate::{CypherResult, Error, Result};

#[cfg(feature = "parity-spy")]
use std::cell::RefCell;
use std::path::Path;
#[cfg(not(feature = "bundled-extension"))]
use std::path::PathBuf;

/// A GraphQLite database connection.
///
/// Wraps a SQLite connection with the GraphQLite extension loaded,
/// providing Cypher query support.
pub struct Connection {
    conn: rusqlite::Connection,
    /// Cypher recording sink used only by the parity harness (issue #84).
    ///
    /// `None` unless [`Connection::parity_start_recording`] has been called.
    /// This field (and every method that touches it) only exists under the
    /// off-by-default `parity-spy` feature, so normal builds are unaffected.
    #[cfg(feature = "parity-spy")]
    recorder: RefCell<Option<Vec<serde_json::Value>>>,
}

impl Connection {
    /// Wrap a raw rusqlite connection into a `Connection`.
    ///
    /// Centralizes struct construction so the parity-spy `recorder` field is
    /// initialized in exactly one place. Under the default (no `parity-spy`)
    /// build this compiles down to the original `Connection { conn }` literal.
    #[cfg(feature = "parity-spy")]
    fn wrap(conn: rusqlite::Connection) -> Self {
        Connection {
            conn,
            recorder: RefCell::new(None),
        }
    }

    #[cfg(not(feature = "parity-spy"))]
    fn wrap(conn: rusqlite::Connection) -> Self {
        Connection { conn }
    }

    /// Begin recording every Cypher query (+ params) this connection emits.
    ///
    /// Only available under the `parity-spy` feature; used by the parity
    /// harness's cypher mode. Resets any prior recording buffer.
    #[cfg(feature = "parity-spy")]
    pub fn parity_start_recording(&self) {
        *self.recorder.borrow_mut() = Some(Vec::new());
    }

    /// Take (and clear) the recorded Cypher calls captured since recording
    /// started or since the last take. Recording stays active. Returns an
    /// empty vec if recording was never started.
    #[cfg(feature = "parity-spy")]
    pub fn parity_take_recording(&self) -> Vec<serde_json::Value> {
        let mut guard = self.recorder.borrow_mut();
        match guard.as_mut() {
            Some(buf) => std::mem::take(buf),
            None => Vec::new(),
        }
    }

    /// Push one `{query, params}` record onto the recording buffer if active.
    /// Whitespace in the query is normalized the same way as the TS/Python
    /// spies (`normWs`: collapse runs of whitespace, trim).
    #[cfg(feature = "parity-spy")]
    fn parity_record(&self, query: &str, params: Option<&serde_json::Value>) {
        if let Some(buf) = self.recorder.borrow_mut().as_mut() {
            buf.push(serde_json::json!({
                "query": parity_norm_ws(query),
                "params": params.cloned().unwrap_or(serde_json::Value::Null),
            }));
        }
    }

    /// Open a database at the given path.
    ///
    /// # Arguments
    ///
    /// * `path` - Path to database file, or ":memory:" for in-memory database
    ///
    /// # Example
    ///
    /// ```no_run
    /// use graphqlite::Connection;
    ///
    /// let conn = Connection::open(":memory:")?;
    /// # Ok::<(), graphqlite::Error>(())
    /// ```
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let conn = rusqlite::Connection::open(path)?;
        Self::from_rusqlite(conn)
    }

    /// Open an in-memory database.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use graphqlite::Connection;
    ///
    /// let conn = Connection::open_in_memory()?;
    /// # Ok::<(), graphqlite::Error>(())
    /// ```
    pub fn open_in_memory() -> Result<Self> {
        let conn = rusqlite::Connection::open_in_memory()?;
        Self::from_rusqlite(conn)
    }

    /// Create a GraphQLite connection from an existing rusqlite Connection.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use graphqlite::Connection;
    /// use rusqlite;
    ///
    /// let sqlite_conn = rusqlite::Connection::open_in_memory()?;
    /// let conn = Connection::from_rusqlite(sqlite_conn)?;
    /// # Ok::<(), graphqlite::Error>(())
    /// ```
    #[cfg(feature = "bundled-extension")]
    pub fn from_rusqlite(conn: rusqlite::Connection) -> Result<Self> {
        // Load the bundled extension (extracts from embedded binary)
        crate::platform::load_bundled_extension(&conn)?;
        Ok(Self::wrap(conn))
    }

    /// Create a GraphQLite connection from an existing rusqlite Connection.
    #[cfg(not(feature = "bundled-extension"))]
    pub fn from_rusqlite(conn: rusqlite::Connection) -> Result<Self> {
        let extension_path = find_extension()?;
        load_extension(&conn, &extension_path)?;
        Ok(Self::wrap(conn))
    }

    /// Create a connection with a custom extension path.
    ///
    /// # Arguments
    ///
    /// * `path` - Path to database file
    /// * `extension_path` - Path to the GraphQLite extension (.dylib, .so, or .dll)
    ///
    /// Note: This method is only available when the `bundled-extension` feature is disabled.
    #[cfg(not(feature = "bundled-extension"))]
    pub fn open_with_extension<P: AsRef<Path>, E: AsRef<std::path::Path>>(
        path: P,
        extension_path: E,
    ) -> Result<Self> {
        let conn = rusqlite::Connection::open(path)?;
        load_extension(&conn, extension_path.as_ref())?;
        Ok(Self::wrap(conn))
    }

    /// Execute a Cypher query.
    ///
    /// # Arguments
    ///
    /// * `query` - Cypher query string
    ///
    /// # Returns
    ///
    /// A `CypherResult` containing the query results.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use graphqlite::Connection;
    ///
    /// let conn = Connection::open_in_memory()?;
    /// conn.cypher("CREATE (n:Person {name: 'Alice'})")?;
    /// let results = conn.cypher("MATCH (n:Person) RETURN n.name")?;
    /// # Ok::<(), graphqlite::Error>(())
    /// ```
    pub fn cypher(&self, query: &str) -> Result<CypherResult> {
        #[cfg(feature = "parity-spy")]
        self.parity_record(query, None);

        let result: Option<String> = self
            .conn
            .query_row("SELECT cypher(?1)", [query], |row| row.get(0))?;

        match result {
            Some(json_str) => {
                // Check for error response (legacy prefix or structured JSON)
                if json_str.starts_with("Error") || json_str.starts_with("{\"error\"") {
                    return Err(parse_structured_error(&json_str));
                }
                CypherResult::from_json(&json_str)
            }
            None => Ok(CypherResult::empty()),
        }
    }

    /// Execute a Cypher query with named parameters.
    ///
    /// Parameters are passed as a JSON object and bound inside the extension,
    /// preventing injection and eliminating the need for manual escaping.
    ///
    /// # Arguments
    ///
    /// * `query` - Cypher query string with `$param` placeholders
    /// * `params` - Parameter values as a `serde_json::Value` (must be an object)
    ///
    /// # Example
    ///
    /// ```no_run
    /// use graphqlite::Connection;
    /// use serde_json::json;
    ///
    /// let conn = Connection::open_in_memory()?;
    /// conn.cypher("CREATE (n:Person {name: 'Alice', age: 30})")?;
    /// let results = conn.cypher_with_params(
    ///     "MATCH (n:Person) WHERE n.name = $name RETURN n.name, n.age",
    ///     &json!({"name": "Alice"})
    /// )?;
    /// # Ok::<(), graphqlite::Error>(())
    /// ```
    #[deprecated(since = "0.4.0", note = "Use cypher_builder() instead")]
    pub fn cypher_with_params(
        &self,
        query: &str,
        params: &serde_json::Value,
    ) -> Result<CypherResult> {
        self.execute_cypher_with_params(query, params)
    }

    /// Internal: execute a parameterized Cypher query.
    pub(crate) fn execute_cypher_with_params(
        &self,
        query: &str,
        params: &serde_json::Value,
    ) -> Result<CypherResult> {
        #[cfg(feature = "parity-spy")]
        self.parity_record(query, Some(params));

        let params_json = serde_json::to_string(params)
            .map_err(|e| Error::Cypher(format!("Failed to serialize params: {}", e)))?;
        let result: Option<String> = self.conn.query_row(
            "SELECT cypher(?1, ?2)",
            rusqlite::params![query, params_json],
            |row| row.get(0),
        )?;

        match result {
            Some(json_str) => {
                if json_str.starts_with("Error") || json_str.starts_with("{\"error\"") {
                    return Err(parse_structured_error(&json_str));
                }
                CypherResult::from_json(&json_str)
            }
            None => Ok(CypherResult::empty()),
        }
    }

    /// Create a builder for a parameterized Cypher query.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use graphqlite::Connection;
    ///
    /// let conn = Connection::open_in_memory()?;
    /// conn.cypher("CREATE (n:Person {name: 'Alice', age: 30})")?;
    /// let results = conn.cypher_builder("MATCH (n:Person) WHERE n.name = $name RETURN n")
    ///     .param("name", "Alice")
    ///     .run()?;
    /// # Ok::<(), graphqlite::Error>(())
    /// ```
    pub fn cypher_builder<'a>(&'a self, query: &'a str) -> CypherQuery<'a> {
        CypherQuery::new(self, query)
    }

    /// Execute raw SQL.
    ///
    /// Useful for queries that don't use Cypher, like checking schema
    /// or using algorithm results with `json_each()`.
    pub fn execute(&self, sql: &str) -> Result<usize> {
        Ok(self.conn.execute(sql, [])?)
    }

    /// Access the underlying rusqlite connection.
    pub fn sqlite_connection(&self) -> &rusqlite::Connection {
        &self.conn
    }
}

/// Find the GraphQLite extension library.
#[cfg(not(feature = "bundled-extension"))]
fn find_extension() -> Result<PathBuf> {
    let ext_name = if cfg!(target_os = "macos") {
        "graphqlite.dylib"
    } else if cfg!(target_os = "windows") {
        "graphqlite.dll"
    } else {
        "graphqlite.so"
    };

    // Search paths in order of preference
    let search_paths: Vec<PathBuf> = vec![
        // Environment variable
        std::env::var("GRAPHQLITE_EXTENSION_PATH")
            .ok()
            .map(PathBuf::from)
            .unwrap_or_default(),
        // Current directory build
        PathBuf::from("build").join(ext_name),
        // Relative to crate root (for development)
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap_or(Path::new("."))
            .parent()
            .unwrap_or(Path::new("."))
            .join("build")
            .join(ext_name),
        // System paths
        PathBuf::from("/usr/local/lib").join(ext_name),
        PathBuf::from("/usr/lib").join(ext_name),
    ];

    for path in search_paths {
        if path.exists() {
            return Ok(path);
        }
    }

    Err(Error::ExtensionNotFound(format!(
        "Could not find {}. Build with 'make extension' or set GRAPHQLITE_EXTENSION_PATH",
        ext_name
    )))
}

/// Load the GraphQLite extension into a connection.
#[cfg(not(feature = "bundled-extension"))]
fn load_extension(conn: &rusqlite::Connection, path: &std::path::Path) -> Result<()> {
    // Remove the file extension for SQLite's load_extension
    let load_path = path.with_extension("");

    unsafe {
        conn.load_extension_enable()?;
        // `None` needs an explicit type since rusqlite 0.39 made the entry-point
        // parameter generic (`Option<N: Name>`); `Option<&str>` = "default entry
        // point", identical to the pre-0.39 behavior. Without this the
        // `--no-default-features` build fails to infer the type parameter.
        conn.load_extension(&load_path, None::<&str>)?;
        conn.load_extension_disable()?;
    }

    // Verify the extension loaded
    let test: String = conn.query_row("SELECT graphqlite_test()", [], |row| row.get(0))?;
    if !test.to_lowercase().contains("successfully") {
        return Err(Error::ExtensionNotFound(
            "Extension loaded but verification failed".to_string(),
        ));
    }

    Ok(())
}

/// Parse a structured JSON error from the extension into an Error.
/// Handles both structured `{"error":"msg","code":"CODE"}` and legacy `"Error: msg"` formats.
fn parse_structured_error(s: &str) -> Error {
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(s) {
        if let Some(msg) = v.get("error").and_then(|e| e.as_str()) {
            return Error::Cypher(msg.to_string());
        }
    }
    Error::Cypher(s.to_string())
}

/// Normalize whitespace the same way the TS/Python parity spies do
/// (`normWs`: collapse every run of whitespace to a single space and trim).
#[cfg(feature = "parity-spy")]
fn parity_norm_ws(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(not(feature = "bundled-extension"))]
    fn get_test_extension_path() -> Option<std::path::PathBuf> {
        let paths = [
            std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .parent()
                .unwrap()
                .parent()
                .unwrap()
                .join("build/graphqlite.dylib"),
            std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .parent()
                .unwrap()
                .parent()
                .unwrap()
                .join("build/graphqlite.so"),
        ];

        paths.into_iter().find(|p| p.exists())
    }

    #[test]
    #[cfg(not(feature = "bundled-extension"))]
    fn test_find_extension() {
        // This test may skip if extension isn't built
        if get_test_extension_path().is_none() {
            return;
        }
        assert!(find_extension().is_ok());
    }

    #[test]
    #[cfg(feature = "bundled-extension")]
    fn test_bundled_connection() {
        // Test that bundled extension works
        let conn = Connection::open_in_memory();
        assert!(conn.is_ok(), "Failed to open connection: {:?}", conn.err());
    }
}
