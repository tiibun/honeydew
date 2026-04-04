///|
struct App {
  mut count : Int
  mut running : Bool
}

///|
fn App::new() -> App {
  { count: 0, running: true }
}

///|
fn App::handle_key(self : App, key : @terminal.Key) -> Unit {
  match key {
    Char('q') | CtrlC => self.running = false
    Char('r') => self.count = 0
    Up | Char('k') | Char('+') => self.count = self.count + 1
    Down | Char('j') | Char('-') => self.count = self.count - 1
    _ => ()
  }
}

///|
fn App::render(self : App, frame : @honeydew.Frame) -> Unit {
  let area = frame.size()

  // Split into three rows: top padding / content / bottom padding
  let rows = @layout.Layout::new(
    @layout.Vertical,
    [
      @layout.Percentage(35),
      @layout.Length(7),
      @layout.Percentage(65),
    ],
  ).split(area)

  // Split the content row into three columns: left pad / content / right pad
  let cols = @layout.Layout::new(
    @layout.Horizontal,
    [
      @layout.Percentage(30),
      @layout.Percentage(40),
      @layout.Percentage(30),
    ],
  ).split(rows[1])

  let content_area = cols[1]

  // Choose color based on count sign
  let count_color = if self.count > 0 {
    @style.Green
  } else if self.count < 0 {
    @style.Red
  } else {
    @style.White
  }

  // Counter display
  let count_text = "Count: \{self.count}"
  let hint = "↑/k/+  increment    ↓/j/-  decrement    r  reset    q  quit"

  let block = @widget.Block::new()
    .title(" counter ")
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Cyan))
    .title_style(
      @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold),
    )

  let para = @widget.Paragraph::new(
    "\n  \{count_text}\n\n  \{hint}",
  )
    .style(@style.Style::default().fg(count_color))
    .block(block)

  frame.render_widget(para, content_area)
}

///|
fn main {
  let terminal = match @honeydew.Terminal::new() {
    Ok(t) => t
    Err(e) => {
      println("error: \{e}")
      return
    }
  }
  let app = App::new()
  while app.running {
    terminal.draw(fn(frame) { app.render(frame) })
    app.handle_key(terminal.read_key())
  }
  terminal.restore()
}
