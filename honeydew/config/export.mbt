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
  let path_b = str_to_bytes(path)
  let content_b = str_to_bytes(content)
  if hd_file_write(path_b, path_b.length(), content_b, content_b.length()) != 0 {
    Err("Could not write CSV file: \{path}")
  } else {
    Ok(path)
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
