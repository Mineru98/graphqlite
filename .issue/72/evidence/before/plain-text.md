# before — DDL 평문 반환 (수정 전)

## extension.c:399
            /* Modification query without RETURN - show statistics */
            char response[256];
            snprintf(response, sizeof(response), "Query executed successfully - nodes created: %d, relationships created: %d",
                    result->nodes_created, result->relationships_created);
            sqlite3_result_text(context, response, -1, SQLITE_TRANSIENT);
## TS parseMutationSummary (정규식)
7://   ④ DDL summary "Query executed successfully - nodes created: 1, ..."  (plain text)
115:const NODES_CREATED = /nodes created:\s*(\d+)/i;
124:  const nodes = NODES_CREATED.exec(raw);
