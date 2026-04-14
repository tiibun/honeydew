///|
async test "ConnForm::field_count includes timeout and TLS fields for server connections" {
  @async.with_task_group(group => {
    let _ = group
    let form = { ..ConnForm::new(), kind_idx: 1 }
    assert_eq(form.field_count(), 10)
  })
}

///|
async test "AppState::do_connect rejects PostgreSQL certificate paths the driver cannot use" {
  @async.with_task_group(async fn(group) {
    let form = {
      ..ConnForm::new(),
      kind_idx: 1,
      host: @widget.Input::new().with_value("127.0.0.1"),
      port: @widget.Input::new().with_value("5432"),
      database: @widget.Input::new().with_value("appdb"),
      username: @widget.Input::new().with_value("app"),
      tls_enabled: true,
      ca_cert_path: @widget.Input::new().with_value("/tmp/ca.pem"),
    }
    let next = { ..AppState::new(group), conn_form: form }.do_connect()
    assert_true(next.conn is None)
    assert_true(next.conn_form.error.contains("certificate paths"))
  })
}

///|
async test "AppState::do_connect rejects MySQL TLS until the driver supports it" {
  @async.with_task_group(async fn(group) {
    let form = {
      ..ConnForm::new(),
      kind_idx: 2,
      host: @widget.Input::new().with_value("127.0.0.1"),
      port: @widget.Input::new().with_value("3306"),
      database: @widget.Input::new().with_value("appdb"),
      username: @widget.Input::new().with_value("app"),
      tls_enabled: true,
    }
    let next = { ..AppState::new(group), conn_form: form }.do_connect()
    assert_true(next.conn is None)
    assert_true(next.conn_form.error.contains("MySQL TLS"))
  })
}
