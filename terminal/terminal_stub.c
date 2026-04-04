#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>

static struct termios original_termios;

// Enter raw mode: disable line buffering and echo
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

// Restore original terminal settings
int hd_exit_raw_mode(void) {
  return tcsetattr(STDIN_FILENO, TCSAFLUSH, &original_termios);
}

// Read one byte from stdin. Returns the byte value (0-255), or -1 on error.
int hd_read_byte(void) {
  unsigned char c;
  int n = read(STDIN_FILENO, &c, 1);
  if (n == 1) return (int)c;
  return -1;
}

// Get terminal size packed as (cols << 16) | rows.
// Returns -1 on error.
int hd_get_winsize(void) {
  struct winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) < 0) return -1;
  return ((int)ws.ws_col << 16) | (int)ws.ws_row;
}

// Write `len` bytes from `buf` to stdout and flush.
void hd_write(const char *buf, int len) {
  fwrite(buf, 1, (size_t)len, stdout);
  fflush(stdout);
}
