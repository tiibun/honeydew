///|
/// A key event read from stdin in raw mode.
pub(all) enum Key {
  Char(Char)
  Enter
  Backspace
  Delete
  Esc
  Tab
  ShiftTab
  Up
  Down
  Left
  Right
  Home
  End
  PageUp
  PageDown
  CtrlB
  CtrlC
  CtrlD
  CtrlE
  CtrlF
  CtrlJ
  CtrlL
  CtrlM
  CtrlO
  CtrlQ
  CtrlR
  CtrlS
  CtrlX
  CtrlY
  CtrlZ
  CtrlEnter
  F1
  F5
  /// Left mouse button click at (col, row), 1-indexed.
  MouseClick(Int, Int)
  Unknown(Array[Int])
  /// Terminal window was resized.
  Resize
} derive(Eq, Show)

///|
/// Decode a sequence of raw bytes into a Key.
/// Called after reading an escape sequence or a single byte.
pub fn Key::from_bytes(bytes : Array[Int]) -> Key {
  match bytes {
    [b] =>
      if b == 13 {
        Enter
      } else if b == 127 {
        Backspace
      } else if b == 27 {
        Esc
      } else if b == 9 {
        Tab
      } else if b == 2 {
        CtrlB
      } else if b == 3 {
        CtrlC
      } else if b == 4 {
        CtrlD
      } else if b == 5 {
        CtrlE
      } else if b == 6 {
        CtrlF
      } else if b == 10 {
        CtrlJ
      } else if b == 12 {
        CtrlL
      } else if b == 15 {
        CtrlO
      } else if b == 17 {
        CtrlQ
      } else if b == 18 {
        CtrlR
      } else if b == 19 {
        CtrlS
      } else if b == 24 {
        CtrlX
      } else if b == 25 {
        CtrlY
      } else if b == 26 {
        CtrlZ
      } else if b >= 32 && b < 128 {
        Char(Int::unsafe_to_char(b))
      } else {
        Unknown(bytes)
      }
    // Ctrl+Enter — multiple encodings used by different terminals:
    //   ESC [13;5u       kitty keyboard protocol (modifier after keycode)
    //   ESC [5;13~       some terminals (modifier before keycode, ~ terminator)
    //   ESC [27;5;13~    XTerm modifyOtherKeys=2
    [27, 91, 49, 51, 59, 53, 117] => CtrlEnter // ESC [13;5u
    [27, 91, 53, 59, 49, 51, 126] => CtrlEnter // ESC [5;13~
    [27, 91, 50, 55, 59, 53, 59, 49, 51, 126] => CtrlEnter // ESC [27;5;13~
    // Ctrl+E — escape sequences for terminals that encode it as a sequence:
    //   ESC [101;5u      kitty keyboard protocol
    //   ESC [27;5;101~   XTerm modifyOtherKeys=2
    [27, 91, 49, 48, 49, 59, 53, 117] => CtrlE // ESC [101;5u
    [27, 91, 50, 55, 59, 53, 59, 49, 48, 49, 126] => CtrlE // ESC [27;5;101~
    // Ctrl+M (COMMIT) — byte 13 collides with Enter, so we decode only escape sequences:
    //   ESC [109;5u      kitty keyboard protocol
    //   ESC [27;5;109~   XTerm modifyOtherKeys=2
    [27, 91, 49, 48, 57, 59, 53, 117] => CtrlM // ESC [109;5u
    [27, 91, 50, 55, 59, 53, 59, 49, 48, 57, 126] => CtrlM // ESC [27;5;109~
    // ESC OP    => F1 (VT100 / most modern terminals)
    [27, 79, 80] => F1
    // ESC [11~  => F1 (xterm / rxvt)
    [27, 91, 49, 49, 126] => F1
    // ESC [15~  => F5
    [27, 91, 49, 53, 126] => F5
    // ESC [ Z  => ShiftTab
    [27, 91, 90] => ShiftTab
    // ESC [ A  => Up
    [27, 91, 65] => Up
    // ESC [ B  => Down
    [27, 91, 66] => Down
    // ESC [ C  => Right
    [27, 91, 67] => Right
    // ESC [ D  => Left
    [27, 91, 68] => Left
    // ESC [ H  => Home
    [27, 91, 72] => Home
    // ESC [ F  => End
    [27, 91, 70] => End
    // ESC [ 5 ~  => PageUp
    [27, 91, 53, 126] => PageUp
    // ESC [ 6 ~  => PageDown
    [27, 91, 54, 126] => PageDown
    // ESC [ 3 ~  => Delete
    [27, 91, 51, 126] => Delete
    _ => Unknown(bytes)
  }
}
