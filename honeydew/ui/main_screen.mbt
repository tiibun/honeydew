///|
/// Render the main 3-pane screen: schema browser | SQL editor | results.
pub fn render_main(frame : @honeytui.Frame, state : @app.AppState) -> Unit {
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
  // Split content: main area (fills) | 1-row status bar at bottom
  let content_rows = @layout.Layout::new(@layout.Vertical, [
    @layout.Min(0),
    @layout.Length(1),
  ]).split(content)
  let main_area = content_rows[0]
  let status_area = content_rows[1]
  // Split main area horizontally: schema (28%) | right (72%)
  let cols = @layout.Layout::new(@layout.Horizontal, [
    @layout.Percentage(28),
    @layout.Percentage(72),
  ]).split(main_area)
  // Right side: editor (35%) | results (65%)
  let right_rows = @layout.Layout::new(@layout.Vertical, [
    @layout.Percentage(35),
    @layout.Percentage(65),
  ]).split(cols[1])
  let schema_area = cols[0]
  let editor_area = right_rows[0]
  let results_area = right_rows[1]
  // ---- Schema browser ----
  let schema_focused = state.focus == @app.Schema
  let schema_border_style = if schema_focused {
    @style.Style::default().fg(@style.Cyan)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  let schema_block = @widget.Block::new()
    .title(" Schema ")
    .borders(@widget.Borders::all())
    .border_style(schema_border_style)
  let list = state.schema_list.block(schema_block)
  frame.render_widget(list, schema_area)
  // ---- SQL editor ----
  let editor_focused = state.focus == @app.Editor
  let editor_border_style = if editor_focused {
    @style.Style::default().fg(@style.Cyan)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  let editor_block = @widget.Block::new()
    .title(" SQL (Ctrl+Enter=run) ")
    .borders(@widget.Borders::all())
    .border_style(editor_border_style)
  let sql_widget = state.sql_input.focused(editor_focused).block(editor_block)
  frame.render_widget(sql_widget, editor_area)
  // ---- Results ----
  let results_focused = state.focus == @app.Results
  let results_border_style = if results_focused {
    @style.Style::default().fg(@style.Cyan)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  let row_count = state.results.rows.length()
  let results_title = if row_count == 1 {
    " Results: 1 row "
  } else if row_count > 1 {
    " Results: \{row_count} rows "
  } else {
    " Results "
  }
  let results_block = @widget.Block::new()
    .title(results_title)
    .borders(@widget.Borders::all())
    .border_style(results_border_style)
  let tbl = state.results.block(results_block)
  frame.render_widget(tbl, results_area)
  // ---- Status bar ----
  let status_style = if state.status.contains("Error") {
    @style.Style::default().fg(@style.Red).bg(@style.Black)
  } else {
    @style.Style::default().fg(@style.White).bg(@style.Black)
  }
  frame.render_widget(
    @widget.Paragraph::new(" \{state.status}").style(status_style),
    status_area,
  )
  if state.show_help {
    render_help_overlay(frame, state)
  }
}
