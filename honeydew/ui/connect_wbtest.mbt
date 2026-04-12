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
        },
      ],
      profile_idx: 3,
    }
    assert_eq(selected_profile_preview_fields(state), [])
  })
}
