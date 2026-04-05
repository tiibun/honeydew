#include <mysql/mysql.h>
#include <string.h>
#include <stdio.h>

#define MAX_CONNS   8
#define MAX_RESULTS 8

static MYSQL      *g_conns[MAX_CONNS];
static MYSQL_RES  *g_results[MAX_RESULTS];

/* ---- helpers ---- */

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

/* ---- connection ---- */

int hd_mysql_connect(
    const char *host,    int host_len,
    int         port,
    const char *db,      int db_len,
    const char *user,    int user_len,
    const char *pass,    int pass_len)
{
    char chost[256], cdb[256], cuser[256], cpass[256];
    make_cstr(host, host_len, chost, sizeof(chost));
    make_cstr(db,   db_len,   cdb,   sizeof(cdb));
    make_cstr(user, user_len, cuser, sizeof(cuser));
    make_cstr(pass, pass_len, cpass, sizeof(cpass));

    for (int i = 0; i < MAX_CONNS; i++) {
        if (!g_conns[i]) {
            g_conns[i] = mysql_init(NULL);
            if (!g_conns[i]) return -1;
            if (mysql_real_connect(g_conns[i], chost, cuser, cpass, cdb,
                                   port ? port : 3306, NULL, 0)) {
                return i;
            }
            mysql_close(g_conns[i]);
            g_conns[i] = NULL;
            return -1;
        }
    }
    return -1;
}

void hd_mysql_close(int id)
{
    if (id >= 0 && id < MAX_CONNS && g_conns[id]) {
        mysql_close(g_conns[id]);
        g_conns[id] = NULL;
    }
}

int hd_mysql_errmsg(int id, char *buf, int buf_len)
{
    if (id < 0 || id >= MAX_CONNS || !g_conns[id]) return -1;
    return copy_str(mysql_error(g_conns[id]), buf, buf_len);
}

/* ---- query ---- */

int hd_mysql_exec(int conn_id, const char *sql, int len)
{
    if (conn_id < 0 || conn_id >= MAX_CONNS || !g_conns[conn_id]) return -1;

    if (mysql_real_query(g_conns[conn_id], sql, (unsigned long)len) != 0)
        return -1;

    MYSQL_RES *res = mysql_store_result(g_conns[conn_id]);
    /* For non-SELECT (INSERT/UPDATE/etc.) res is NULL but no error */
    for (int i = 0; i < MAX_RESULTS; i++) {
        if (!g_results[i]) {
            g_results[i] = res; /* may be NULL — that's OK */
            return i;
        }
    }
    if (res) mysql_free_result(res);
    return -1;
}

void hd_mysql_result_free(int res_id)
{
    if (res_id >= 0 && res_id < MAX_RESULTS && g_results[res_id]) {
        mysql_free_result(g_results[res_id]);
        g_results[res_id] = NULL;
    }
}

int hd_mysql_nrows(int res_id)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return 0;
    return (int)mysql_num_rows(g_results[res_id]);
}

int hd_mysql_nfields(int res_id)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return 0;
    return (int)mysql_num_fields(g_results[res_id]);
}

int hd_mysql_fname(int res_id, int col, char *buf, int buf_len)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return -1;
    MYSQL_FIELD *fields = mysql_fetch_fields(g_results[res_id]);
    if (!fields) return -1;
    return copy_str(fields[col].name, buf, buf_len);
}

/* Seek to row `row_idx` and read column `col`. Returns bytes or -1 (NULL). */
int hd_mysql_getvalue(int res_id, int row_idx, int col, char *buf, int buf_len)
{
    if (res_id < 0 || res_id >= MAX_RESULTS || !g_results[res_id]) return -1;
    mysql_data_seek(g_results[res_id], (unsigned long long)row_idx);
    MYSQL_ROW row = mysql_fetch_row(g_results[res_id]);
    if (!row) return -1;
    unsigned long *lengths = mysql_fetch_lengths(g_results[res_id]);
    if (!row[col]) return -1; /* NULL value */
    int n = lengths ? (int)lengths[col] : (int)strlen(row[col]);
    if (n >= buf_len) n = buf_len - 1;
    memcpy(buf, row[col], n);
    buf[n] = '\0';
    return n;
}
