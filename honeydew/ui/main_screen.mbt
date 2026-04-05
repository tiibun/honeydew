///|
/// Render the main 3-pane screen: schema browser | SQL editor | results.
pub fn render_main(frame : @honeytui.Frame, state : @app.AppState) -> Unit {
  let area = frame.size()
  // Split horizontally: schema (30%) | right (70%)
  let cols = @layout.Layout::new(@layout.Horizontal, [
    @layout.Percentage(28),
    @layout.Percentage(72),
  ]).split(area)
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
    .title(" スキーマ ")
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
    .title(" SQL (Enter=実行) ")
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
    " 結果: 1行 "
  } else if row_count > 1 {
    " 結果: \{row_count}行 "
  } else {
    " 結果 "
  }
  let results_block = @widget.Block::new()
    .title(results_title)
    .borders(@widget.Borders::all())
    .border_style(results_border_style)
  let tbl = state.results.block(results_block)
  frame.render_widget(tbl, results_area)
  // ---- Status bar ----
  // Rendered as a 1-line Paragraph at the bottom of the screen
  // (already included in the layout since there's no explicit status row).
  // Instead, embed status in results title — already done above.
}
