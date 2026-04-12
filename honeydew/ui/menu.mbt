///|
/// Build a string that fills `width` columns:
/// `left` on the left, `right` on the right, spaces in between.
fn fill_row(left : String, right : String, width : Int) -> String {
  let used = left.length() + right.length()
  let gap = if width > used { width - used } else { 0 }
  let sb = StringBuilder::new()
  sb.write_string(left)
  for i = 0; i < gap; i = i + 1 {
    sb.write_char(' ')
  }
  sb.write_string(right)
  sb.to_string()
}

///|
/// Render the 1-row menu bar at the very top of the screen.
pub fn render_menu_bar(frame : @honeytui.Frame, state : @app.AppState) -> Unit {
  let area = frame.size()
  let bar_area = @layout.Rect::new(area.x, area.y, area.width, 1)
  let left = state.menu_bar_left_label()
  let right = " ?=Help  Ctrl+Q=Quit "
  let text = fill_row(left, right, area.width)
  let bar_style = if state.in_transaction {
    @style.Style::default().fg(@style.Black).bg(@style.Yellow)
  } else {
    @style.Style::default().fg(@style.Black).bg(@style.Cyan)
  }
  frame.render_widget(@widget.Paragraph::new(text).style(bar_style), bar_area)
}

///|
/// Render a centered overlay showing the full error message.
pub fn render_error_overlay(
  frame : @honeytui.Frame,
  state : @app.AppState,
) -> Unit {
  let area = frame.size()
  let overlay_area = @layout.Placement::centered(
    @layout.AtMost(64),
    @layout.AtMost(8),
  ).resolve(area)
  let block = @widget.Block::new()
    .title(" Error Details ")
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Red))
    .title_style(
      @style.Style::default().fg(@style.Red).add_modifier(@style.bold),
    )
  frame.render_widget(block, overlay_area)
  let inner = overlay_area.inner(1)
  let msg_area = @layout.Rect::new(
    inner.x,
    inner.y,
    inner.width,
    if inner.height > 1 {
      inner.height - 1
    } else {
      0
    },
  )
  frame.render_widget(
    @widget.Paragraph::new(state.status).style(
      @style.Style::default().fg(@style.White),
    ),
    msg_area,
  )
  let hint_area = @layout.Rect::new(
    inner.x,
    inner.y + (if inner.height > 0 { inner.height - 1 } else { 0 }),
    inner.width,
    if inner.height > 0 {
      1
    } else {
      0
    },
  )
  frame.render_widget(
    @widget.Paragraph::new("any key to close").style(
      @style.Style::default().fg(@style.BrightBlack),
    ),
    hint_area,
  )
}

///|
/// Render a centered help overlay with all key bindings.
pub fn render_help_overlay(
  frame : @honeytui.Frame,
  state : @app.AppState,
) -> Unit {
  let area = frame.size()
  let overlay_area = @layout.Placement::centered(
    @layout.AtMost(50),
    @layout.AtMost(16),
  ).resolve(area)
  let content = match state.screen {
    @app.Connect =>
      " Tab / Shift-Tab  next / prev field\n" +
      " ↑ / ↓           change DB type (when on DB row)\n" +
      " Enter            connect / load profile\n" +
      " Ctrl+S           save profile to keyring\n" +
      " d                delete selected profile\n" +
      " q / Ctrl+Q       quit\n" +
      "\n" +
      " ?                close this help"
    @app.Main =>
      " Tab              switch panel\n" +
      " Ctrl+Enter       run statement at cursor\n" +
      " F5               run all statements\n" +
      " Ctrl+C           cancel running query\n" +
      " Ctrl+S           export results as CSV\n" +
      " Ctrl+D           disconnect (return to Connect)\n" +
      " Ctrl+L           refresh schema browser\n" +
      " Ctrl+B           BEGIN transaction\n" +
      " Ctrl+M           COMMIT transaction\n" +
      " Ctrl+R           ROLLBACK transaction\n" +
      " ↑ / ↓           navigate; editor recalls history at top/bottom\n" +
      " y                copy selected result cell\n" +
      " Space / Enter    expand/collapse (objects)\n" +
      " ← / →           collapse / expand (objects)\n" +
      " Ctrl+E           show full error details\n" +
      " Ctrl+Q           quit\n" +
      "\n" +
      " ?                close this help"
  }
  let block = @widget.Block::new()
    .title(" Key Bindings ")
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Yellow))
    .title_style(
      @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold),
    )
  let para = @widget.Paragraph::new(content)
    .style(@style.Style::default().fg(@style.White))
    .block(block)
  frame.render_widget(para, overlay_area)
}
