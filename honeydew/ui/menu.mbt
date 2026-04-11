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
pub fn render_menu_bar(frame : @honeytui.Frame, _state : @app.AppState) -> Unit {
  let area = frame.size()
  let bar_area = @layout.Rect::new(area.x, area.y, area.width, 1)
  let left = " honeydew "
  let right = " ?=Help  Ctrl+Q=Quit "
  let text = fill_row(left, right, area.width)
  let bar_style = @style.Style::default().fg(@style.Black).bg(@style.Cyan)
  frame.render_widget(@widget.Paragraph::new(text).style(bar_style), bar_area)
}

///|
/// Render a centered overlay showing the full error message.
pub fn render_error_overlay(
  frame : @honeytui.Frame,
  state : @app.AppState,
) -> Unit {
  let area = frame.size()
  let overlay_w = if area.width > 66 { 64 } else { area.width }
  let overlay_h = 8
  let ox = (area.width - overlay_w) / 2
  let oy = (area.height - overlay_h) / 2
  let overlay_area = @layout.Rect::new(
    if ox > 0 {
      ox
    } else {
      0
    },
    if oy > 0 {
      oy
    } else {
      0
    },
    overlay_w,
    overlay_h,
  )
  let inner_h = overlay_h - 2
  let inner_w = overlay_w - 2
  let block = @widget.Block::new()
    .title(" Error Details ")
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Red))
    .title_style(
      @style.Style::default().fg(@style.Red).add_modifier(@style.bold),
    )
  frame.render_widget(block, overlay_area)
  let inner = @layout.Rect::new(
    overlay_area.x + 1,
    overlay_area.y + 1,
    inner_w,
    inner_h,
  )
  let msg_area = @layout.Rect::new(
    inner.x,
    inner.y,
    inner.width,
    inner.height - 1,
  )
  frame.render_widget(
    @widget.Paragraph::new(state.status).style(
      @style.Style::default().fg(@style.White),
    ),
    msg_area,
  )
  let hint_area = @layout.Rect::new(
    inner.x,
    inner.y + inner.height - 1,
    inner.width,
    1,
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
  let help_w = 50
  let help_h = 13
  let hx = (area.width - help_w) / 2
  let hy = (area.height - help_h) / 2
  let ox = if hx > 0 { hx } else { 0 }
  let oy = if hy > 0 { hy } else { 0 }
  let ow = if help_w < area.width { help_w } else { area.width }
  let oh = if help_h < area.height { help_h } else { area.height }
  let overlay_area = @layout.Rect::new(area.x + ox, area.y + oy, ow, oh)
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
      " ↑ / ↓           scroll / select\n" +
      " Space / Enter    expand/collapse (objects)\n" +
      " ← / →           collapse / expand (objects)\n" +
      " e                show full error details\n" +
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
