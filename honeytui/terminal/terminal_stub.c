#ifdef _WIN32
/* ===== Windows implementation ===== */
#include <windows.h>
#include <conio.h>
#include <stdio.h>

int hd_setup_sigwinch(int write_fd) { (void)write_fd; return 0; }
int hd_cleanup_sigwinch(void) { return 0; }

static DWORD original_in_mode;
static DWORD original_out_mode;
static UINT  original_cp_in;
static UINT  original_cp_out;

int hd_enter_raw_mode(void) {
  HANDLE hin  = GetStdHandle(STD_INPUT_HANDLE);
  HANDLE hout = GetStdHandle(STD_OUTPUT_HANDLE);
  if (hin == INVALID_HANDLE_VALUE || hout == INVALID_HANDLE_VALUE) return -1;
  if (!GetConsoleMode(hin,  &original_in_mode))  return -1;
  if (!GetConsoleMode(hout, &original_out_mode)) return -1;

  /* Disable echo, line buffering, and Ctrl-C signal so we get raw bytes */
  DWORD in_mode = original_in_mode &
    ~(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT);
  if (!SetConsoleMode(hin, in_mode)) return -1;

  /* Enable VT/ANSI processing so our escape sequences render correctly */
  DWORD out_mode = original_out_mode |
    ENABLE_VIRTUAL_TERMINAL_PROCESSING | ENABLE_PROCESSED_OUTPUT;
  if (!SetConsoleMode(hout, out_mode)) {
    SetConsoleMode(hin, original_in_mode);  /* rollback input mode */
    return -1;
  }

  /* Use UTF-8 for both input and output; save originals for restore */
  original_cp_in  = GetConsoleCP();
  original_cp_out = GetConsoleOutputCP();
  SetConsoleCP(CP_UTF8);
  SetConsoleOutputCP(CP_UTF8);
  return 0;
}

int hd_exit_raw_mode(void) {
  HANDLE hin  = GetStdHandle(STD_INPUT_HANDLE);
  HANDLE hout = GetStdHandle(STD_OUTPUT_HANDLE);
  SetConsoleMode(hin,  original_in_mode);
  SetConsoleMode(hout, original_out_mode);
  SetConsoleCP(original_cp_in);
  SetConsoleOutputCP(original_cp_out);
  return 0;
}

/*
 * Windows key input buffer.
 * Arrow/nav keys from _getch() arrive as two-byte sequences (0 or 0xE0 + code).
 * We translate them into ANSI escape sequences so key.mbt can decode them
 * without any platform-specific logic.
 */
static int key_buf[4];
static int key_buf_len = 0;
static int key_buf_pos = 0;

/* Fill key_buf with ESC [ + up to 2 payload bytes and set its length. */
static void push_ansi(int len, int b2, int b3) {
  key_buf[0] = 27; key_buf[1] = 91; key_buf[2] = b2; key_buf[3] = b3;
  key_buf_len = len; key_buf_pos = 0;
}

int hd_get_winsize(void) {
  HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
  CONSOLE_SCREEN_BUFFER_INFO csbi;
  if (!GetConsoleScreenBufferInfo(h, &csbi)) return -1;
  int cols = csbi.srWindow.Right  - csbi.srWindow.Left + 1;
  int rows = csbi.srWindow.Bottom - csbi.srWindow.Top  + 1;
  return (cols << 16) | rows;
}

void hd_write(const char *buf, int len) {
  fwrite(buf, 1, (size_t)len, stdout);
  fflush(stdout);
}

#else
/* ===== POSIX implementation (macOS / Linux) ===== */
#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <fcntl.h>

static volatile int hd_sigwinch_write_fd = -1;

static void hd_sigwinch_handler(int sig) {
  (void)sig;
  char c = 1;
  write(hd_sigwinch_write_fd, &c, 1);
}

int hd_setup_sigwinch(int write_fd) {
  int new_fd = dup(write_fd);
  if (new_fd < 0) return -1;
  int flags = fcntl(new_fd, F_GETFL, 0);
  if (flags >= 0) fcntl(new_fd, F_SETFL, flags | O_NONBLOCK);
  hd_sigwinch_write_fd = new_fd;
  struct sigaction sa;
  sa.sa_handler = hd_sigwinch_handler;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;
  return sigaction(SIGWINCH, &sa, NULL);
}

int hd_cleanup_sigwinch(void) {
  signal(SIGWINCH, SIG_DFL);
  if (hd_sigwinch_write_fd >= 0) {
    close(hd_sigwinch_write_fd);
    hd_sigwinch_write_fd = -1;
  }
  return 0;
}

static struct termios original_termios;

int hd_enter_raw_mode(void) {
  if (tcgetattr(STDIN_FILENO, &original_termios) < 0) return -1;
  struct termios raw = original_termios;
  raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
  raw.c_oflag &= ~(OPOST);
  raw.c_cflag |=  (CS8);
  raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
  raw.c_cc[VMIN]  = 1;
  raw.c_cc[VTIME] = 0;
  if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) < 0) return -1;
  return 0;
}

int hd_exit_raw_mode(void) {
  return tcsetattr(STDIN_FILENO, TCSAFLUSH, &original_termios);
}

int hd_get_winsize(void) {
  struct winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) < 0) return -1;
  return ((int)ws.ws_col << 16) | (int)ws.ws_row;
}

void hd_write(const char *buf, int len) {
  fwrite(buf, 1, (size_t)len, stdout);
  fflush(stdout);
}

#endif
