///|
test "build_csv escapes headers and cells" {
  let csv = build_csv(["display,name", "detail"], [
    ["plain", ""],
    ["comma,value", "quote\"here"],
    ["line\nbreak", "carriage\rreturn"],
  ])
  assert_eq(
    csv,
    "\"display,name\",detail\n" +
    "plain,\n" +
    "\"comma,value\",\"quote\"\"here\"\n" +
    "\"line\nbreak\",\"carriage\rreturn\"\n",
  )
}

///|
test "export_results_csv rejects empty results" {
  let result = export_results_csv([], [])
  assert_eq(result, Err("No results to export"))
}

///|
test "export_results_csv writes CSV to the export path" {
  let path = "\{config_dir()}/exports/results.csv"
  let result = export_results_csv(["id", "name"], [["1", "Ada"]])
  assert_eq(result, Ok(path))
  let path_b = str_to_bytes(path)
  let buf : FixedArray[Byte] = FixedArray::make(1024, b'\x00')
  let n = hd_file_read(path_b, path_b.length(), buf, buf.length())
  assert_eq(fixed_bytes_to_str(buf, n), "id,name\n1,Ada\n")
}
