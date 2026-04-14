///|
pub fn export_results_csv(
  columns : Array[String],
  rows : Array[Array[String]],
) -> Result[String, String] {
  if columns.length() == 0 {
    return Err("No results to export")
  }
  let dir = "\{config_dir()}/exports"
  let dir_b = str_to_bytes(dir)
  if hd_mkdir_p(dir_b, dir_b.length()) != 0 {
    return Err("Could not create export directory: \{dir}")
  }
  let path = "\{dir}/results.csv"
  let content = build_csv(columns, rows)
  match write_text_file(path, content) {
    Ok(_) => Ok(path)
    Err(msg) => Err(msg)
  }
}

///|
pub fn export_results_json(
  columns : Array[String],
  rows : Array[Array[String]],
) -> Result[String, String] {
  if columns.length() == 0 {
    return Err("No results to export")
  }
  let path = "\{config_dir()}/exports/results.json"
  let content = build_json(columns, rows)
  match write_text_file(path, content) {
    Ok(_) => Ok(path)
    Err(msg) => Err(msg)
  }
}

///|
pub fn read_text_file(path : String) -> Result[String, String] {
  let path_b = str_to_bytes(path)
  let buf : FixedArray[Byte] = FixedArray::make(262144, b'\x00')
  let n = hd_file_read(path_b, path_b.length(), buf, buf.length())
  if n < 0 {
    Err("Could not read file: \{path}")
  } else {
    Ok(fixed_bytes_to_str(buf, n))
  }
}

///|
pub fn write_text_file(path : String, content : String) -> Result[Unit, String] {
  let dir = parent_dir(path)
  if dir != "" {
    let dir_b = str_to_bytes(dir)
    if hd_mkdir_p(dir_b, dir_b.length()) != 0 {
      return Err("Could not create export directory: \{dir}")
    }
  }
  let path_b = str_to_bytes(path)
  let content_b = str_to_bytes(content)
  if hd_file_write(path_b, path_b.length(), content_b, content_b.length()) != 0 {
    Err("Could not write file: \{path}")
  } else {
    Ok(())
  }
}

///|
fn build_csv(columns : Array[String], rows : Array[Array[String]]) -> String {
  let sb = StringBuilder::new()
  append_csv_row(columns, sb)
  for row in rows {
    append_csv_row(row, sb)
  }
  sb.to_string()
}

///|
fn build_json(columns : Array[String], rows : Array[Array[String]]) -> String {
  let sb = StringBuilder::new()
  sb.write_char('[')
  for row_idx, row in rows {
    if row_idx > 0 {
      sb.write_char(',')
    }
    sb.write_char('{')
    for col_idx, column in columns {
      if col_idx > 0 {
        sb.write_char(',')
      }
      json_write_str(column, sb)
      sb.write_char(':')
      let value = if col_idx < row.length() { row[col_idx] } else { "" }
      json_write_str(value, sb)
    }
    sb.write_char('}')
  }
  sb.write_char(']')
  sb.to_string()
}

///|
fn append_csv_row(values : Array[String], sb : StringBuilder) -> Unit {
  for idx, value in values {
    if idx > 0 {
      sb.write_char(',')
    }
    sb.write_string(csv_escape(value))
  }
  sb.write_char('\n')
}

///|
fn csv_escape(value : String) -> String {
  if !needs_csv_quotes(value) {
    return value
  }
  let sb = StringBuilder::new()
  sb.write_char('"')
  for ch in value.iter() {
    if ch == '"' {
      sb.write_string("\"\"")
    } else {
      sb.write_char(ch)
    }
  }
  sb.write_char('"')
  sb.to_string()
}

///|
fn needs_csv_quotes(value : String) -> Bool {
  value.contains(",") ||
  value.contains("\"") ||
  value.contains("\n") ||
  value.contains("\r")
}

///|
fn parent_dir(path : String) -> String {
  let mut idx = path.length() - 1
  while idx >= 0 {
    if path[idx] == '/' {
      return path[:idx].to_string()
    }
    idx -= 1
  }
  ""
}
