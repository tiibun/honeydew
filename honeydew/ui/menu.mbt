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
    @layout.AtMost(68),
    @layout.AtMost(20),
  ).resolve(area)
  let bindings : Array[(String, String)] = match state.screen {
    @app.Connect =>
      [
        ("Tab / Shift-Tab", "next / prev field"),
        ("↑ / ↓", "change DB type (when on DB row)"),
        ("Enter", "connect / load profile"),
        ("Ctrl+S", "save profile to keyring"),
        ("d", "delete selected profile"),
        ("q / Ctrl+Q", "quit"),
        ("", ""),
        ("?", "close this help"),
      ]
    @app.Main =>
      [
        ("Tab", "switch panel"),
        ("Ctrl+Enter", "run statement at cursor"),
        ("Ctrl+F", "open editor search"),
        ("Enter", "leave search bar / accept search"),
        ("n / N", "next / previous search match"),
        ("Ctrl+X", "run EXPLAIN for statement at cursor"),
        ("F5", "run all statements"),
        ("Ctrl+C", "cancel running query"),
        ("Ctrl+S", "export results as CSV"),
        ("Ctrl+J", "export results as JSON"),
        ("Ctrl+O", "load SQL from file"),
        ("Ctrl+D", "disconnect (return to Connect)"),
        ("Ctrl+L", "refresh schema browser"),
        ("Ctrl+B", "BEGIN transaction"),
        ("Ctrl+M", "COMMIT transaction"),
        ("Ctrl+R", "ROLLBACK transaction"),
        ("↑ / ↓", "navigate; editor recalls history at top/bottom"),
        ("y", "copy selected result cell"),
        ("Y", "copy selected result row"),
        ("Space / Enter", "expand/collapse (objects)"),
        ("← / →", "collapse / expand (objects)"),
        ("Ctrl+E", "show full error details"),
        ("Ctrl+Q", "quit"),
        ("", ""),
        ("?", "close this help"),
      ]
  }
  let block = @widget.Block::new()
    .title(" Key Bindings ")
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Yellow))
    .title_style(
      @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold),
    )
  frame.render_widget(block, overlay_area)
  let inner = block.inner(overlay_area)
  // Split into one row per binding, then each row into key/description columns.
  // This prevents description wrap from misaligning subsequent rows.
  let row_constraints = Array::make(bindings.length(), @layout.Length(1))
  let rows = @layout.Layout::new(@layout.Vertical, row_constraints).split(inner)
  let text_style = @style.Style::default().fg(@style.White)
  // Longest key: "Tab / Shift-Tab" (15 cols) + 1 leading space + 2 trailing = 18
  for i = 0; i < bindings.length(); i = i + 1 {
    let (key, desc) = bindings[i]
    let cols = @layout.Layout::new(@layout.Horizontal, [
      @layout.Length(18),
      @layout.Min(0),
    ]).split(rows[i])
    let desc_width = cols[1].width
    let desc_text = if @buffer.str_display_width(desc) <= desc_width {
      desc
    } else {
      @buffer.truncate_to_width(desc, desc_width - 3) + "..."
    }
    frame.render_widget(
      @widget.Paragraph::new(" " + key).style(text_style),
      cols[0],
    )
    frame.render_widget(
      @widget.Paragraph::new(desc_text).style(text_style),
      cols[1],
    )
  }
}
