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
/// Render a centered help overlay with all key bindings.
pub fn render_help_overlay(
  frame : @honeytui.Frame,
  state : @app.AppState,
) -> Unit {
  let area = frame.size()
  let help_w = 46
  let help_h = 11
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
      " Ctrl+Enter       run SQL (editor only)\n" +
      " ↑ / ↓           scroll / select\n" +
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
