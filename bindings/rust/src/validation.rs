//! Structured, non-executing Cypher validation results.

use serde::Deserialize;

/// One syntax or static-semantic diagnostic returned by query validation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValidationDiagnostic {
    /// Stable extension error code, such as `PARSE_ERROR` or `VALIDATION_ERROR`.
    pub code: String,
    /// Human-readable explanation, including expected tokens for parse failures.
    pub message: String,
    /// One-based source line when the parser can identify it.
    pub line: Option<u32>,
    /// One-based source column when the parser can identify it.
    pub column: Option<u32>,
}

/// Result of validating a Cypher query without executing it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValidationResult {
    /// Whether parsing and static semantic validation succeeded.
    pub valid: bool,
    /// The first diagnostic, if validation failed.
    pub diagnostic: Option<ValidationDiagnostic>,
}

#[derive(Deserialize)]
struct WireValidationResult {
    valid: bool,
    #[serde(default)]
    error: Option<String>,
    #[serde(default)]
    code: Option<String>,
    #[serde(default)]
    line: Option<u32>,
    #[serde(default)]
    column: Option<u32>,
}

impl ValidationResult {
    pub(crate) fn from_json(json: &str) -> serde_json::Result<Self> {
        let wire: WireValidationResult = serde_json::from_str(json)?;
        let diagnostic = wire.error.map(|message| ValidationDiagnostic {
            code: wire.code.unwrap_or_else(|| {
                if wire.line.is_some() {
                    "PARSE_ERROR".to_string()
                } else {
                    "VALIDATION_ERROR".to_string()
                }
            }),
            message,
            line: wire.line,
            column: wire.column,
        });
        Ok(Self {
            valid: wire.valid,
            diagnostic,
        })
    }
}
