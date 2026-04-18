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
  let right = " F1=Help  Ctrl+Q=Quit "
  let text = fill_row(left, right, area.width)
  let bar_style = if state.in_transaction {
    @style.Style::default().fg(@style.Black).bg(@style.Yellow)
  } else {
    @style.Style::default().fg(@style.Black).bg(@style.Cyan)
  }
  frame.render_widget(@widget.Paragraph::new(text).style(bar_style), bar_area)
}

///|
/// Render a centered overlay for parameterized-query input.
/// Shows one labeled Input field per placeholder extracted from the SQL.
/// When in save-preset mode, an extra name-input row is shown at the bottom.
/// When in pick-preset mode, the overlay is replaced with a snapshot list.
pub fn render_param_query_overlay(
  frame : @honeytui.Frame,
  state : @app.AppState,
) -> Unit {
  let form = match state.param_query_form {
    Some(f) => f
    None => return
  }
  let area = frame.size()
  let n = form.labels.length()
  let is_pick_mode = state.param_snap_pick_idx is Some(_)
  let is_save_mode = state.param_snap_name is Some(_)
  // Overlay height depends on current mode
  let overlay_h = if is_pick_mode {
    let m = state.param_snapshots.length()
    let h = m + 3 // m list rows + 2 borders + 1 hint inside
    if h > 22 {
      22
    } else if h < 5 {
      5
    } else {
      h
    }
  } else if is_save_mode {
    n + 4 // n fields + 2 borders + 1 name-input + 1 hint
  } else {
    n + 3 // n fields + 2 borders + 1 hint
  }
  let title = if is_pick_mode {
    " Load Preset "
  } else {
    " Run with Parameters "
  }
  let overlay_area = @layout.Placement::centered(
    @layout.AtMost(64),
    @layout.AtMost(overlay_h),
  ).resolve(area)
  let block = @widget.Block::new()
    .title(title)
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Cyan))
    .title_style(
      @style.Style::default().fg(@style.Cyan).add_modifier(@style.bold),
    )
    .style(@style.Style::default().bg(@style.Black))
  frame.render_widget(block, overlay_area)
  let inner = overlay_area.inner(1)
  if inner.height == 0 || inner.width == 0 {
    return
  }
  // Pick mode: replace form content with snapshot list
  if is_pick_mode {
    render_snap_pick_list(frame, state, inner)
    return
  }
  // Compute label column width from the longest label (minimum 6)
  let mut max_label_len = 6
  for label in form.labels {
    if label.length() > max_label_len {
      max_label_len = label.length()
    }
  }
  let label_col_width = max_label_len + 2
  // Reserve rows for hint (always) + name input (save mode)
  let bottom_reserved = if is_save_mode { 2 } else { 1 }
  let avail_field_rows = if inner.height > bottom_reserved {
    inner.height - bottom_reserved
  } else {
    0
  }
  let field_rows = if n < avail_field_rows { n } else { avail_field_rows }
  // Render each field row
  for i = 0; i < field_rows; i = i + 1 {
    let row_area = @layout.Rect::new(inner.x, inner.y + i, inner.width, 1)
    let row_cols = @layout.Layout::new(@layout.Horizontal, [
      @layout.Length(label_col_width),
      @layout.Min(0),
    ]).split(row_area)
    let label = form.labels[i]
    let label_style = if i == form.focus_idx {
      @style.Style::default().fg(@style.Cyan).add_modifier(@style.bold)
    } else {
      @style.Style::default().fg(@style.White)
    }
    frame.render_widget(
      @widget.Paragraph::new(" " + label).style(label_style),
      row_cols[0],
    )
    frame.render_widget(
      form.fields[i].focused(i == form.focus_idx),
      row_cols[1],
    )
  }
  // Name-input row (save mode only)
  if is_save_mode && inner.height >= 2 {
    let name_y = inner.y + inner.height - 2
    let name_area = @layout.Rect::new(inner.x, name_y, inner.width, 1)
    let name_cols = @layout.Layout::new(@layout.Horizontal, [
      @layout.Length(7),
      @layout.Min(0),
    ]).split(name_area)
    frame.render_widget(
      @widget.Paragraph::new("Name: ").style(
        @style.Style::default().fg(@style.Cyan),
      ),
      name_cols[0],
    )
    match state.param_snap_name {
      Some(input) => frame.render_widget(input.focused(true), name_cols[1])
      None => ()
    }
  }
  // Hint row at the bottom of the inner area
  if inner.height > 0 {
    let hint_y = inner.y + inner.height - 1
    let hint_area = @layout.Rect::new(inner.x, hint_y, inner.width, 1)
    let hint = if is_save_mode {
      " Enter=save preset  Esc=cancel"
    } else {
      " Tab=next  Enter=run  Ctrl+S=save preset  Ctrl+P=presets  Esc=cancel"
    }
    frame.render_widget(
      @widget.Paragraph::new(hint).style(
        @style.Style::default().fg(@style.BrightBlack),
      ),
      hint_area,
    )
  }
}

///|
/// Render the snapshot list inside the param overlay (pick mode).
fn render_snap_pick_list(
  frame : @honeytui.Frame,
  state : @app.AppState,
  inner : @layout.Rect,
) -> Unit {
  let selected_idx = match state.param_snap_pick_idx {
    Some(i) => i
    None => 0
  }
  let m = state.param_snapshots.length()
  let visible_rows = if inner.height > 1 { inner.height - 1 } else { 0 }
  // Scroll offset: keep the selected item centred in the viewport
  let scroll_start = if m <= visible_rows {
    0
  } else {
    let half = visible_rows / 2
    let ideal = if selected_idx > half { selected_idx - half } else { 0 }
    if ideal + visible_rows > m {
      m - visible_rows
    } else {
      ideal
    }
  }
  for i = 0; i < visible_rows && scroll_start + i < m; i = i + 1 {
    let snap_idx = scroll_start + i
    let row_area = @layout.Rect::new(inner.x, inner.y + i, inner.width, 1)
    let snap = state.param_snapshots[snap_idx]
    let style = if snap_idx == selected_idx {
      @style.Style::default().fg(@style.Black).bg(@style.Cyan)
    } else {
      @style.Style::default().fg(@style.White)
    }
    frame.render_widget(
      @widget.Paragraph::new(" " + snap.name).style(style),
      row_area,
    )
  }
  // Hint row
  if inner.height > 0 {
    let hint_y = inner.y + inner.height - 1
    let hint_area = @layout.Rect::new(inner.x, hint_y, inner.width, 1)
    frame.render_widget(
      @widget.Paragraph::new(" ↑↓=navigate  Enter=load preset  Esc=cancel").style(
        @style.Style::default().fg(@style.BrightBlack),
      ),
      hint_area,
    )
  }
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
    .style(@style.Style::default().bg(@style.Black))
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
        ("F1", "close this help"),
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
        ("F1", "close this help"),
      ]
  }
  let overlay_area = @layout.Placement::centered(
    @layout.AtMost(68),
    @layout.AtMost(bindings.length() + 2),
  ).resolve(area)
  let block = @widget.Block::new()
    .title(" Key Bindings ")
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Yellow))
    .title_style(
      @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold),
    )
    .style(@style.Style::default().bg(@style.Black))
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
