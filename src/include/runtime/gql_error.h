/*
 * runtime/gql_error.h
 *    Structured error response helper for SQLite UDFs. Returns
 *    JSON of the shape `{"error": "...", "code": "..."}` via
 *    sqlite3_result_error so callers can distinguish error classes
 *    programmatically.
 *
 *    Shared between src/extension.c and src/backend/runtime/udf_helpers.c
 *    (lifted from extension.c during I-0040 M6).
 */

#ifndef RUNTIME_GQL_ERROR_H
#define RUNTIME_GQL_ERROR_H

#include "graphqlite_sqlite.h"

#define GQL_ERR_VALIDATION    "VALIDATION_ERROR"
#define GQL_ERR_PARSE         "PARSE_ERROR"
#define GQL_ERR_EXECUTION     "EXECUTION_ERROR"
#define GQL_ERR_MEMORY        "MEMORY_ERROR"
#define GQL_ERR_INTERNAL      "INTERNAL_ERROR"
#define GQL_ERR_NOT_IMPL      "NOT_IMPLEMENTED"

void graphqlite_result_error(sqlite3_context *context,
                             const char *message,
                             const char *code);

#endif /* RUNTIME_GQL_ERROR_H */
