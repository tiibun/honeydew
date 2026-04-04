#ifdef _WIN32
/* ===== Windows implementation ===== */
#include <windows.h>
#include <conio.h>
#include <stdio.h>

static DWORD original_in_mode;
static DWORD original_out_mode;

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
  if (!SetConsoleMode(hout, out_mode)) return -1;

  /* Use UTF-8 for both input and output */
  SetConsoleCP(CP_UTF8);
  SetConsoleOutputCP(CP_UTF8);
  return 0;
}

int hd_exit_raw_mode(void) {
  HANDLE hin  = GetStdHandle(STD_INPUT_HANDLE);
  HANDLE hout = GetStdHandle(STD_OUTPUT_HANDLE);
  SetConsoleMode(hin,  original_in_mode);
  SetConsoleMode(hout, original_out_mode);
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

static void push_ansi3(int b2) {
  key_buf[0] = 27; key_buf[1] = 91; key_buf[2] = b2;
  key_buf_len = 3; key_buf_pos = 0;
}

static void push_ansi4(int digit, int tilde) {
  key_buf[0] = 27; key_buf[1] = 91; key_buf[2] = digit; key_buf[3] = tilde;
  key_buf_len = 4; key_buf_pos = 0;
}

int hd_read_byte(void) {
  if (key_buf_pos < key_buf_len) return key_buf[key_buf_pos++];
  key_buf_len = 0; key_buf_pos = 0;

  int c = _getch();
  if (c != 0 && c != 0xE0) return c;  /* Normal ASCII or control byte */

  /* Extended key prefix: read the scan code */
  int scan = _getch();
  switch (scan) {
    case 0x48: push_ansi3(65);       break;  /* Up    -> ESC [ A */
    case 0x50: push_ansi3(66);       break;  /* Down  -> ESC [ B */
    case 0x4D: push_ansi3(67);       break;  /* Right -> ESC [ C */
    case 0x4B: push_ansi3(68);       break;  /* Left  -> ESC [ D */
    case 0x47: push_ansi3(72);       break;  /* Home  -> ESC [ H */
    case 0x4F: push_ansi3(70);       break;  /* End   -> ESC [ F */
    case 0x49: push_ansi4(53, 126);  break;  /* PgUp  -> ESC [ 5 ~ */
    case 0x51: push_ansi4(54, 126);  break;  /* PgDn  -> ESC [ 6 ~ */
    case 0x53: push_ansi4(51, 126);  break;  /* Del   -> ESC [ 3 ~ */
    default:   return -1;
  }
  return key_buf[key_buf_pos++];
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

int hd_read_byte(void) {
  unsigned char c;
  int n = read(STDIN_FILENO, &c, 1);
  if (n == 1) return (int)c;
  return -1;
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
