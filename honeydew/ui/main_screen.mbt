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
    @layout.Percentage(@app.schema_width_percent),
    @layout.Percentage(100 - @app.schema_width_percent),
  ]).split(main_area)
  // Right side: editor (35%) | results (65%)
  let right_rows = @layout.Layout::new(@layout.Vertical, [
    @layout.Percentage(@app.editor_height_percent),
    @layout.Percentage(@app.results_height_percent),
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
    .title(" Objects ")
    .borders(@widget.Borders::all())
    .border_style(schema_border_style)
  let tree = state.schema_tree.block(schema_block)
  frame.render_widget(tree, schema_area)
  // ---- SQL editor ----
  let editor_focused = state.focus == @app.Editor
  let editor_border_style = if editor_focused {
    @style.Style::default().fg(@style.Cyan)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  let editor_block = @widget.Block::new()
    .title(
      " SQL (Ctrl+Enter=run current  Ctrl+F=find  Ctrl+O=open  Ctrl+X=EXPLAIN  F5=run all) ",
    )
    .borders(@widget.Borders::all())
    .border_style(editor_border_style)
  frame.render_widget(editor_block, editor_area)
  let editor_inner = editor_block.inner(editor_area)
  let show_editor_bar = (
      state.file_prompt is Some(_) || state.search_input is Some(_)
    ) &&
    editor_inner.height > 1
  let editor_rows = if show_editor_bar {
    @layout.Layout::new(@layout.Vertical, [@layout.Min(0), @layout.Length(1)]).split(
      editor_inner,
    )
  } else {
    [editor_inner]
  }
  let sql_widget = state.sql_input
    .focused(
      editor_focused && !state.search_editing && state.file_prompt is None,
    )
    .show_line_numbers(true)
  frame.render_widget(sql_widget, editor_rows[0])
  match (state.file_prompt, state.search_input) {
    (Some(input), _) if editor_rows.length() > 1 => {
      let search_area = editor_rows[1]
      let cols = @layout.Layout::new(@layout.Horizontal, [
        @layout.Length(6),
        @layout.Min(0),
      ]).split(search_area)
      frame.render_widget(
        @widget.Paragraph::new("Open: ").style(
          @style.Style::default().fg(@style.Cyan),
        ),
        cols[0],
      )
      frame.render_widget(input.focused(true), cols[1])
    }
    (None, Some(input)) if editor_rows.length() > 1 => {
      let search_area = editor_rows[1]
      let count_width = 10
      let cols = @layout.Layout::new(@layout.Horizontal, [
        @layout.Length(6),
        @layout.Min(0),
        @layout.Length(count_width),
      ]).split(search_area)
      frame.render_widget(
        @widget.Paragraph::new("Find: ").style(
          @style.Style::default().fg(@style.Cyan),
        ),
        cols[0],
      )
      let search_input = input.focused(state.search_editing)
      frame.render_widget(search_input, cols[1])
      let match_count = if state.search_matches.length() == 0 {
        "0/0"
      } else {
        "\{state.search_match_index + 1}/\{state.search_matches.length()}"
      }
      frame.render_widget(
        @widget.Paragraph::new(match_count).style(
          @style.Style::default().fg(@style.BrightBlack),
        ),
        cols[2],
      )
    }
    _ => ()
  }
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
  let is_error = state.status.contains("Error")
  let status_style = if is_error {
    @style.Style::default().fg(@style.Red).bg(@style.Black)
  } else {
    @style.Style::default().fg(@style.White).bg(@style.Black)
  }
  let status_text = if is_error {
    let hint = "  Ctrl+E=details"
    let prefix = " \{state.status}"
    let avail = status_area.width - hint.length()
    let left = if prefix.length() > avail {
      prefix[0:avail].to_string()
    } else {
      let pad = avail - prefix.length()
      prefix + String::make(pad, ' ')
    }
    left + hint
  } else {
    " \{state.status}"
  }
  frame.render_widget(
    @widget.Paragraph::new(status_text).style(status_style),
    status_area,
  )
  if state.show_help {
    render_help_overlay(frame, state)
  } else if state.show_error {
    render_error_overlay(frame, state)
  }
}
