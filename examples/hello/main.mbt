///|
fn main {
  // Enter raw mode
  let raw = match @terminal.RawMode::enter() {
    Ok(r) => r
    Err(e) => {
      println("error: \{e}")
      return
    }
  }

  // Enter alternate screen and hide cursor
  @terminal.write(@terminal.enter_alternate_screen())
  @terminal.write(@terminal.cursor_hide())
  @terminal.write(@terminal.clear_all())

  // Get terminal size and center the message
  let msg = "Hello, honeydew!  (press q to quit)"
  let (cols, rows) = match @terminal.get_size() {
    Ok(s) => s
    Err(_) => (80, 24)
  }
  let col = (cols - msg.length()) / 2 + 1
  let row = rows / 2 + 1
  @terminal.write(@terminal.cursor_goto(col, row))
  @terminal.write(msg)

  // Event loop: quit on 'q' or Ctrl-C
  let mut running = true
  while running {
    match @terminal.read_key() {
      Char('q') | CtrlC => running = false
      _ => ()
    }
  }

  // Restore terminal
  @terminal.write(@terminal.cursor_show())
  @terminal.write(@terminal.leave_alternate_screen())
  let _ = raw.exit()

}
