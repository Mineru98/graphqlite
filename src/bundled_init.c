/*
 * GraphQLite Bundled Initialization
 *
 * This file provides initialization for statically linked builds
 * (e.g., Rust bindings with bundled SQLite). Unlike extension.c,
 * this doesn't use the SQLite extension API pointer mechanism.
 */

#include <sqlite3.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <regex.h>

/* Include internal headers - these use graphqlite_sqlite.h which
 * will include sqlite3.h since GRAPHQLITE_EXTENSION is not defined */
#include "executor/cypher_schema.h"
#include "executor/cypher_executor.h"
#include "executor/agtype.h"
#include "executor/graph_algorithms.h"
#include "parser/cypher_parser.h"

/* Error codes for structured error responses */
#define GQL_ERR_VALIDATION    "VALIDATION_ERROR"
#define GQL_ERR_PARSE         "PARSE_ERROR"
#define GQL_ERR_EXECUTION     "EXECUTION_ERROR"
#define GQL_ERR_MEMORY        "MEMORY_ERROR"
#define GQL_ERR_INTERNAL      "INTERNAL_ERROR"
#define GQL_ERR_NOT_IMPL      "NOT_IMPLEMENTED"

/* Return a structured JSON error via sqlite3_result_error.
 * Format: {"error": "message", "code": "ERROR_CODE"} */
static void graphqlite_result_error(sqlite3_context *context, const char *message, const char *code) {
    char buf[1024];
    snprintf(buf, sizeof(buf), "{\"error\":\"%s\",\"code\":\"%s\"}", message, code);
    sqlite3_result_error(context, buf, -1);
}

/* Per-connection executor cache structure */
typedef struct {
    sqlite3 *db;
    cypher_executor *executor;
    csr_graph *cached_graph;  /* Cached CSR graph for algorithm acceleration */
} bundled_connection_cache;

/* Destructor called when database connection closes */
static void bundled_connection_cache_destroy(void *data) {
    bundled_connection_cache *cache = (bundled_connection_cache *)data;
    if (cache) {
        if (cache->cached_graph) {
            csr_graph_free(cache->cached_graph);
        }
        if (cache->executor) {
            cypher_executor_free(cache->executor);
        }
        free(cache);
    }
}

/* Simple test function */
static void bundled_test_func(sqlite3_context *context, int argc, sqlite3_value **argv) {
    (void)argc;
    (void)argv;
    sqlite3_result_text(context, "GraphQLite extension loaded successfully!", -1, SQLITE_STATIC);
}

/* gql_load_graph() - Build CSR from SQLite and cache in connection memory */
static void bundled_load_graph_func(sqlite3_context *context, int argc, sqlite3_value **argv) {
    (void)argc;
    (void)argv;

    bundled_connection_cache *cache = (bundled_connection_cache *)sqlite3_user_data(context);
    if (!cache) {
        graphqlite_result_error(context, "No connection cache available", GQL_ERR_INTERNAL);
        return;
    }

    sqlite3 *db = sqlite3_context_db_handle(context);

    /* If already loaded, return current stats */
    if (cache->cached_graph) {
        char response[256];
        snprintf(response, sizeof(response),
                 "{\"status\":\"already_loaded\",\"nodes\":%d,\"edges\":%d}",
                 cache->cached_graph->node_count,
                 cache->cached_graph->edge_count);
        sqlite3_result_text(context, response, -1, SQLITE_TRANSIENT);
        return;
    }

    /* Load graph from SQLite */
    csr_graph *graph = csr_graph_load(db);
    if (!graph) {
        sqlite3_result_text(context, "{\"status\":\"loaded\",\"nodes\":0,\"edges\":0}", -1, SQLITE_STATIC);
        return;
    }

    /* Cache the graph */
    cache->cached_graph = graph;

    /* Also update executor if it exists */
    if (cache->executor) {
        cache->executor->cached_graph = graph;
    }

    char response[256];
    snprintf(response, sizeof(response),
             "{\"status\":\"loaded\",\"nodes\":%d,\"edges\":%d}",
             graph->node_count, graph->edge_count);
    sqlite3_result_text(context, response, -1, SQLITE_TRANSIENT);
}

/* gql_unload_graph() - Free cached graph memory */
static void bundled_unload_graph_func(sqlite3_context *context, int argc, sqlite3_value **argv) {
    (void)argc;
    (void)argv;

    bundled_connection_cache *cache = (bundled_connection_cache *)sqlite3_user_data(context);
    if (!cache) {
        graphqlite_result_error(context, "No connection cache available", GQL_ERR_INTERNAL);
        return;
    }

    if (cache->cached_graph) {
        csr_graph_free(cache->cached_graph);
        cache->cached_graph = NULL;

        /* Also clear executor reference */
        if (cache->executor) {
            cache->executor->cached_graph = NULL;
        }

        sqlite3_result_text(context, "{\"status\":\"unloaded\"}", -1, SQLITE_STATIC);
    } else {
        sqlite3_result_text(context, "{\"status\":\"not_loaded\"}", -1, SQLITE_STATIC);
    }
}

/* gql_reload_graph() - Invalidate cache and rebuild from current database state */
static void bundled_reload_graph_func(sqlite3_context *context, int argc, sqlite3_value **argv) {
    (void)argc;
    (void)argv;

    bundled_connection_cache *cache = (bundled_connection_cache *)sqlite3_user_data(context);
    if (!cache) {
        graphqlite_result_error(context, "No connection cache available", GQL_ERR_INTERNAL);
        return;
    }

    sqlite3 *db = sqlite3_context_db_handle(context);

    int prev_nodes = 0, prev_edges = 0;

    /* Free existing cache if present */
    if (cache->cached_graph) {
        prev_nodes = cache->cached_graph->node_count;
        prev_edges = cache->cached_graph->edge_count;
        csr_graph_free(cache->cached_graph);
        cache->cached_graph = NULL;
    }

    /* Load fresh graph from SQLite */
    csr_graph *graph = csr_graph_load(db);
    cache->cached_graph = graph;

    /* Also update executor if it exists */
    if (cache->executor) {
        cache->executor->cached_graph = graph;
    }

    int new_nodes = graph ? graph->node_count : 0;
    int new_edges = graph ? graph->edge_count : 0;

    char response[512];
    snprintf(response, sizeof(response),
             "{\"status\":\"reloaded\",\"previous_nodes\":%d,\"previous_edges\":%d,\"nodes\":%d,\"edges\":%d}",
             prev_nodes, prev_edges, new_nodes, new_edges);
    sqlite3_result_text(context, response, -1, SQLITE_TRANSIENT);
}

/* gql_graph_loaded() - Return cache status */
static void bundled_graph_loaded_func(sqlite3_context *context, int argc, sqlite3_value **argv) {
    (void)argc;
    (void)argv;

    bundled_connection_cache *cache = (bundled_connection_cache *)sqlite3_user_data(context);
    if (!cache) {
        graphqlite_result_error(context, "No connection cache available", GQL_ERR_INTERNAL);
        return;
    }

    if (cache->cached_graph) {
        char response[256];
        snprintf(response, sizeof(response),
                 "{\"loaded\":true,\"nodes\":%d,\"edges\":%d}",
                 cache->cached_graph->node_count,
                 cache->cached_graph->edge_count);
        sqlite3_result_text(context, response, -1, SQLITE_TRANSIENT);
    } else {
        sqlite3_result_text(context, "{\"loaded\":false,\"nodes\":0,\"edges\":0}", -1, SQLITE_STATIC);
    }
}

/* Cypher function - full implementation with cached executor */
static void bundled_cypher_func(sqlite3_context *context, int argc, sqlite3_value **argv) {
    if (argc < 1 || argc > 2) {
        graphqlite_result_error(context, "cypher() requires 1 or 2 arguments: (query) or (query, params_json)", GQL_ERR_VALIDATION);
        return;
    }

    if (sqlite3_value_type(argv[0]) != SQLITE_TEXT) {
        graphqlite_result_error(context, "cypher() first argument (query) must be text", GQL_ERR_VALIDATION);
        return;
    }

    const char *query = (const char*)sqlite3_value_text(argv[0]);
    if (!query) {
        graphqlite_result_error(context, "cypher() query cannot be null", GQL_ERR_VALIDATION);
        return;
    }

    /* Optional parameters JSON */
    const char *params_json = NULL;
    if (argc == 2) {
        if (sqlite3_value_type(argv[1]) == SQLITE_NULL) {
            /* NULL is allowed - treat as no params */
        } else if (sqlite3_value_type(argv[1]) != SQLITE_TEXT) {
            graphqlite_result_error(context, "cypher() second argument (params) must be JSON text or NULL", GQL_ERR_VALIDATION);
            return;
        } else {
            params_json = (const char*)sqlite3_value_text(argv[1]);
        }
    }

    /* Get database connection from SQLite context */
    sqlite3 *db = sqlite3_context_db_handle(context);

    /* Get per-connection cache from user data */
    bundled_connection_cache *cache = (bundled_connection_cache *)sqlite3_user_data(context);
    cypher_executor *executor = NULL;

    if (cache && cache->executor) {
        /* Reuse cached executor for this connection */
        executor = cache->executor;
    } else {
        /* First call - create new executor */
        executor = cypher_executor_create(db);
        if (!executor) {
            graphqlite_result_error(context, "Failed to create cypher executor", GQL_ERR_INTERNAL);
            return;
        }

        /* Cache for reuse */
        if (cache) {
            cache->executor = executor;
        }
    }

    /* Execute query (with or without parameters) */
    cypher_result *result;
    if (params_json) {
        result = cypher_executor_execute_params(executor, query, params_json);
    } else {
        result = cypher_executor_execute(executor, query);
    }
    if (!result) {
        graphqlite_result_error(context, "Failed to execute cypher query", GQL_ERR_EXECUTION);
        return;
    }

    /* Format result based on success/failure */
    if (result->success) {
        if (result->row_count > 0 && result->use_agtype && result->agtype_data) {
            /* Use AGE-compatible format */
            if (result->row_count == 1 && result->column_count == 1) {
                char *agtype_str = agtype_value_to_string(result->agtype_data[0][0]);
                if (agtype_str) {
                    const char *col_name = (result->column_names && result->column_names[0])
                        ? result->column_names[0] : "result";
                    int json_size = strlen(agtype_str) + strlen(col_name) + 32;
                    char *json_result = malloc(json_size);
                    if (json_result) {
                        snprintf(json_result, json_size, "[{\"%s\": %s}]", col_name, agtype_str);
                        sqlite3_result_text(context, json_result, -1, SQLITE_TRANSIENT);
                        free(json_result);
                    } else {
                        sqlite3_result_text(context, agtype_str, -1, SQLITE_TRANSIENT);
                    }
                    free(agtype_str);
                } else {
                    sqlite3_result_text(context, "[{\"result\": null}]", -1, SQLITE_STATIC);
                }
            } else {
                /* Multiple results - return as JSON array */
                size_t buffer_size = 1024;
                for (int row = 0; row < result->row_count; row++) {
                    for (int col = 0; col < result->column_count; col++) {
                        if (result->agtype_data[row][col]) {
                            char *temp_str = agtype_value_to_string(result->agtype_data[row][col]);
                            if (temp_str) {
                                buffer_size += strlen(temp_str) + 20;
                                free(temp_str);
                            }
                        }
                    }
                }

                char *json_result = malloc(buffer_size);
                if (!json_result) {
                    graphqlite_result_error(context, "Memory allocation failed for agtype result formatting", GQL_ERR_MEMORY);
                    cypher_result_free(result);
                    return;
                }
                size_t offset = 0;

                offset += snprintf(json_result + offset, buffer_size - offset, "[");

                for (int row = 0; row < result->row_count; row++) {
                    if (row > 0) offset += snprintf(json_result + offset, buffer_size - offset, ",");

                    if (result->column_count == 1) {
                        offset += snprintf(json_result + offset, buffer_size - offset, "{\"");
                        if (result->column_names && result->column_names[0]) {
                            size_t slen = strlen(result->column_names[0]);
                            if (offset + slen < buffer_size) { memcpy(json_result + offset, result->column_names[0], slen); offset += slen; }
                        } else {
                            offset += snprintf(json_result + offset, buffer_size - offset, "result");
                        }
                        offset += snprintf(json_result + offset, buffer_size - offset, "\":");
                        char *agtype_str = agtype_value_to_string(result->agtype_data[row][0]);
                        if (agtype_str) {
                            size_t slen = strlen(agtype_str);
                            if (offset + slen < buffer_size) { memcpy(json_result + offset, agtype_str, slen); offset += slen; }
                            free(agtype_str);
                        } else {
                            offset += snprintf(json_result + offset, buffer_size - offset, "null");
                        }
                        offset += snprintf(json_result + offset, buffer_size - offset, "}");
                    } else {
                        offset += snprintf(json_result + offset, buffer_size - offset, "{");
                        for (int col = 0; col < result->column_count; col++) {
                            if (col > 0) offset += snprintf(json_result + offset, buffer_size - offset, ",");

                            offset += snprintf(json_result + offset, buffer_size - offset, "\"");
                            if (result->column_names && result->column_names[col]) {
                                size_t slen = strlen(result->column_names[col]);
                                if (offset + slen < buffer_size) { memcpy(json_result + offset, result->column_names[col], slen); offset += slen; }
                            } else {
                                char col_name[32];
                                snprintf(col_name, sizeof(col_name), "column_%d", col);
                                size_t slen = strlen(col_name);
                                if (offset + slen < buffer_size) { memcpy(json_result + offset, col_name, slen); offset += slen; }
                            }
                            offset += snprintf(json_result + offset, buffer_size - offset, "\":");

                            char *agtype_str = agtype_value_to_string(result->agtype_data[row][col]);
                            if (agtype_str) {
                                size_t slen = strlen(agtype_str);
                                if (offset + slen < buffer_size) { memcpy(json_result + offset, agtype_str, slen); offset += slen; }
                                free(agtype_str);
                            } else {
                                offset += snprintf(json_result + offset, buffer_size - offset, "null");
                            }
                        }
                        offset += snprintf(json_result + offset, buffer_size - offset, "}");
                    }
                }
                offset += snprintf(json_result + offset, buffer_size - offset, "]");
                json_result[offset] = '\0';

                sqlite3_result_text(context, json_result, -1, SQLITE_TRANSIENT);
                free(json_result);
            }
        } else if (result->row_count > 0 && result->data) {
            /* Format results as JSON with column names */
            size_t buffer_size = 1024;
            for (int row = 0; row < result->row_count; row++) {
                for (int col = 0; col < result->column_count; col++) {
                    if (result->data[row][col]) {
                        buffer_size += strlen(result->data[row][col]) * 2 + 20;
                    }
                }
            }

            char *json_result = malloc(buffer_size);
            if (!json_result) {
                graphqlite_result_error(context, "Memory allocation failed for result formatting", GQL_ERR_MEMORY);
                cypher_result_free(result);
                return;
            }
            size_t offset = 0;

            offset += snprintf(json_result + offset, buffer_size - offset, "[");

            for (int row = 0; row < result->row_count; row++) {
                if (row > 0) offset += snprintf(json_result + offset, buffer_size - offset, ",");
                offset += snprintf(json_result + offset, buffer_size - offset, "{");

                for (int col = 0; col < result->column_count; col++) {
                    if (col > 0) offset += snprintf(json_result + offset, buffer_size - offset, ",");

                    offset += snprintf(json_result + offset, buffer_size - offset, "\"");
                    if (result->column_names && result->column_names[col]) {
                        size_t slen = strlen(result->column_names[col]);
                        if (offset + slen < buffer_size) { memcpy(json_result + offset, result->column_names[col], slen); offset += slen; }
                    } else {
                        char col_name[32];
                        snprintf(col_name, sizeof(col_name), "column_%d", col);
                        size_t slen = strlen(col_name);
                        if (offset + slen < buffer_size) { memcpy(json_result + offset, col_name, slen); offset += slen; }
                    }
                    offset += snprintf(json_result + offset, buffer_size - offset, "\":");

                    if (result->data[row][col]) {
                        const char *val = result->data[row][col];
                        int col_type = SQLITE_TEXT;
                        if (result->data_types && result->data_types[row]) {
                            col_type = result->data_types[row][col];
                        }

                        if (val[0] == '[' || val[0] == '{') {
                            size_t slen = strlen(val);
                            if (offset + slen < buffer_size) { memcpy(json_result + offset, val, slen); offset += slen; }
                        } else if (col_type == SQLITE_INTEGER || col_type == SQLITE_FLOAT) {
                            size_t slen = strlen(val);
                            if (offset + slen < buffer_size) { memcpy(json_result + offset, val, slen); offset += slen; }
                        } else {
                            offset += snprintf(json_result + offset, buffer_size - offset, "\"");
                            while (*val) {
                                if (*val == '"' || *val == '\\') {
                                    if (offset < buffer_size) json_result[offset++] = '\\';
                                }
                                if (offset < buffer_size) json_result[offset++] = *val;
                                val++;
                            }
                            offset += snprintf(json_result + offset, buffer_size - offset, "\"");
                        }
                    } else {
                        offset += snprintf(json_result + offset, buffer_size - offset, "null");
                    }
                }
                offset += snprintf(json_result + offset, buffer_size - offset, "}");
            }
            offset += snprintf(json_result + offset, buffer_size - offset, "]");
            json_result[offset] = '\0';

            sqlite3_result_text(context, json_result, -1, SQLITE_TRANSIENT);
            free(json_result);
        } else if (result->column_count > 0) {
            sqlite3_result_text(context, "[]", -1, SQLITE_STATIC);
        } else {
            char response[256];
            snprintf(response, sizeof(response), "Query executed successfully - nodes created: %d, relationships created: %d",
                    result->nodes_created, result->relationships_created);
            sqlite3_result_text(context, response, -1, SQLITE_TRANSIENT);
        }
    } else {
        const char *err_code = GQL_ERR_EXECUTION;
        if (result->error_message && (strstr(result->error_message, "syntax error") || strstr(result->error_message, "Line "))) {
            err_code = GQL_ERR_PARSE;
        } else if (result->error_message && strstr(result->error_message, "not yet implemented")) {
            err_code = GQL_ERR_NOT_IMPL;
        }
        const char *err_msg = result->error_message ? result->error_message : "Query execution failed";
        /* Sanitize double quotes in dynamic error messages to avoid breaking JSON */
        char sanitized_msg[512];
        const char *src = err_msg;
        char *dst = sanitized_msg;
        char *end = sanitized_msg + sizeof(sanitized_msg) - 1;
        while (*src && dst < end) {
            *dst++ = (*src == '"') ? '\'' : *src;
            src++;
        }
        *dst = '\0';
        graphqlite_result_error(context, sanitized_msg, err_code);
    }

    cypher_result_free(result);
}

/* Create schema function */
static int bundled_create_schema(sqlite3 *db) {
    cypher_schema_manager *schema_manager = cypher_schema_create_manager(db);
    if (!schema_manager) {
        return -1;
    }

    int result = cypher_schema_initialize(schema_manager);
    cypher_schema_free_manager(schema_manager);

    return result;
}

/*
 * REGEXP function for SQLite
 */
static void bundled_regexp_func(
    sqlite3_context *context,
    int argc,
    sqlite3_value **argv
) {
    const char *pattern;
    const char *string;
    regex_t regex;
    int ret;
    int cflags = REG_EXTENDED | REG_NOSUB;

    if (argc != 2) {
        graphqlite_result_error(context, "regexp() requires 2 arguments", GQL_ERR_VALIDATION);
        return;
    }

    pattern = (const char*)sqlite3_value_text(argv[0]);
    string = (const char*)sqlite3_value_text(argv[1]);

    if (!pattern || !string) {
        sqlite3_result_null(context);
        return;
    }

    if (strncmp(pattern, "(?i)", 4) == 0) {
        cflags |= REG_ICASE;
        pattern += 4;
    }

    ret = regcomp(&regex, pattern, cflags);
    if (ret != 0) {
        char errbuf[256];
        regerror(ret, &regex, errbuf, sizeof(errbuf));
        /* Sanitize double quotes in dynamic error message */
        for (char *p = errbuf; *p; p++) { if (*p == '"') *p = '\''; }
        graphqlite_result_error(context, errbuf, GQL_ERR_EXECUTION);
        return;
    }

    ret = regexec(&regex, string, 0, NULL, 0);
    regfree(&regex);

    sqlite3_result_int(context, ret == 0 ? 1 : 0);
}

/*
 * Initialize GraphQLite on a database connection.
 * This is the bundled version that uses direct SQLite calls.
 *
 * Returns SQLITE_OK on success, error code on failure.
 */
int graphqlite_init(sqlite3 *db) {
    int rc = SQLITE_OK;

    /* Create per-connection cache */
    bundled_connection_cache *cache = calloc(1, sizeof(bundled_connection_cache));
    if (!cache) {
        return SQLITE_NOMEM;
    }
    cache->db = db;
    cache->executor = NULL;

    /* Register all functions — check each return value */
    rc = sqlite3_create_function(db, "graphqlite_test", 0, SQLITE_UTF8, 0,
                           bundled_test_func, 0, 0);
    if (rc != SQLITE_OK) { free(cache); return rc; }

    rc = sqlite3_create_function_v2(db, "cypher", -1, SQLITE_UTF8, cache,
                               bundled_cypher_func, 0, 0,
                               bundled_connection_cache_destroy);
    if (rc != SQLITE_OK) { free(cache); return rc; }

    rc = sqlite3_create_function(db, "regexp", 2, SQLITE_UTF8, 0,
                           bundled_regexp_func, 0, 0);
    if (rc != SQLITE_OK) { free(cache); return rc; }

    rc = sqlite3_create_function(db, "gql_load_graph", 0, SQLITE_UTF8, cache,
                           bundled_load_graph_func, 0, 0);
    if (rc != SQLITE_OK) { free(cache); return rc; }

    rc = sqlite3_create_function(db, "gql_unload_graph", 0, SQLITE_UTF8, cache,
                           bundled_unload_graph_func, 0, 0);
    if (rc != SQLITE_OK) { free(cache); return rc; }

    rc = sqlite3_create_function(db, "gql_reload_graph", 0, SQLITE_UTF8, cache,
                           bundled_reload_graph_func, 0, 0);
    if (rc != SQLITE_OK) { free(cache); return rc; }

    rc = sqlite3_create_function(db, "gql_graph_loaded", 0, SQLITE_UTF8, cache,
                           bundled_graph_loaded_func, 0, 0);
    if (rc != SQLITE_OK) { free(cache); return rc; }

    /* Create schema */
    bundled_create_schema(db);

    return SQLITE_OK;
}
