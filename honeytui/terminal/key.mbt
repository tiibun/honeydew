///|
/// A key event read from stdin in raw mode.
pub(all) enum Key {
  Char(Char)
  Enter
  Backspace
  Delete
  Esc
  Tab
  Up
  Down
  Left
  Right
  Home
  End
  PageUp
  PageDown
  CtrlC
  CtrlD
  CtrlL
  CtrlQ
  CtrlS
  CtrlZ
  Unknown(Array[Int])
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
      } else if b == 3 {
        CtrlC
      } else if b == 4 {
        CtrlD
      } else if b == 12 {
        CtrlL
      } else if b == 17 {
        CtrlQ
      } else if b == 19 {
        CtrlS
      } else if b == 26 {
        CtrlZ
      } else if b >= 32 && b < 128 {
        Char(Int::unsafe_to_char(b))
      } else {
        Unknown(bytes)
      }
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
