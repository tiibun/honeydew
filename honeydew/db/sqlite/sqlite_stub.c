#include "sqlite3.h"
#include <string.h>
#include <stdio.h>

#define MAX_CONNS  8
#define MAX_STMTS  16

static sqlite3       *g_conns[MAX_CONNS];
static sqlite3_stmt  *g_stmts[MAX_STMTS];

/* ---- connection management ---- */

int hd_sqlite_open(const char *path, int len)
{
    char tmp[1024];
    if (len < 0 || len >= (int)sizeof(tmp)) return -1;
    memcpy(tmp, path, len);
    tmp[len] = '\0';

    for (int i = 0; i < MAX_CONNS; i++) {
        if (!g_conns[i]) {
            if (sqlite3_open(tmp, &g_conns[i]) == SQLITE_OK) return i;
            g_conns[i] = NULL;
            return -1;
        }
    }
    return -1; /* no free slot */
}

void hd_sqlite_close(int id)
{
    if (id >= 0 && id < MAX_CONNS && g_conns[id]) {
        sqlite3_close(g_conns[id]);
        g_conns[id] = NULL;
    }
}

/* ---- statement management ---- */

int hd_sqlite_prepare(int conn_id, const char *sql, int len)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return -1;

    for (int i = 0; i < MAX_STMTS; i++) {
        if (!g_stmts[i]) {
            int rc = sqlite3_prepare_v2(g_conns[conn_id], sql, len,
                                        &g_stmts[i], NULL);
            if (rc == SQLITE_OK) return i;
            g_stmts[i] = NULL;
            return -1;
        }
    }
    return -1; /* no free slot */
}

void hd_sqlite_finalize(int stmt_id)
{
    if (stmt_id >= 0 && stmt_id < MAX_STMTS && g_stmts[stmt_id]) {
        sqlite3_finalize(g_stmts[stmt_id]);
        g_stmts[stmt_id] = NULL;
    }
}

/* ---- stepping & columns ---- */

/* Returns SQLITE_ROW (100), SQLITE_DONE (101), or negative on error. */
int hd_sqlite_step(int stmt_id)
{
    if (stmt_id < 0 || stmt_id >= MAX_STMTS || !g_stmts[stmt_id]) return -1;
    return sqlite3_step(g_stmts[stmt_id]);
}

int hd_sqlite_column_count(int stmt_id)
{
    if (stmt_id < 0 || stmt_id >= MAX_STMTS || !g_stmts[stmt_id]) return 0;
    return sqlite3_column_count(g_stmts[stmt_id]);
}

/* Copy column name into buf; return number of bytes written, or -1. */
int hd_sqlite_column_name(int stmt_id, int col, char *buf, int buf_len)
{
    if (stmt_id < 0 || stmt_id >= MAX_STMTS || !g_stmts[stmt_id]) return -1;
    const char *name = sqlite3_column_name(g_stmts[stmt_id], col);
    if (!name) return -1;
    int n = (int)strlen(name);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, name, n);
    buf[n] = '\0';
    return n;
}

/* Copy column text value into buf; return bytes written (-1 for NULL). */
int hd_sqlite_column_text(int stmt_id, int col, char *buf, int buf_len)
{
    if (stmt_id < 0 || stmt_id >= MAX_STMTS || !g_stmts[stmt_id]) return -1;
    if (sqlite3_column_type(g_stmts[stmt_id], col) == SQLITE_NULL) return -1;
    const unsigned char *text = sqlite3_column_text(g_stmts[stmt_id], col);
    if (!text) return -1;
    int n = (int)strlen((const char *)text);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, text, n);
    buf[n] = '\0';
    return n;
}

/* Return the declared column type name for PRAGMA table_info (col 2). */
int hd_sqlite_column_decltype(int stmt_id, int col, char *buf, int buf_len)
{
    if (stmt_id < 0 || stmt_id >= MAX_STMTS || !g_stmts[stmt_id]) return -1;
    const char *t = sqlite3_column_decltype(g_stmts[stmt_id], col);
    if (!t) { buf[0] = '\0'; return 0; }
    int n = (int)strlen(t);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, t, n);
    buf[n] = '\0';
    return n;
}

/* Copy last error message for a connection. */
int hd_sqlite_errmsg(int conn_id, char *buf, int buf_len)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return -1;
    const char *msg = sqlite3_errmsg(g_conns[conn_id]);
    if (!msg) return -1;
    int n = (int)strlen(msg);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, msg, n);
    buf[n] = '\0';
    return n;
}
