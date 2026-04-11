///|
enum SqlHighlightMode {
  Normal
  StringLiteral
  BlockComment
}

///|
fn sql_keyword_style() -> @style.Style {
  @style.Style::default().fg(@style.Yellow).add_modifier(@style.bold)
}

///|
fn sql_string_style() -> @style.Style {
  @style.Style::default().fg(@style.Green)
}

///|
fn sql_comment_style() -> @style.Style {
  @style.Style::default().fg(@style.BrightBlack)
}

///|
fn sql_highlight_lines(text : String) -> Array[Array[(String, @style.Style)]] {
  let result : Array[Array[(String, @style.Style)]] = []
  let mut mode = Normal
  for line in split_highlight_lines(text) {
    let (segments, next_mode) = highlight_sql_line(line, mode)
    result.push(segments)
    mode = next_mode
  }
  result
}

///|
fn highlight_sql_line(
  line : String,
  mode : SqlHighlightMode,
) -> (Array[(String, @style.Style)], SqlHighlightMode) {
  let segments : Array[(String, @style.Style)] = []
  let len = line.length()
  let mut i = 0
  let mut current_mode = mode
  while i < len {
    match current_mode {
      StringLiteral => {
        let (end, closed) = scan_string_literal(line, i)
        push_styled_segment(
          segments,
          line[i:end].to_string(),
          sql_string_style(),
        )
        i = end
        current_mode = if closed { Normal } else { StringLiteral }
      }
      BlockComment => {
        let (end, closed) = scan_block_comment(line, i)
        push_styled_segment(
          segments,
          line[i:end].to_string(),
          sql_comment_style(),
        )
        i = end
        current_mode = if closed { Normal } else { BlockComment }
      }
      Normal =>
        if starts_with_two(line, i, '-'.to_int(), '-'.to_int()) {
          push_styled_segment(
            segments,
            line[i:].to_string(),
            sql_comment_style(),
          )
          i = len
        } else if starts_with_two(line, i, '/'.to_int(), '*'.to_int()) {
          let (end, closed) = scan_block_comment(line, i)
          push_styled_segment(
            segments,
            line[i:end].to_string(),
            sql_comment_style(),
          )
          i = end
          current_mode = if closed { Normal } else { BlockComment }
        } else if line[i].to_int() == '\''.to_int() {
          let (end, closed) = scan_string_literal(line, i)
          push_styled_segment(
            segments,
            line[i:end].to_string(),
            sql_string_style(),
          )
          i = end
          current_mode = if closed { Normal } else { StringLiteral }
        } else if is_ident_start(line, i) {
          let end = scan_ident(line, i)
          let word = line[i:end].to_string()
          let style = if is_sql_keyword(word) {
            sql_keyword_style()
          } else {
            @style.Style::default()
          }
          push_styled_segment(segments, word, style)
          i = end
        } else {
          let start = i
          i += 1
          while i < len && !starts_highlight_token(line, i) {
            i += 1
          }
          push_styled_segment(
            segments,
            line[start:i].to_string(),
            @style.Style::default(),
          )
        }
    }
  }
  (segments, current_mode)
}

///|
fn push_styled_segment(
  segments : Array[(String, @style.Style)],
  text : String,
  style : @style.Style,
) -> Unit {
  if text == "" {
    return
  }
  let last = segments.length() - 1
  if last >= 0 {
    let (prev_text, prev_style) = segments[last]
    if prev_style == style {
      segments[last] = ("\{prev_text}\{text}", prev_style)
      return
    }
  }
  segments.push((text, style))
}

///|
fn starts_highlight_token(line : String, idx : Int) -> Bool {
  starts_with_two(line, idx, '-'.to_int(), '-'.to_int()) ||
  starts_with_two(line, idx, '/'.to_int(), '*'.to_int()) ||
  line[idx].to_int() == '\''.to_int() ||
  is_ident_start(line, idx)
}

///|
fn starts_with_two(line : String, idx : Int, a : Int, b : Int) -> Bool {
  idx + 1 < line.length() &&
  line[idx].to_int() == a &&
  line[idx + 1].to_int() == b
}

///|
fn scan_string_literal(line : String, start : Int) -> (Int, Bool) {
  let len = line.length()
  let mut i = start + 1
  while i < len {
    if line[i].to_int() == '\''.to_int() {
      if i + 1 < len && line[i + 1].to_int() == '\''.to_int() {
        i += 2
      } else {
        return (i + 1, true)
      }
    } else {
      i += 1
    }
  }
  (len, false)
}

///|
fn scan_block_comment(line : String, start : Int) -> (Int, Bool) {
  let len = line.length()
  let mut i = start + 2
  while i + 1 < len {
    if line[i].to_int() == '*'.to_int() && line[i + 1].to_int() == '/'.to_int() {
      return (i + 2, true)
    }
    i += 1
  }
  (len, false)
}

///|
fn is_ident_start(line : String, idx : Int) -> Bool {
  let c = line[idx].to_int()
  (c >= 'A'.to_int() && c <= 'Z'.to_int()) ||
  (c >= 'a'.to_int() && c <= 'z'.to_int()) ||
  c == '_'.to_int()
}

///|
fn is_ident_part(line : String, idx : Int) -> Bool {
  let c = line[idx].to_int()
  is_ident_start(line, idx) || (c >= '0'.to_int() && c <= '9'.to_int())
}

///|
fn scan_ident(line : String, start : Int) -> Int {
  let len = line.length()
  let mut i = start + 1
  while i < len && is_ident_part(line, i) {
    i += 1
  }
  i
}

///|
fn is_sql_keyword(word : String) -> Bool {
  match word.to_upper() {
    "SELECT"
    | "INSERT"
    | "UPDATE"
    | "DELETE"
    | "FROM"
    | "WHERE"
    | "JOIN"
    | "LEFT"
    | "RIGHT"
    | "INNER"
    | "OUTER"
    | "ON"
    | "GROUP"
    | "ORDER"
    | "BY"
    | "LIMIT"
    | "OFFSET"
    | "HAVING"
    | "AS"
    | "AND"
    | "OR"
    | "NOT"
    | "NULL"
    | "CREATE"
    | "TABLE"
    | "VIEW"
    | "ALTER"
    | "DROP"
    | "INTO"
    | "VALUES"
    | "SET"
    | "BEGIN"
    | "COMMIT"
    | "ROLLBACK"
    | "DISTINCT" => true
    _ => false
  }
}

///|
fn split_highlight_lines(text : String) -> Array[String] {
  if text == "" {
    return [""]
  }
  let result : Array[String] = []
  let mut start = 0
  let len = text.length()
  for i = 0; i < len; i = i + 1 {
    if text[i].to_int() == '\n'.to_int() {
      result.push(text[start:i].to_string())
      start = i + 1
    }
  }
  result.push(text[start:].to_string())
  result
}
