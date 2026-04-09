#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#  include <windows.h>
#  include <direct.h>
#  define popen  _popen
#  define pclose _pclose
#else
#  include <unistd.h>
#  include <sys/stat.h>
#  include <errno.h>
#endif

/* ------------------------------------------------------------------ */
/* OS detection                                                         */
/* ------------------------------------------------------------------ */
int hd_get_os(void) {
#ifdef _WIN32
    return 2;
#elif defined(__APPLE__)
    return 0;
#else
    return 1;
#endif
}

/* ------------------------------------------------------------------ */
/* Home directory                                                        */
/* ------------------------------------------------------------------ */
int hd_home_dir(char *buf, int buf_len) {
#ifdef _WIN32
    const char *home = getenv("USERPROFILE");
#else
    const char *home = getenv("HOME");
#endif
    if (!home) return -1;
    int len = (int)strlen(home);
    if (len >= buf_len) return -1;
    memcpy(buf, home, len);
    buf[len] = '\0';
    return len;
}

/* ------------------------------------------------------------------ */
/* Recursive mkdir                                                       */
/* ------------------------------------------------------------------ */
int hd_mkdir_p(const char *path, int path_len) {
    char tmp[4096];
    if (path_len <= 0 || path_len >= (int)sizeof(tmp)) return -1;
    memcpy(tmp, path, path_len);
    tmp[path_len] = '\0';
    for (int i = 1; i < path_len; i++) {
        if (tmp[i] == '/' || tmp[i] == '\\') {
            char c = tmp[i];
            tmp[i] = '\0';
#ifdef _WIN32
            CreateDirectoryA(tmp, NULL);
#else
            mkdir(tmp, 0700);
#endif
            tmp[i] = c;
        }
    }
#ifdef _WIN32
    return (CreateDirectoryA(tmp, NULL) || GetLastError() == ERROR_ALREADY_EXISTS) ? 0 : -1;
#else
    return (mkdir(tmp, 0700) == 0 || errno == EEXIST) ? 0 : -1;
#endif
}

/* ------------------------------------------------------------------ */
/* File I/O                                                              */
/* ------------------------------------------------------------------ */
int hd_file_read(const char *path, int path_len, char *buf, int buf_len) {
    char tmp[4096];
    if (path_len <= 0 || path_len >= (int)sizeof(tmp)) return -1;
    memcpy(tmp, path, path_len);
    tmp[path_len] = '\0';
    FILE *f = fopen(tmp, "rb");
    if (!f) return 0;
    int n = (int)fread(buf, 1, buf_len - 1, f);
    fclose(f);
    if (n < 0) n = 0;
    buf[n] = '\0';
    return n;
}

int hd_file_write(const char *path, int path_len, const char *data, int data_len) {
    char tmp[4096];
    if (path_len <= 0 || path_len >= (int)sizeof(tmp)) return -1;
    memcpy(tmp, path, path_len);
    tmp[path_len] = '\0';
    FILE *f = fopen(tmp, "wb");
    if (!f) return -1;
    int n = (int)fwrite(data, 1, data_len, f);
    fclose(f);
    return (n == data_len) ? 0 : -1;
}

/* ------------------------------------------------------------------ */
/* Shell single-quote helper (POSIX only)                               */
/* ------------------------------------------------------------------ */
#ifndef _WIN32
static int sq_append(const char *s, int len, char *out, int pos, int max) {
    if (pos >= max - 2) return pos;
    out[pos++] = '\'';
    for (int i = 0; i < len && pos < max - 5; i++) {
        if (s[i] == '\'') {
            /* end-quote, backslash-quote, re-open */
            out[pos++] = '\''; out[pos++] = '\\';
            out[pos++] = '\''; out[pos++] = '\'';
        } else {
            out[pos++] = s[i];
        }
    }
    if (pos < max - 1) out[pos++] = '\'';
    return pos;
}
#endif

/* ------------------------------------------------------------------ */
/* Keyring – macOS (security CLI)                                       */
/* ------------------------------------------------------------------ */
#ifdef __APPLE__

int hd_keyring_get(const char *svc, int svc_len,
                   const char *acct, int acct_len,
                   char *out, int out_len) {
    char cmd[8192];
    int p = 0;
    const char *s1 = "security find-generic-password -a ";
    memcpy(cmd + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = sq_append(acct, acct_len, cmd, p, (int)sizeof(cmd));
    cmd[p++] = ' ';
    const char *s2 = "-s ";
    memcpy(cmd + p, s2, strlen(s2)); p += (int)strlen(s2);
    p = sq_append(svc, svc_len, cmd, p, (int)sizeof(cmd));
    const char *s3 = " -w 2>/dev/null";
    memcpy(cmd + p, s3, strlen(s3)); p += (int)strlen(s3);
    cmd[p] = '\0';

    FILE *pipe = popen(cmd, "r");
    if (!pipe) return -1;
    int n = (int)fread(out, 1, out_len - 1, pipe);
    pclose(pipe);
    if (n < 0) n = 0;
    out[n] = '\0';
    while (n > 0 && (out[n-1] == '\n' || out[n-1] == '\r')) out[--n] = '\0';
    return n;
}

int hd_keyring_set(const char *svc, int svc_len,
                   const char *acct, int acct_len,
                   const char *pass, int pass_len) {
    char cmd[8192];
    int p = 0;
    const char *s1 = "security add-generic-password -U -a ";
    memcpy(cmd + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = sq_append(acct, acct_len, cmd, p, (int)sizeof(cmd));
    cmd[p++] = ' ';
    const char *s2 = "-s ";
    memcpy(cmd + p, s2, strlen(s2)); p += (int)strlen(s2);
    p = sq_append(svc, svc_len, cmd, p, (int)sizeof(cmd));
    cmd[p++] = ' ';
    const char *s3 = "-w ";
    memcpy(cmd + p, s3, strlen(s3)); p += (int)strlen(s3);
    p = sq_append(pass, pass_len, cmd, p, (int)sizeof(cmd));
    const char *s4 = " 2>/dev/null";
    memcpy(cmd + p, s4, strlen(s4)); p += (int)strlen(s4);
    cmd[p] = '\0';
    return system(cmd) == 0 ? 0 : -1;
}

int hd_keyring_delete(const char *svc, int svc_len,
                      const char *acct, int acct_len) {
    char cmd[8192];
    int p = 0;
    const char *s1 = "security delete-generic-password -a ";
    memcpy(cmd + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = sq_append(acct, acct_len, cmd, p, (int)sizeof(cmd));
    cmd[p++] = ' ';
    const char *s2 = "-s ";
    memcpy(cmd + p, s2, strlen(s2)); p += (int)strlen(s2);
    p = sq_append(svc, svc_len, cmd, p, (int)sizeof(cmd));
    const char *s3 = " 2>/dev/null";
    memcpy(cmd + p, s3, strlen(s3)); p += (int)strlen(s3);
    cmd[p] = '\0';
    return system(cmd) == 0 ? 0 : -1;
}

/* ------------------------------------------------------------------ */
/* Keyring – Linux (secret-tool)                                        */
/* ------------------------------------------------------------------ */
#elif defined(__linux__)

int hd_keyring_get(const char *svc, int svc_len,
                   const char *acct, int acct_len,
                   char *out, int out_len) {
    char cmd[8192];
    int p = 0;
    const char *s1 = "secret-tool lookup service ";
    memcpy(cmd + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = sq_append(svc, svc_len, cmd, p, (int)sizeof(cmd));
    cmd[p++] = ' ';
    const char *s2 = "account ";
    memcpy(cmd + p, s2, strlen(s2)); p += (int)strlen(s2);
    p = sq_append(acct, acct_len, cmd, p, (int)sizeof(cmd));
    const char *s3 = " 2>/dev/null";
    memcpy(cmd + p, s3, strlen(s3)); p += (int)strlen(s3);
    cmd[p] = '\0';

    FILE *pipe = popen(cmd, "r");
    if (!pipe) return -1;
    int n = (int)fread(out, 1, out_len - 1, pipe);
    pclose(pipe);
    if (n < 0) n = 0;
    out[n] = '\0';
    while (n > 0 && (out[n-1] == '\n' || out[n-1] == '\r')) out[--n] = '\0';
    return n;
}

int hd_keyring_set(const char *svc, int svc_len,
                   const char *acct, int acct_len,
                   const char *pass, int pass_len) {
    char cmd[8192];
    int p = 0;
    /* printf '%s' <pass> | secret-tool store --label=<svc> service <svc> account <acct> */
    const char *s1 = "printf '%s' ";
    memcpy(cmd + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = sq_append(pass, pass_len, cmd, p, (int)sizeof(cmd));
    const char *s2 = " | secret-tool store --label=";
    memcpy(cmd + p, s2, strlen(s2)); p += (int)strlen(s2);
    p = sq_append(svc, svc_len, cmd, p, (int)sizeof(cmd));
    const char *s3 = " service ";
    memcpy(cmd + p, s3, strlen(s3)); p += (int)strlen(s3);
    p = sq_append(svc, svc_len, cmd, p, (int)sizeof(cmd));
    const char *s4 = " account ";
    memcpy(cmd + p, s4, strlen(s4)); p += (int)strlen(s4);
    p = sq_append(acct, acct_len, cmd, p, (int)sizeof(cmd));
    const char *s5 = " 2>/dev/null";
    memcpy(cmd + p, s5, strlen(s5)); p += (int)strlen(s5);
    cmd[p] = '\0';
    return system(cmd) == 0 ? 0 : -1;
}

int hd_keyring_delete(const char *svc, int svc_len,
                      const char *acct, int acct_len) {
    char cmd[8192];
    int p = 0;
    const char *s1 = "secret-tool clear service ";
    memcpy(cmd + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = sq_append(svc, svc_len, cmd, p, (int)sizeof(cmd));
    const char *s2 = " account ";
    memcpy(cmd + p, s2, strlen(s2)); p += (int)strlen(s2);
    p = sq_append(acct, acct_len, cmd, p, (int)sizeof(cmd));
    const char *s3 = " 2>/dev/null";
    memcpy(cmd + p, s3, strlen(s3)); p += (int)strlen(s3);
    cmd[p] = '\0';
    return system(cmd) == 0 ? 0 : -1;
}

/* ------------------------------------------------------------------ */
/* Keyring – Windows (PasswordVault via PowerShell)                     */
/* ------------------------------------------------------------------ */
#elif defined(_WIN32)

/* Helper: escape a string for a PowerShell single-quoted string.
   Only single-quote needs doubling in PS single-quoted strings. */
static int ps_escape(const char *s, int len, char *out, int pos, int max) {
    if (pos >= max - 2) return pos;
    out[pos++] = '\'';
    for (int i = 0; i < len && pos < max - 3; i++) {
        if (s[i] == '\'') { out[pos++] = '\''; out[pos++] = '\''; }
        else               { out[pos++] = s[i]; }
    }
    if (pos < max - 1) out[pos++] = '\'';
    return pos;
}

static int ps_run(const char *ps_cmd, char *out, int out_len) {
    char cmd[16384];
    snprintf(cmd, sizeof(cmd),
             "powershell -NoProfile -NonInteractive -Command \"%s\"", ps_cmd);
    FILE *pipe = popen(cmd, "r");
    if (!pipe) return -1;
    int n = out ? (int)fread(out, 1, out_len - 1, pipe) : 0;
    pclose(pipe);
    if (!out) return 0;
    if (n < 0) n = 0;
    out[n] = '\0';
    while (n > 0 && (out[n-1] == '\n' || out[n-1] == '\r' || out[n-1] == ' '))
        out[--n] = '\0';
    return n;
}

#define PV_LOAD \
    "[void][Windows.Security.Credentials.PasswordVault," \
    "Windows.Security.Credentials,ContentType=WindowsRuntime];"

int hd_keyring_get(const char *svc, int svc_len,
                   const char *acct, int acct_len,
                   char *out, int out_len) {
    char ps[4096];
    int p = 0;
    const char *s1 = PV_LOAD
        "$v=New-Object Windows.Security.Credentials.PasswordVault;"
        "try{$c=$v.Retrieve(";
    memcpy(ps + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = ps_escape(svc, svc_len, ps, p, (int)sizeof(ps));
    ps[p++] = ',';
    p = ps_escape(acct, acct_len, ps, p, (int)sizeof(ps));
    const char *s2 = ");$c.RetrievePassword();Write-Output $c.Password}catch{}";
    memcpy(ps + p, s2, strlen(s2)); p += (int)strlen(s2);
    ps[p] = '\0';
    return ps_run(ps, out, out_len);
}

int hd_keyring_set(const char *svc, int svc_len,
                   const char *acct, int acct_len,
                   const char *pass, int pass_len) {
    char ps[4096];
    int p = 0;
    const char *s1 = PV_LOAD
        "$v=New-Object Windows.Security.Credentials.PasswordVault;"
        "try{$c=$v.Retrieve(";
    memcpy(ps + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = ps_escape(svc, svc_len, ps, p, (int)sizeof(ps));
    ps[p++] = ',';
    p = ps_escape(acct, acct_len, ps, p, (int)sizeof(ps));
    const char *s2 = ");$v.Remove($c)}catch{};"
        "$c=New-Object Windows.Security.Credentials.PasswordCredential(";
    memcpy(ps + p, s2, strlen(s2)); p += (int)strlen(s2);
    p = ps_escape(svc, svc_len, ps, p, (int)sizeof(ps));
    ps[p++] = ',';
    p = ps_escape(acct, acct_len, ps, p, (int)sizeof(ps));
    ps[p++] = ',';
    p = ps_escape(pass, pass_len, ps, p, (int)sizeof(ps));
    const char *s3 = ");$v.Add($c)";
    memcpy(ps + p, s3, strlen(s3)); p += (int)strlen(s3);
    ps[p] = '\0';
    return ps_run(ps, NULL, 0);
}

int hd_keyring_delete(const char *svc, int svc_len,
                      const char *acct, int acct_len) {
    char ps[4096];
    int p = 0;
    const char *s1 = PV_LOAD
        "$v=New-Object Windows.Security.Credentials.PasswordVault;"
        "try{$c=$v.Retrieve(";
    memcpy(ps + p, s1, strlen(s1)); p += (int)strlen(s1);
    p = ps_escape(svc, svc_len, ps, p, (int)sizeof(ps));
    ps[p++] = ',';
    p = ps_escape(acct, acct_len, ps, p, (int)sizeof(ps));
    const char *s2 = ");$v.Remove($c)}catch{}";
    memcpy(ps + p, s2, strlen(s2)); p += (int)strlen(s2);
    ps[p] = '\0';
    return ps_run(ps, NULL, 0);
}

#endif /* OS-specific keyring */
