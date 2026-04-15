#include "sqlite3.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#  include <windows.h>
typedef HANDLE pthread_t;
typedef struct { void *(*fn)(void *); void *arg; } _win_targs;
static DWORD WINAPI _win_wrap(LPVOID p) {
    _win_targs *a = (_win_targs *)p; a->fn(a->arg); free(a); return 0;
}
static int pthread_create(pthread_t *t, void *attr, void *(*fn)(void *), void *arg) {
    (void)attr;
    _win_targs *a = (_win_targs *)malloc(sizeof(_win_targs));
    if (!a) return -1;
    a->fn = fn; a->arg = arg;
    *t = CreateThread(NULL, 0, _win_wrap, a, 0, NULL);
    if (!*t) { free(a); return -1; }
    return 0;
}
static void pthread_detach(pthread_t t) { CloseHandle(t); }
#else
#  include <pthread.h>
#endif

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

int hd_sqlite_changes(int conn_id)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return 0;
    return sqlite3_changes(g_conns[conn_id]);
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

/* Interrupt a long-running query. Thread-safe. */
void hd_sqlite_interrupt(int conn_id)
{
    if (conn_id >= 0 && conn_id < MAX_CONNS && g_conns[conn_id]) {
        sqlite3_interrupt(g_conns[conn_id]);
    }
}

/* ---- async worker thread ---- */

/* Status codes for the async worker. */
#define ASYNC_IDLE    0
#define ASYNC_RUNNING 1
#define ASYNC_DONE    2
#define ASYNC_ERROR   3

/* Maximum dimensions for collected results. */
#define ASYNC_MAX_COLS  256
#define ASYNC_MAX_ROWS  50000
#define ASYNC_MAX_CELL  8192

typedef struct {
    char *data;
    int   len;     /* -1 means SQL NULL */
} cell_t;

typedef struct {
    /* input */
    int   conn_id;
    char *sql;
    int   sql_len;

    /* status (volatile for cross-thread visibility) */
    volatile int status;

    /* output */
    char  *col_names[ASYNC_MAX_COLS];
    int    ncols;
    cell_t *cells;     /* flat array: cells[row * ncols + col] */
    int    nrows;
    int    capacity;   /* allocated row capacity */
    int    changes;
    char   errmsg[1024];

    pthread_t thread;
} async_worker_t;

static async_worker_t g_async;

static void async_free_results(void)
{
    for (int i = 0; i < g_async.ncols; i++) {
        free(g_async.col_names[i]);
        g_async.col_names[i] = NULL;
    }
    if (g_async.cells) {
        int total = g_async.nrows * g_async.ncols;
        for (int i = 0; i < total; i++) {
            free(g_async.cells[i].data);
        }
        free(g_async.cells);
        g_async.cells = NULL;
    }
    free(g_async.sql);
    g_async.sql = NULL;
    g_async.ncols = 0;
    g_async.nrows = 0;
    g_async.capacity = 0;
    g_async.changes = 0;
    g_async.errmsg[0] = '\0';
}

static char *strdup_col(const char *s)
{
    if (!s) return NULL;
    size_t n = strlen(s);
    char *d = (char *)malloc(n + 1);
    if (d) { memcpy(d, s, n); d[n] = '\0'; }
    return d;
}

static void *async_thread_fn(void *arg)
{
    (void)arg;
    int conn_id = g_async.conn_id;
    sqlite3 *db = g_conns[conn_id];
    sqlite3_stmt *stmt = NULL;

    int rc = sqlite3_prepare_v2(db, g_async.sql, g_async.sql_len, &stmt, NULL);
    if (rc != SQLITE_OK) {
        const char *msg = sqlite3_errmsg(db);
        if (msg) {
            snprintf(g_async.errmsg, sizeof(g_async.errmsg), "%s", msg);
        } else {
            snprintf(g_async.errmsg, sizeof(g_async.errmsg), "prepare failed");
        }
        g_async.status = ASYNC_ERROR;
        return NULL;
    }

    int ncols = sqlite3_column_count(stmt);
    if (ncols > ASYNC_MAX_COLS) ncols = ASYNC_MAX_COLS;
    g_async.ncols = ncols;

    /* Read column names. */
    for (int i = 0; i < ncols; i++) {
        g_async.col_names[i] = strdup_col(sqlite3_column_name(stmt, i));
    }

    /* Step through rows. */
    int capacity = 256;
    g_async.cells = (cell_t *)calloc((size_t)capacity * (size_t)ncols, sizeof(cell_t));
    g_async.capacity = capacity;
    g_async.nrows = 0;

    while ((rc = sqlite3_step(stmt)) == SQLITE_ROW) {
        if (g_async.nrows >= ASYNC_MAX_ROWS) break;
        /* Grow if needed. */
        if (g_async.nrows >= g_async.capacity) {
            int new_cap = g_async.capacity * 2;
            if (new_cap > ASYNC_MAX_ROWS) new_cap = ASYNC_MAX_ROWS;
            cell_t *new_cells = (cell_t *)realloc(
                g_async.cells,
                (size_t)new_cap * (size_t)ncols * sizeof(cell_t));
            if (!new_cells) break;
            memset(new_cells + (size_t)g_async.capacity * (size_t)ncols, 0,
                   (size_t)(new_cap - g_async.capacity) * (size_t)ncols * sizeof(cell_t));
            g_async.cells = new_cells;
            g_async.capacity = new_cap;
        }
        int base = g_async.nrows * ncols;
        for (int col = 0; col < ncols; col++) {
            if (sqlite3_column_type(stmt, col) == SQLITE_NULL) {
                g_async.cells[base + col].data = NULL;
                g_async.cells[base + col].len = -1;
            } else {
                const char *text = (const char *)sqlite3_column_text(stmt, col);
                if (text) {
                    int n = (int)strlen(text);
                    if (n > ASYNC_MAX_CELL) n = ASYNC_MAX_CELL;
                    char *d = (char *)malloc((size_t)n + 1);
                    if (d) { memcpy(d, text, (size_t)n); d[n] = '\0'; }
                    g_async.cells[base + col].data = d;
                    g_async.cells[base + col].len = n;
                } else {
                    g_async.cells[base + col].data = NULL;
                    g_async.cells[base + col].len = -1;
                }
            }
        }
        g_async.nrows++;
    }

    g_async.changes = sqlite3_changes(db);

    if (rc == SQLITE_INTERRUPT) {
        snprintf(g_async.errmsg, sizeof(g_async.errmsg), "interrupted");
        sqlite3_finalize(stmt);
        g_async.status = ASYNC_ERROR;
        return NULL;
    }

    if (rc != SQLITE_DONE && rc != SQLITE_ROW) {
        const char *msg = sqlite3_errmsg(db);
        if (msg) {
            snprintf(g_async.errmsg, sizeof(g_async.errmsg), "%s", msg);
        } else {
            snprintf(g_async.errmsg, sizeof(g_async.errmsg), "query failed");
        }
        sqlite3_finalize(stmt);
        g_async.status = ASYNC_ERROR;
        return NULL;
    }

    sqlite3_finalize(stmt);
    g_async.status = ASYNC_DONE;
    return NULL;
}

/* Start an async query execution in a background thread.
   Returns 0 on success, -1 on failure. */
int hd_sqlite_async_start(int conn_id, const char *sql, int sql_len)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return -1;
    if (g_async.status == ASYNC_RUNNING) return -1;

    async_free_results();
    g_async.conn_id = conn_id;
    g_async.sql = (char *)malloc((size_t)sql_len + 1);
    if (!g_async.sql) return -1;
    memcpy(g_async.sql, sql, (size_t)sql_len);
    g_async.sql[sql_len] = '\0';
    g_async.sql_len = sql_len;
    g_async.status = ASYNC_RUNNING;

    if (pthread_create(&g_async.thread, NULL, async_thread_fn, NULL) != 0) {
        g_async.status = ASYNC_IDLE;
        free(g_async.sql);
        g_async.sql = NULL;
        return -1;
    }
    pthread_detach(g_async.thread);
    return 0;
}

/* Poll the async worker status.
   Returns: 0=idle, 1=running, 2=done_ok, 3=done_error */
int hd_sqlite_async_poll(void)
{
    return g_async.status;
}

/* Read result dimensions after completion. */
int hd_sqlite_async_ncols(void)  { return g_async.ncols; }
int hd_sqlite_async_nrows(void)  { return g_async.nrows; }
int hd_sqlite_async_changes(void) { return g_async.changes; }

/* Copy a column name into buf. Returns bytes written or -1. */
int hd_sqlite_async_colname(int col, char *buf, int buf_len)
{
    if (col < 0 || col >= g_async.ncols || !g_async.col_names[col]) return -1;
    int n = (int)strlen(g_async.col_names[col]);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, g_async.col_names[col], (size_t)n);
    buf[n] = '\0';
    return n;
}

/* Copy a cell value into buf. Returns bytes written, or -1 for NULL. */
int hd_sqlite_async_value(int row, int col, char *buf, int buf_len)
{
    if (row < 0 || row >= g_async.nrows) return -1;
    if (col < 0 || col >= g_async.ncols) return -1;
    cell_t *c = &g_async.cells[row * g_async.ncols + col];
    if (c->len < 0 || !c->data) return -1;
    int n = c->len;
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, c->data, (size_t)n);
    buf[n] = '\0';
    return n;
}

/* Copy the error message into buf. Returns bytes written or -1. */
int hd_sqlite_async_errmsg(char *buf, int buf_len)
{
    if (g_async.errmsg[0] == '\0') return -1;
    int n = (int)strlen(g_async.errmsg);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, g_async.errmsg, (size_t)n);
    buf[n] = '\0';
    return n;
}

/* Release async worker results and reset to idle. */
void hd_sqlite_async_finish(void)
{
    async_free_results();
    g_async.status = ASYNC_IDLE;
}
