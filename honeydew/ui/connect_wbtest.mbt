///|
async test "selected_profile_preview_fields shows sqlite details for selected profile" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      profiles: [
        {
          name: "local-sqlite",
          kind_idx: 0,
          host: "",
          port: 0,
          database: "/tmp/app.db",
          username: "",
          tls_enabled: false,
          ca_cert_path: "",
          client_cert_path: "",
          client_key_path: "",
          connect_timeout_secs: 10,
        },
      ],
      profile_idx: 0,
    }
    assert_eq(selected_profile_preview_fields(state), [
      ("Name", "local-sqlite"),
      ("DB", "SQLite"),
      ("Database path", "/tmp/app.db"),
    ])
  })
}

///|
async test "selected_profile_preview_fields shows server details for selected profile" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      profiles: [
        {
          name: "local-pg",
          kind_idx: 1,
          host: "db.internal",
          port: 5432,
          database: "appdb",
          username: "app",
          tls_enabled: true,
          ca_cert_path: "/tmp/ca.pem",
          client_cert_path: "",
          client_key_path: "",
          connect_timeout_secs: 12,
        },
      ],
      profile_idx: 0,
    }
    assert_eq(selected_profile_preview_fields(state), [
      ("Name", "local-pg"),
      ("DB", "PostgreSQL"),
      ("Host", "db.internal"),
      ("Port", "5432"),
      ("Database", "appdb"),
      ("User", "app"),
      ("Timeout", "12s"),
      ("TLS", "On"),
    ])
  })
}

///|
async test "selected_profile_preview_fields returns empty when selection is invalid" {
  @async.with_task_group(group => {
    let state = {
      ..@app.AppState::new(group),
      profiles: [
        {
          name: "local-pg",
          kind_idx: 1,
          host: "db.internal",
          port: 5432,
          database: "appdb",
          username: "app",
          tls_enabled: false,
          ca_cert_path: "",
          client_cert_path: "",
          client_key_path: "",
          connect_timeout_secs: 10,
        },
      ],
      profile_idx: 3,
    }
    assert_eq(selected_profile_preview_fields(state), [])
  })
}
