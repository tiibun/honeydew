///|
test "ANSI cursor_goto" {
  assert_eq(@terminal.cursor_goto(1, 1), "\u001b[1;1H")
  assert_eq(@terminal.cursor_goto(10, 5), "\u001b[5;10H")
}

///|
test "ANSI control sequences" {
  assert_eq(@terminal.cursor_hide(), "\u001b[?25l")
  assert_eq(@terminal.cursor_show(), "\u001b[?25h")
  assert_eq(@terminal.clear_all(), "\u001b[2J")
  assert_eq(@terminal.clear_eol(), "\u001b[K")
  assert_eq(@terminal.reset(), "\u001b[0m")
  assert_eq(@terminal.enter_alternate_screen(), "\u001b[?1049h")
  assert_eq(@terminal.leave_alternate_screen(), "\u001b[?1049l")
}

///|
test "Key::from_bytes - printable chars" {
  assert_eq(@terminal.Key::from_bytes([65]), Char('A'))
  assert_eq(@terminal.Key::from_bytes([97]), Char('a'))
  assert_eq(@terminal.Key::from_bytes([32]), Char(' '))
}

///|
test "Key::from_bytes - special keys" {
  assert_eq(@terminal.Key::from_bytes([13]), Enter)
  assert_eq(@terminal.Key::from_bytes([127]), Backspace)
  assert_eq(@terminal.Key::from_bytes([27]), Esc)
  assert_eq(@terminal.Key::from_bytes([9]), Tab)
}

///|
test "Key::from_bytes - control keys" {
  assert_eq(@terminal.Key::from_bytes([3]), CtrlC)
  assert_eq(@terminal.Key::from_bytes([4]), CtrlD)
  assert_eq(@terminal.Key::from_bytes([6]), CtrlF)
  assert_eq(@terminal.Key::from_bytes([10]), CtrlJ)
  assert_eq(@terminal.Key::from_bytes([15]), CtrlO)
  assert_eq(@terminal.Key::from_bytes([12]), CtrlL)
  assert_eq(@terminal.Key::from_bytes([17]), CtrlQ)
  assert_eq(@terminal.Key::from_bytes([19]), CtrlS)
  assert_eq(@terminal.Key::from_bytes([24]), CtrlX)
  assert_eq(@terminal.Key::from_bytes([25]), CtrlY)
  assert_eq(@terminal.Key::from_bytes([26]), CtrlZ)
}

///|
test "Key::from_bytes - arrow keys" {
  assert_eq(@terminal.Key::from_bytes([27, 91, 65]), Up)
  assert_eq(@terminal.Key::from_bytes([27, 91, 66]), Down)
  assert_eq(@terminal.Key::from_bytes([27, 91, 67]), Right)
  assert_eq(@terminal.Key::from_bytes([27, 91, 68]), Left)
}

///|
test "Key::from_bytes - navigation keys" {
  assert_eq(@terminal.Key::from_bytes([27, 91, 72]), Home)
  assert_eq(@terminal.Key::from_bytes([27, 91, 70]), End)
  assert_eq(@terminal.Key::from_bytes([27, 91, 53, 126]), PageUp)
  assert_eq(@terminal.Key::from_bytes([27, 91, 54, 126]), PageDown)
  assert_eq(@terminal.Key::from_bytes([27, 91, 51, 126]), Delete)
}

///|
test "Key::from_bytes - shift-tab" {
  assert_eq(@terminal.Key::from_bytes([27, 91, 90]), ShiftTab)
}

///|
test "Key::from_bytes - unknown sequence" {
  let k = @terminal.Key::from_bytes([27, 91, 255])
  assert_true(k is Unknown(_))
}

///|
test "Key::from_bytes - CtrlB (byte 2)" {
  assert_eq(@terminal.Key::from_bytes([2]), CtrlB)
}

///|
test "Key::from_bytes - CtrlR (byte 18)" {
  assert_eq(@terminal.Key::from_bytes([18]), CtrlR)
}

///|
test "Key::from_bytes - CtrlM escape sequences (kitty + xterm)" {
  // kitty keyboard protocol: ESC [109;5u
  assert_eq(@terminal.Key::from_bytes([27, 91, 49, 48, 57, 59, 53, 117]), CtrlM)
  // XTerm modifyOtherKeys=2: ESC [27;5;109~
  assert_eq(
    @terminal.Key::from_bytes([27, 91, 50, 55, 59, 53, 59, 49, 48, 57, 126]),
    CtrlM,
  )
}
