#include <dlfcn.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

/* Minimal type stubs — opaque handles are enough */
typedef struct MYSQL      MYSQL;
typedef struct MYSQL_RES  MYSQL_RES;
typedef char            **MYSQL_ROW;
typedef unsigned long long my_ulonglong;

typedef struct {
    char *name;
    char *org_name;
    char *table;
    char *org_table;
    char *db;
    char *catalog;
    char *def;
    unsigned long length;
    unsigned long max_length;
    unsigned int  name_length;
    unsigned int  org_name_length;
    unsigned int  table_length;
    unsigned int  org_table_length;
    unsigned int  db_length;
    unsigned int  catalog_length;
    unsigned int  def_length;
    unsigned int  flags;
    unsigned int  decimals;
    unsigned int  charsetnr;
    int           type;
    void         *extension;
} MYSQL_FIELD;

/* ---- function pointer table ---- */

#define MYSQL_FUNCTIONS \
    MYSQL_FUNC(MYSQL *,           mysql_init,          (MYSQL *)) \
    MYSQL_FUNC(MYSQL *,           mysql_real_connect,  (MYSQL *, const char *, const char *, const char *, const char *, unsigned int, const char *, unsigned long)) \
    MYSQL_FUNC(void,              mysql_close,         (MYSQL *)) \
    MYSQL_FUNC(int,               mysql_real_query,    (MYSQL *, const char *, unsigned long)) \
    MYSQL_FUNC(MYSQL_RES *,       mysql_store_result,  (MYSQL *)) \
    MYSQL_FUNC(void,              mysql_free_result,   (MYSQL_RES *)) \
    MYSQL_FUNC(unsigned int,      mysql_num_fields,    (MYSQL_RES *)) \
    MYSQL_FUNC(my_ulonglong,      mysql_num_rows,      (MYSQL_RES *)) \
    MYSQL_FUNC(MYSQL_FIELD *,     mysql_fetch_fields,  (MYSQL_RES *)) \
    MYSQL_FUNC(MYSQL_ROW,         mysql_fetch_row,     (MYSQL_RES *)) \
    MYSQL_FUNC(unsigned long *,   mysql_fetch_lengths, (MYSQL_RES *)) \
    MYSQL_FUNC(void,              mysql_data_seek,     (MYSQL_RES *, my_ulonglong)) \
    MYSQL_FUNC(unsigned int,      mysql_field_count,   (MYSQL *)) \
    MYSQL_FUNC(my_ulonglong,      mysql_affected_rows, (MYSQL *)) \
    MYSQL_FUNC(unsigned long,     mysql_thread_id,     (MYSQL *)) \
    MYSQL_FUNC(const char *,      mysql_error,         (MYSQL *))

#define MYSQL_FUNC(ret, name, params) static ret (*fn_##name) params;
MYSQL_FUNCTIONS
#undef MYSQL_FUNC

static int g_loaded = 0; /* -1=failed, 0=not tried, 1=ok */

static int load_mysql(void)
{
    if (g_loaded != 0) return g_loaded;

    void *h = NULL;
#ifdef __MACH__
    h = dlopen("libmysqlclient.21.dylib", RTLD_LAZY | RTLD_GLOBAL);
    if (!h) h = dlopen("libmysqlclient.dylib",    RTLD_LAZY | RTLD_GLOBAL);
    if (!h) h = dlopen("/opt/homebrew/opt/mysql-client/lib/libmysqlclient.dylib", RTLD_LAZY | RTLD_GLOBAL);
    if (!h) h = dlopen("/usr/local/opt/mysql-client/lib/libmysqlclient.dylib",    RTLD_LAZY | RTLD_GLOBAL);
#else
    h = dlopen("libmysqlclient.so.21", RTLD_LAZY | RTLD_GLOBAL);
    if (!h) h = dlopen("libmysqlclient.so.20", RTLD_LAZY | RTLD_GLOBAL);
    if (!h) h = dlopen("libmysqlclient.so",    RTLD_LAZY | RTLD_GLOBAL);
#endif
    if (!h) { g_loaded = -1; return -1; }

#define MYSQL_FUNC(ret, name, params) \
    fn_##name = dlsym(h, #name); \
    if (!fn_##name) { g_loaded = -1; return -1; }
    MYSQL_FUNCTIONS
#undef MYSQL_FUNC

    g_loaded = 1;
    return 1;
}

/* ---- connection pool ---- */

#define MAX_CONNS   8
#define MAX_RESULTS 8

static MYSQL     *g_conns[MAX_CONNS];
static MYSQL_RES *g_results[MAX_RESULTS];

typedef struct {
    char *host;
    char *db;
    char *user;
    char *pass;
    int   port;
} mysql_conn_meta_t;

static mysql_conn_meta_t g_conn_meta[MAX_CONNS];

static int copy_str(const char *src, char *dst, int dst_len)
{
    if (!src) { if (dst_len > 0) dst[0] = '\0'; return 0; }
    int n = (int)strlen(src);
    if (n >= dst_len) n = dst_len - 1;
    memcpy(dst, src, n);
    dst[n] = '\0';
    return n;
}

static void make_cstr(const char *src, int len, char *dst, int dst_len)
{
    int n = len < dst_len - 1 ? len : dst_len - 1;
    memcpy(dst, src, n);
    dst[n] = '\0';
}

static char *dup_cstr(const char *src)
{
    if (!src) return NULL;
    size_t n = strlen(src);
    char *dst = (char *)malloc(n + 1);
    if (!dst) return NULL;
    memcpy(dst, src, n + 1);
    return dst;
}

static void free_conn_meta(int id)
{
    free(g_conn_meta[id].host);
    free(g_conn_meta[id].db);
    free(g_conn_meta[id].user);
    free(g_conn_meta[id].pass);
    g_conn_meta[id].host = NULL;
    g_conn_meta[id].db = NULL;
    g_conn_meta[id].user = NULL;
    g_conn_meta[id].pass = NULL;
    g_conn_meta[id].port = 0;
}

/* ---- public API ---- */

int hd_mysql_connect(
    const char *host,    int host_len,
    int         port,
    const char *db,      int db_len,
    const char *user,    int user_len,
    const char *pass,    int pass_len)
{
    if (load_mysql() != 1) return -1;

    char chost[256], cdb[256], cuser[256], cpass[256];
    make_cstr(host, host_len, chost, sizeof(chost));
    make_cstr(db,   db_len,   cdb,   sizeof(cdb));
    make_cstr(user, user_len, cuser, sizeof(cuser));
    make_cstr(pass, pass_len, cpass, sizeof(cpass));

    for (int i = 0; i < MAX_CONNS; i++) {
        if (!g_conns[i]) {
            g_conns[i] = fn_mysql_init(NULL);
            if (!g_conns[i]) return -1;
            if (fn_mysql_real_connect(g_conns[i], chost, cuser, cpass, cdb,
                                      port ? port : 3306, NULL, 0)) {
                free_conn_meta(i);
                g_conn_meta[i].host = dup_cstr(chost);
                g_conn_meta[i].db = dup_cstr(cdb);
                g_conn_meta[i].user = dup_cstr(cuser);
                g_conn_meta[i].pass = dup_cstr(cpass);
                g_conn_meta[i].port = port ? port : 3306;
                return i;
            }
            fn_mysql_close(g_conns[i]);
            g_conns[i] = NULL;
            return -1;
        }
    }
    return -1;
}

void hd_mysql_close(int id)
{
    if (id >= 0 && id < MAX_CONNS && g_conns[id]) {
        fn_mysql_close(g_conns[id]);
        g_conns[id] = NULL;
        free_conn_meta(id);
    }
}

int hd_mysql_errmsg(int id, char *buf, int buf_len)
{
    if (id < 0 || id >= MAX_CONNS || !g_conns[id]) return -1;
    return copy_str(fn_mysql_error(g_conns[id]), buf, buf_len);
}

void hd_mysql_interrupt(int conn_id)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return;

    MYSQL *cancel_conn = fn_mysql_init(NULL);
    if (!cancel_conn) return;

    mysql_conn_meta_t *meta = &g_conn_meta[conn_id];
    if (!fn_mysql_real_connect(cancel_conn,
                               meta->host ? meta->host : "",
                               meta->user ? meta->user : "",
                               meta->pass ? meta->pass : "",
                               meta->db ? meta->db : "",
                               meta->port ? (unsigned int)meta->port : 3306,
                               NULL,
                               0)) {
        fn_mysql_close(cancel_conn);
        return;
    }

    unsigned long thread_id = fn_mysql_thread_id(g_conns[conn_id]);
    char sql[64];
    int sql_len = snprintf(sql, sizeof(sql), "KILL QUERY %lu", thread_id);
    if (sql_len > 0 && sql_len < (int)sizeof(sql)) {
        if (fn_mysql_real_query(cancel_conn, sql, (unsigned long)sql_len) == 0) {
            MYSQL_RES *res = fn_mysql_store_result(cancel_conn);
            if (res) fn_mysql_free_result(res);
        }
    }

    fn_mysql_close(cancel_conn);
}

int hd_mysql_exec(int conn_id, const char *sql, int len)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return -1;

    if (fn_mysql_real_query(g_conns[conn_id], sql, (unsigned long)len) != 0)
        return -1;

    MYSQL_RES *res = fn_mysql_store_result(g_conns[conn_id]);
    if (!res && fn_mysql_field_count(g_conns[conn_id]) != 0)
        return -1;
    for (int i = 0; i < MAX_RESULTS; i++) {
        if (!g_results[i]) {
            g_results[i] = res;
            return i;
        }
    }
    if (res) fn_mysql_free_result(res);
    return -1;
}

int hd_mysql_affected_rows(int conn_id)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return 0;
    return (int)fn_mysql_affected_rows(g_conns[conn_id]);
}

void hd_mysql_result_free(int res_id)
{
    if (res_id >= 0 && res_id < MAX_RESULTS && g_results[res_id]) {
        fn_mysql_free_result(g_results[res_id]);
        g_results[res_id] = NULL;
    }
}

int hd_mysql_nrows(int res_id)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return 0;
    return (int)fn_mysql_num_rows(g_results[res_id]);
}

int hd_mysql_nfields(int res_id)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return 0;
    return (int)fn_mysql_num_fields(g_results[res_id]);
}

int hd_mysql_fname(int res_id, int col, char *buf, int buf_len)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return -1;
    MYSQL_FIELD *fields = fn_mysql_fetch_fields(g_results[res_id]);
    if (!fields) return -1;
    return copy_str(fields[col].name, buf, buf_len);
}

int hd_mysql_getvalue(int res_id, int row_idx, int col, char *buf, int buf_len)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return -1;
    fn_mysql_data_seek(g_results[res_id], (my_ulonglong)row_idx);
    MYSQL_ROW row = fn_mysql_fetch_row(g_results[res_id]);
    if (!row) return -1;
    unsigned long *lengths = fn_mysql_fetch_lengths(g_results[res_id]);
    if (!row[col]) return -1;
    int n = lengths ? (int)lengths[col] : (int)strlen(row[col]);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, row[col], n);
    buf[n] = '\0';
    return n;
}

/* ---- async worker thread ---- */

#define ASYNC_IDLE    0
#define ASYNC_RUNNING 1
#define ASYNC_DONE    2
#define ASYNC_ERROR   3

typedef struct {
    int conn_id;
    char *sql;
    int sql_len;
    volatile int status;
    MYSQL_RES *result;
    int affected_rows;
    char errmsg[1024];
    unsigned long thread_id;
    MYSQL *kill_conn;
    pthread_t thread;
} mysql_async_worker_t;

static mysql_async_worker_t g_async;

static void mysql_async_reset(void)
{
    if (g_async.result) {
        fn_mysql_free_result(g_async.result);
        g_async.result = NULL;
    }
    if (g_async.kill_conn) {
        fn_mysql_close(g_async.kill_conn);
        g_async.kill_conn = NULL;
    }
    free(g_async.sql);
    g_async.sql = NULL;
    g_async.conn_id = -1;
    g_async.sql_len = 0;
    g_async.affected_rows = 0;
    g_async.thread_id = 0;
    g_async.errmsg[0] = '\0';
}

static void *mysql_async_thread_fn(void *arg)
{
    (void)arg;
    if (g_async.conn_id < 0 || g_async.conn_id >= MAX_CONNS || !g_conns[g_async.conn_id]) {
        snprintf(g_async.errmsg, sizeof(g_async.errmsg), "connection closed");
        g_async.status = ASYNC_ERROR;
        return NULL;
    }

    MYSQL *conn = g_conns[g_async.conn_id];
    if (fn_mysql_real_query(conn, g_async.sql, (unsigned long)g_async.sql_len) != 0) {
        copy_str(fn_mysql_error(conn), g_async.errmsg, (int)sizeof(g_async.errmsg));
        g_async.status = ASYNC_ERROR;
        return NULL;
    }

    g_async.result = fn_mysql_store_result(conn);
    if (!g_async.result && fn_mysql_field_count(conn) != 0) {
        copy_str(fn_mysql_error(conn), g_async.errmsg, (int)sizeof(g_async.errmsg));
        g_async.status = ASYNC_ERROR;
        return NULL;
    }
    g_async.affected_rows = (int)fn_mysql_affected_rows(conn);
    g_async.status = ASYNC_DONE;
    return NULL;
}

int hd_mysql_async_start(int conn_id, const char *sql, int len)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return -1;
    if (g_async.status == ASYNC_RUNNING) return -1;

    mysql_async_reset();
    g_async.conn_id = conn_id;
    g_async.sql = (char *)malloc((size_t)len + 1);
    if (!g_async.sql) return -1;
    memcpy(g_async.sql, sql, (size_t)len);
    g_async.sql[len] = '\0';
    g_async.sql_len = len;
    g_async.thread_id = fn_mysql_thread_id(g_conns[conn_id]);
    g_async.kill_conn = fn_mysql_init(NULL);
    if (!g_async.kill_conn) {
        free(g_async.sql);
        g_async.sql = NULL;
        g_async.conn_id = -1;
        g_async.sql_len = 0;
        g_async.thread_id = 0;
        return -1;
    }
    mysql_conn_meta_t *meta = &g_conn_meta[conn_id];
    if (!fn_mysql_real_connect(g_async.kill_conn,
                               meta->host ? meta->host : "",
                               meta->user ? meta->user : "",
                               meta->pass ? meta->pass : "",
                               meta->db ? meta->db : "",
                               meta->port ? (unsigned int)meta->port : 3306,
                               NULL,
                               0)) {
        fn_mysql_close(g_async.kill_conn);
        g_async.kill_conn = NULL;
        free(g_async.sql);
        g_async.sql = NULL;
        g_async.conn_id = -1;
        g_async.sql_len = 0;
        g_async.thread_id = 0;
        return -1;
    }
    g_async.status = ASYNC_RUNNING;

    if (pthread_create(&g_async.thread, NULL, mysql_async_thread_fn, NULL) != 0) {
        g_async.status = ASYNC_IDLE;
        mysql_async_reset();
        return -1;
    }
    pthread_detach(g_async.thread);
    return 0;
}

int hd_mysql_async_poll(void)
{
    return g_async.status;
}

void hd_mysql_async_cancel(void)
{
    if (g_async.status != ASYNC_RUNNING || !g_async.kill_conn || g_async.thread_id == 0) {
        return;
    }
    char sql[64];
    int sql_len = snprintf(sql, sizeof(sql), "KILL QUERY %lu", g_async.thread_id);
    if (sql_len <= 0 || sql_len >= (int)sizeof(sql)) {
        return;
    }
    if (fn_mysql_real_query(g_async.kill_conn, sql, (unsigned long)sql_len) == 0) {
        MYSQL_RES *res = fn_mysql_store_result(g_async.kill_conn);
        if (res) fn_mysql_free_result(res);
    }
}

int hd_mysql_async_affected_rows(void)
{
    return g_async.affected_rows;
}

int hd_mysql_async_nrows(void)
{
    if (!g_async.result) return 0;
    return (int)fn_mysql_num_rows(g_async.result);
}

int hd_mysql_async_nfields(void)
{
    if (!g_async.result) return 0;
    return (int)fn_mysql_num_fields(g_async.result);
}

int hd_mysql_async_fname(int col, char *buf, int buf_len)
{
    if (!g_async.result) return -1;
    MYSQL_FIELD *fields = fn_mysql_fetch_fields(g_async.result);
    if (!fields) return -1;
    return copy_str(fields[col].name, buf, buf_len);
}

int hd_mysql_async_getvalue(int row_idx, int col, char *buf, int buf_len)
{
    if (!g_async.result) return -1;
    fn_mysql_data_seek(g_async.result, (my_ulonglong)row_idx);
    MYSQL_ROW row = fn_mysql_fetch_row(g_async.result);
    if (!row || !row[col]) return -1;
    unsigned long *lengths = fn_mysql_fetch_lengths(g_async.result);
    int n = lengths ? (int)lengths[col] : (int)strlen(row[col]);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, row[col], (size_t)n);
    buf[n] = '\0';
    return n;
}

int hd_mysql_async_errmsg(char *buf, int buf_len)
{
    if (g_async.errmsg[0] == '\0') return -1;
    return copy_str(g_async.errmsg, buf, buf_len);
}

void hd_mysql_async_finish(void)
{
    mysql_async_reset();
    g_async.status = ASYNC_IDLE;
}
