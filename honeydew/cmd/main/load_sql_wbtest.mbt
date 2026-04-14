///|
async test "CtrlO opens a file prompt and Enter loads the file into the editor" {
  @async.with_task_group(async fn(group) {
    let path = "\{@config.config_dir()}/exports/test-load.sql"
    match @config.write_text_file(path, "SELECT 42;") {
      Ok(_) => ()
      Err(e) => fail("write_text_file failed: \{e}")
    }
    let state = {
      ..@app.AppState::new(group),
      screen: @app.Main,
      focus: @app.Editor,
    }
    let opened = handle_key(state, CtrlO)
    assert_true(opened.file_prompt is Some(_))

    let mut typed = opened
    for ch in path.iter() {
      typed = handle_key(typed, Char(ch))
    }
    let loaded = handle_key(typed, Enter)
    assert_true(loaded.file_prompt is None)
    assert_eq(loaded.sql_input.value(), "SELECT 42;")
  })
}
