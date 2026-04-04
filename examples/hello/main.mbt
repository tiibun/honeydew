///|
fn main {
  let terminal = match @honeydew.Terminal::new() {
    Ok(t) => t
    Err(e) => {
      println("error: \{e}")
      return
    }
  }

  let mut running = true
  while running {
    terminal.draw(fn(frame) {
      let area = frame.size()

      // Outer block taking the full screen
      let outer = @widget.Block::new()
        .title(" honeydew ")
        .borders(@widget.Borders::all())
        .border_style(
          @style.Style::default().fg(@style.Green),
        )
        .title_style(
          @style.Style::default()
          .fg(@style.Yellow)
          .add_modifier(@style.bold),
        )
      frame.render_widget(outer, area)

      // Center a paragraph inside the outer block
      let inner = @layout.Layout::new(
        @layout.Vertical,
        [@layout.Percentage(40), @layout.Percentage(20), @layout.Percentage(40)],
      ).split(area)
      let mid = @layout.Layout::new(
        @layout.Horizontal,
        [@layout.Percentage(20), @layout.Percentage(60), @layout.Percentage(20)],
      ).split(inner[1])

      let msg = @widget.Paragraph::new(
        "Hello from honeydew!\n\nPress q to quit.",
      )
        .style(@style.Style::default().fg(@style.Cyan))
        .block(
          @widget.Block::new()
          .borders(@widget.Borders::all())
          .border_style(@style.Style::default().fg(@style.Blue)),
        )
      frame.render_widget(msg, mid[1])
    })

    match terminal.read_key() {
      Char('q') | CtrlC => running = false
      _ => ()
    }
  }

  terminal.restore()
}
