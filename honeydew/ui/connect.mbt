///|
/// Render the connection screen with a left profile-list panel and a right form panel.
pub fn render_connect(frame : @honeytui.Frame, state : @app.AppState) -> Unit {
  let area = frame.size()
  render_menu_bar(frame, state)
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
  // Outer box: up to 82 wide, 16 tall, centred
  let box_area = @layout.Placement::centered(
    @layout.AtMost(82),
    @layout.AtMost(16),
  ).resolve(content)
  let form = state.conn_form
  let kind_label = @app.DbKind::label(db_kind(form.kind_idx))
  let outer_block = @widget.Block::new()
    .title(" honeydew — Connect to \{kind_label} ")
    .borders(@widget.Borders::all())
    .border_style(@style.Style::default().fg(@style.Cyan))
    .title_style(@style.Style::default().fg(@style.Yellow))
  frame.render_widget(outer_block, box_area)
  let inner = box_area.inner(1)
  // Split inner area: left=22, gap=1, right=rest
  let left_w = 22
  let gap = 1
  let right_w = if inner.width > left_w + gap {
    inner.width - left_w - gap
  } else {
    0
  }
  let left_area = @layout.Rect::new(inner.x, inner.y, left_w, inner.height)
  let right_area = @layout.Rect::new(
    inner.x + left_w + gap,
    inner.y,
    right_w,
    inner.height,
  )
  render_profile_panel(frame, state, left_area)
  render_form_panel(frame, state, right_area)
  if state.show_help {
    render_help_overlay(frame, state)
  }
}

///|
/// Left panel: list of saved profiles.
fn render_profile_panel(
  frame : @honeytui.Frame,
  state : @app.AppState,
  area : @layout.Rect,
) -> Unit {
  let profile_focus = state.conn_panel == @app.ProfileList
  let border_style = if profile_focus {
    @style.Style::default().fg(@style.Cyan)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  let block = @widget.Block::new()
    .title(" Profiles ")
    .borders(@widget.Borders::all())
    .border_style(border_style)
  frame.render_widget(block, area)
  let inner = @layout.Rect::new(
    area.x + 1,
    area.y + 1,
    if area.width > 2 {
      area.width - 2
    } else {
      0
    },
    if area.height > 2 {
      area.height - 2
    } else {
      0
    },
  )
  let names = state.profile_names()
  let max_rows = inner.height
  let visible_count = if names.length() < max_rows {
    names.length()
  } else {
    max_rows
  }
  for i = 0; i < visible_count; i = i + 1 {
    let row = @layout.Rect::new(inner.x, inner.y + i, inner.width, 1)
    let is_selected = i == state.profile_idx
    let prefix = if is_selected { "> " } else { "  " }
    let name = names[i]
    let max_name = if inner.width > 2 { inner.width - 2 } else { 0 }
    let display = if name.length() > max_name {
      name[0:max_name].to_string()
    } else {
      name
    }
    let text = "\{prefix}\{display}"
    let style = if is_selected && profile_focus {
      @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold)
    } else if is_selected {
      @style.Style::default().fg(@style.White).add_modifier(@style.bold)
    } else {
      @style.Style::default().fg(@style.White)
    }
    frame.render_widget(@widget.Paragraph::new(text).style(style), row)
  }
  // Bottom hint
  if inner.height > 0 {
    let hint_y = inner.y + (if inner.height > 1 { inner.height - 1 } else { 0 })
    let hint_row = @layout.Rect::new(inner.x, hint_y, inner.width, 1)
    let hint = if names.length() == 0 {
      "No profiles"
    } else {
      "↑↓=navigate"
    }
    frame.render_widget(
      @widget.Paragraph::new(hint).style(
        @style.Style::default().fg(@style.BrightBlack),
      ),
      hint_row,
    )
  }
}

///|
/// Right panel: connection form.
fn render_form_panel(
  frame : @honeytui.Frame,
  state : @app.AppState,
  area : @layout.Rect,
) -> Unit {
  let preview_fields = selected_profile_preview_fields(state)
  if state.conn_panel == @app.ProfileList && preview_fields.length() > 0 {
    let block = @widget.Block::new()
      .title(" Connection Info ")
      .borders(@widget.Borders::all())
      .border_style(@style.Style::default().fg(@style.BrightBlack))
    frame.render_widget(block, area)
    let inner = @layout.Rect::new(
      area.x + 1,
      area.y + 1,
      if area.width > 2 {
        area.width - 2
      } else {
        0
      },
      if area.height > 2 {
        area.height - 2
      } else {
        0
      },
    )
    let detail_rows = if inner.height > 1 {
      inner.height - 1
    } else {
      inner.height
    }
    let visible_count = if preview_fields.length() < detail_rows {
      preview_fields.length()
    } else {
      detail_rows
    }
    let label_w = 14
    for i = 0; i < visible_count; i = i + 1 {
      let (label, value) = preview_fields[i]
      let row = @layout.Rect::new(inner.x, inner.y + i, inner.width, 1)
      let value_w = if row.width > label_w { row.width - label_w } else { 0 }
      let value_text = if value_w <= 3 {
        ""
      } else if @buffer.str_display_width(value) <= value_w {
        value
      } else {
        @buffer.truncate_to_width(value, value_w - 3) + "..."
      }
      frame.render_widget(
        @widget.Paragraph::new("\{label}:").style(
          @style.Style::default().fg(@style.Cyan),
        ),
        @layout.Rect::new(row.x, row.y, label_w, 1),
      )
      frame.render_widget(
        @widget.Paragraph::new(value_text).style(
          @style.Style::default().fg(@style.White),
        ),
        @layout.Rect::new(row.x + label_w, row.y, value_w, 1),
      )
    }
    if inner.height > 0 {
      let hint_row = @layout.Rect::new(
        inner.x,
        inner.y + (inner.height - 1),
        inner.width,
        1,
      )
      frame.render_widget(
        @widget.Paragraph::new("Enter=load into form").style(
          @style.Style::default().fg(@style.BrightBlack),
        ),
        hint_row,
      )
    }
    return
  }
  let form_focus = state.conn_panel == @app.Form
  let border_style = if form_focus {
    @style.Style::default().fg(@style.Cyan)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  let block = @widget.Block::new()
    .borders(@widget.Borders::all())
    .border_style(border_style)
  frame.render_widget(block, area)
  let inner = @layout.Rect::new(
    area.x + 1,
    area.y + 1,
    if area.width > 2 {
      area.width - 2
    } else {
      0
    },
    if area.height > 2 {
      area.height - 2
    } else {
      0
    },
  )
  let form = state.conn_form
  let kind_label = @app.DbKind::label(db_kind(form.kind_idx))
  // Rows layout:
  // 0: Name field
  // 1: DB kind selector
  // 2: spacer
  // 3..7: connection text fields (up to 5)
  // 8: spacer
  // 9: error / hint
  let rows = @layout.Layout::new(@layout.Vertical, [
    @layout.Length(1), // 0: profile name
    @layout.Length(1), // 1: DB kind
    @layout.Length(1), // 2: spacer
    @layout.Length(1), // 3: field 1
    @layout.Length(1), // 4: field 2
    @layout.Length(1), // 5: field 3
    @layout.Length(1), // 6: field 4
    @layout.Length(1), // 7: field 5
    @layout.Length(1), // 8: spacer
    @layout.Min(1), // 9: error/hint
  ]).split(inner)
  // ── Row 0: Profile name ──
  let name_label = "Name: "
  let label_w = 10
  let input_w = if rows[0].width > label_w {
    rows[0].width - label_w
  } else {
    0
  }
  frame.render_widget(
    @widget.Paragraph::new(name_label).style(
      @style.Style::default().fg(@style.Cyan),
    ),
    @layout.Rect::new(rows[0].x, rows[0].y, label_w, 1),
  )
  let name_input = form.name.focused(form_focus && form.focus_idx == 0)
  frame.render_widget(
    name_input,
    @layout.Rect::new(rows[0].x + label_w, rows[0].y, input_w, 1),
  )
  // ── Row 1: DB kind ──
  let kind_text = "DB: [ \{kind_label} ]  (↑↓ to change)"
  let kind_style = if form_focus && form.focus_idx == 1 {
    @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold)
  } else {
    @style.Style::default().fg(@style.White)
  }
  frame.render_widget(
    @widget.Paragraph::new(kind_text).style(kind_style),
    rows[1],
  )
  // ── Rows 3..7: connection text fields ──
  let field_labels : Array[String] = match form.kind_idx {
    0 => ["Database path", "", "", "", ""]
    _ => ["Host", "Port", "Database", "User", "Password"]
  }
  let field_inputs : Array[@widget.Input] = match form.kind_idx {
    0 => [form.database, form.port, form.database, form.username, form.password]
    _ =>
      [
        form.host,
        form.port,
        form.database,
        form.username,
        form.password.masked(true),
      ]
  }
  let visible_fields = match form.kind_idx {
    0 => 1
    _ => 5
  }
  for fi = 0; fi < visible_fields; fi = fi + 1 {
    let row = rows[3 + fi]
    let label = field_labels[fi]
    let lw = 10
    let iw = if row.width > lw { row.width - lw } else { 0 }
    let label_area = @layout.Rect::new(row.x, row.y, lw, 1)
    let input_area = @layout.Rect::new(row.x + lw, row.y, iw, 1)
    frame.render_widget(
      @widget.Paragraph::new("\{label}: ").style(
        @style.Style::default().fg(@style.Cyan),
      ),
      label_area,
    )
    let is_focused = form_focus && form.focus_idx == fi + 2
    let input = field_inputs[fi].focused(is_focused)
    frame.render_widget(input, input_area)
  }
  // ── Row 9: Error or hint ──
  let bottom_text = if form.error != "" {
    form.error
  } else {
    "Enter=connect  Ctrl+S=save  Tab=switch  d=delete"
  }
  let bottom_style = if form.error != "" {
    @style.Style::default().fg(@style.Red)
  } else {
    @style.Style::default().fg(@style.BrightBlack)
  }
  frame.render_widget(
    @widget.Paragraph::new(bottom_text).style(bottom_style),
    rows[9],
  )
}

///|
fn db_kind(idx : Int) -> @app.DbKind {
  match idx {
    0 => @app.Sqlite
    1 => @app.Postgres
    _ => @app.Mysql
  }
}

///|
fn selected_profile_preview_fields(
  state : @app.AppState,
) -> Array[(String, String)] {
  let n = state.profiles.length()
  if state.profile_idx < 0 || state.profile_idx >= n {
    return []
  }
  let profile = state.profiles[state.profile_idx]
  let kind_label = @app.DbKind::label(db_kind(profile.kind_idx))
  match profile.kind_idx {
    0 =>
      [
        ("Name", profile.name),
        ("DB", kind_label),
        ("Database path", profile.database),
      ]
    _ =>
      [
        ("Name", profile.name),
        ("DB", kind_label),
        ("Host", profile.host),
        ("Port", if profile.port > 0 { profile.port.to_string() } else { "" }),
        ("Database", profile.database),
        ("User", profile.username),
      ]
  }
}
