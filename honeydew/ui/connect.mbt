///|
/// Render the connection form screen.
pub fn render_connect(frame : @honeytui.Frame, state : @app.AppState) -> Unit {
  let area = frame.size()
  render_menu_bar(frame, state)
  // Content area starts below the 1-row menu bar
  let content = @layout.Rect::new(
    area.x,
    area.y + 1,
    area.width,
    if area.height > 1 {
      area.height - 1
    } else {
      0
    },
  )
  // Centre a 60×14 box inside the content area
  let box_w = 60
  let box_h = 14
  let bx = (content.width - box_w) / 2
  let by = (content.height - box_h) / 2
  let bx2 = if bx > 0 { bx } else { 0 }
  let by2 = if by > 0 { by } else { 0 }
  let bw = if box_w < content.width { box_w } else { content.width }
  let bh = if box_h < content.height { box_h } else { content.height }
  let box_area = @layout.Rect::new(content.x + bx2, content.y + by2, bw, bh)
  let form = state.conn_form
  let kind_label = @app.DbKind::label(db_kind(form.kind_idx))
  let title = " honeydew — Connect to \{kind_label} "
  let outer_block = @widget.Block::new()
    .title(title)
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Cyan))
    .title_style(@style.Style::default().fg(@style.Yellow))
  frame.render_widget(outer_block, box_area)
  let inner = @layout.Rect::new(
    box_area.x + 1,
    box_area.y + 1,
    box_area.width - 2,
    box_area.height - 2,
  )
  // Split into rows
  let rows = @layout.Layout::new(@layout.Vertical, [
    @layout.Length(1), // 0: DB kind selector
    @layout.Length(1), // 1: spacer
    @layout.Length(1), // 2: field 1
    @layout.Length(1), // 3: field 2
    @layout.Length(1), // 4: field 3
    @layout.Length(1), // 5: field 4
    @layout.Length(1), // 6: field 5
    @layout.Length(1), // 7: spacer
    @layout.Length(1), // 8: error / hint
  ]).split(inner)
  // DB kind row
  let kind_text = "  DB: [ \{kind_label} ]  (↑↓ to change)"
  let kind_style = if form.focus_idx == 0 {
    @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold)
  } else {
    @style.Style::default().fg(@style.White)
  }
  frame.render_widget(
    @widget.Paragraph::new(kind_text).style(kind_style),
    rows[0],
  )
  // Field labels differ by DB kind
  let field_labels : Array[String] = match form.kind_idx {
    0 => ["Database path", "", "", "", ""]
    _ => ["Host", "Port", "Database", "User", "Password"]
  }
  let field_inputs : Array[@widget.Input] = match form.kind_idx {
    0 => [form.database, form.port, form.database, form.username, form.password]
    _ => [form.host, form.port, form.database, form.username, form.password]
  }
  let visible_fields = match form.kind_idx {
    0 => 1
    _ => 5
  }
  for fi = 0; fi < visible_fields; fi = fi + 1 {
    let row = rows[2 + fi]
    let label = field_labels[fi]
    let label_w = 16
    let input_w = if row.width > label_w { row.width - label_w } else { 0 }
    let label_area = @layout.Rect::new(row.x, row.y, label_w, 1)
    let input_area = @layout.Rect::new(row.x + label_w, row.y, input_w, 1)
    frame.render_widget(
      @widget.Paragraph::new("\{label}: ").style(
        @style.Style::default().fg(@style.Cyan),
      ),
      label_area,
    )
    let is_focused = form.focus_idx == fi + 1
    let input = field_inputs[fi].focused(is_focused)
    frame.render_widget(input, input_area)
  }
  // Error or hint at the bottom
  let bottom_text = if form.error != "" {
    form.error
  } else {
    "Tab/Shift-Tab=next/prev field  Enter=connect  ↑↓=change DB  q=quit"
  }
  let bottom_style = if form.error != "" {
    @style.Style::default().fg(@style.Red)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  frame.render_widget(
    @widget.Paragraph::new(bottom_text).style(bottom_style),
    rows[8],
  )
  if state.show_help {
    render_help_overlay(frame, state)
  }
}

///|
fn db_kind(idx : Int) -> @app.DbKind {
  match idx {
    0 => @app.Sqlite
    1 => @app.Postgres
    _ => @app.Mysql
  }
}
