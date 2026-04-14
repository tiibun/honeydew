///|
/// Integration tests for the MoonMysqlConn adapter.
/// Requires a running MySQL/MariaDB instance (docker compose up -d).
/// Skipped automatically when the database is unavailable.

///|
fn try_connect(group : @async.TaskGroup[Unit]) -> @moon_mysql.MoonMysqlConn? {
  Some(
    @moon_mysql.MoonMysqlConn::connect(
      "127.0.0.1", 3306, "testdb", "testuser", "testpass", group,
    ),
  ) catch {
    _ => None
  }
}

///|
async test "integration: SELECT 1" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        let result = conn.query("SELECT 1 AS n")
        match result {
          Err(e) => fail("query failed: \{e}")
          Ok(r) => {
            assert_eq(r.columns, ["n"])
            assert_eq(r.rows, [["1"]])
            assert_eq(r.affected_rows, None)
          }
        }
        conn.close()
      }
    }
  })
}

///|
async test "integration: DDL returns empty result" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        let result = conn.query(
          "CREATE TABLE IF NOT EXISTS _mm_test_tmp (id INT PRIMARY KEY)",
        )
        match result {
          Err(e) => fail("DDL failed: \{e}")
          Ok(r) => {
            assert_eq(r.columns, ([] : Array[String]))
            assert_eq(r.rows, ([] : Array[Array[String]]))
          }
        }
        ignore(conn.query("DROP TABLE IF EXISTS _mm_test_tmp"))
        conn.close()
      }
    }
  })
}

///|
async test "integration: INSERT affected_rows" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        ignore(conn.query("DROP TABLE IF EXISTS _mm_test_ins"))
        ignore(
          conn.query(
            "CREATE TABLE _mm_test_ins (id INT PRIMARY KEY, v VARCHAR(32))",
          ),
        )
        let result = conn.query("INSERT INTO _mm_test_ins VALUES (1, 'a')")
        match result {
          Err(e) => fail("INSERT failed: \{e}")
          Ok(r) => assert_eq(r.affected_rows, Some(1))
        }
        ignore(conn.query("DROP TABLE _mm_test_ins"))
        conn.close()
      }
    }
  })
}

///|
async test "integration: async_start / async_poll / async_result" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        assert_true(conn.async_start("SELECT 42 AS n"))
        @async.pause()
        let mut status = conn.async_poll()
        if status == 1 {
          @async.pause()
          status = conn.async_poll()
        }
        assert_eq(status, 2)
        let result = conn.async_result(false)
        match result {
          Err(e) => fail("async_result failed: \{e}")
          Ok(r) => {
            assert_eq(r.columns, ["n"])
            assert_eq(r.rows, [["42"]])
          }
        }
        conn.close()
      }
    }
  })
}

///|
async test "integration: tables lists user tables" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        ignore(conn.query("DROP TABLE IF EXISTS _mm_tbl_test"))
        ignore(conn.query("CREATE TABLE _mm_tbl_test (id INT PRIMARY KEY)"))
        let result = conn.tables()
        match result {
          Err(e) => fail("tables() failed: \{e}")
          Ok(names) => assert_true(names.contains("_mm_tbl_test"))
        }
        ignore(conn.query("DROP TABLE _mm_tbl_test"))
        conn.close()
      }
    }
  })
}

///|
async test "integration: columns returns name and type" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        ignore(conn.query("DROP TABLE IF EXISTS _mm_col_test"))
        ignore(
          conn.query(
            "CREATE TABLE _mm_col_test (id INT PRIMARY KEY, name VARCHAR(64) NOT NULL)",
          ),
        )
        let result = conn.columns("_mm_col_test")
        match result {
          Err(e) => fail("columns() failed: \{e}")
          Ok(cols) => {
            assert_eq(cols.length(), 2)
            assert_eq(cols[0].name, "id")
            assert_true(cols[0].col_type.contains("int"))
            assert_eq(cols[1].name, "name")
            assert_true(cols[1].col_type.contains("varchar"))
          }
        }
        ignore(conn.query("DROP TABLE _mm_col_test"))
        conn.close()
      }
    }
  })
}

///|
async test "integration: NULL encoded as null_value sentinel" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        let result = conn.query("SELECT NULL AS n")
        match result {
          Err(e) => fail("query failed: \{e}")
          Ok(r) => assert_eq(r.rows[0][0], @db.null_value)
        }
        conn.close()
      }
    }
  })
}

///|
async test "integration: views() lists user views" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        ignore(conn.query("DROP VIEW IF EXISTS _mm_view_test"))
        ignore(conn.query("DROP TABLE IF EXISTS _mm_view_base"))
        ignore(conn.query("CREATE TABLE _mm_view_base (id INT PRIMARY KEY)"))
        ignore(
          conn.query(
            "CREATE VIEW _mm_view_test AS SELECT id FROM _mm_view_base",
          ),
        )
        let result = conn.views()
        match result {
          Err(e) => fail("views() failed: \{e}")
          Ok(names) => assert_true(names.contains("_mm_view_test"))
        }
        ignore(conn.query("DROP VIEW _mm_view_test"))
        ignore(conn.query("DROP TABLE _mm_view_base"))
        conn.close()
      }
    }
  })
}

///|
async test "integration: query with invalid SQL returns Err" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        match conn.query("THIS IS NOT VALID SQL") {
          Ok(_) => fail("expected error for invalid SQL")
          Err(msg) => assert_true(msg.length() > 0)
        }
        conn.close()
      }
    }
  })
}

///|
async test "integration: async_poll returns 0 when no task running" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        // No async_start called — should be idle
        assert_eq(conn.async_poll(), 0)
        conn.close()
      }
    }
  })
}

///|
async test "integration: async_result returns Err when called before async_start" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        match conn.async_result(false) {
          Ok(_) => fail("expected Err before any query")
          Err(msg) => assert_eq(msg, "no result available")
        }
        conn.close()
      }
    }
  })
}

///|
async test "integration: async_cancel does not panic" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        conn.async_cancel()
        conn.close()
      }
    }
  })
}

///|
async test "integration: execute with invalid DML returns Err" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        // INSERT into a non-existent table triggers @mysql_proto.execute error path
        match conn.query("INSERT INTO _mm_no_such_table VALUES (1)") {
          Ok(_) => fail("expected error for bad DML")
          Err(msg) => assert_true(msg.length() > 0)
        }
        conn.close()
      }
    }
  })
}

///|
async test "integration: tables and views return Err after close" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        conn.close()
        // After close the underlying TCP socket is gone — queries must fail
        match conn.tables() {
          Ok(_) => fail("expected Err after close")
          Err(msg) => assert_true(msg.length() > 0)
        }
        match conn.views() {
          Ok(_) => fail("expected Err after close")
          Err(msg) => assert_true(msg.length() > 0)
        }
      }
    }
  })
}

///|
async test "integration: columns returns Err after close" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        conn.close()
        match conn.columns("any_table") {
          Ok(_) => fail("expected Err after close")
          Err(msg) => assert_true(msg.length() > 0)
        }
      }
    }
  })
}

///|
async test "integration: async_poll returns 1 before task runs" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        assert_true(conn.async_start("SELECT 1"))
        // Poll immediately before yielding — task hasn't run yet
        let status = conn.async_poll()
        assert_eq(status, 1)
        // Now let it finish
        @async.pause()
        let _ = conn.async_poll()
        conn.close()
      }
    }
  })
}

///|
async test "integration: trait dispatch covers all methods" {
  @async.with_task_group(group => {
    match try_connect(group) {
      None => ()
      Some(conn) => {
        let handle : &@db.DbConn = conn
        // query
        match handle.query("SELECT 'ok' AS v") {
          Err(e) => fail("trait query failed: \{e}")
          Ok(r) => assert_eq(r.rows[0][0], "ok")
        }
        // tables, views, columns
        ignore(handle.tables())
        ignore(handle.views())
        ignore(handle.columns("_no_such_table_"))
        // async_start / async_poll / async_result
        ignore(handle.async_start("SELECT 2"))
        @async.pause()
        let status = handle.async_poll()
        if status == 1 {
          @async.pause()
          ignore(handle.async_poll())
        }
        ignore(handle.async_result(false))
        // cancel + close
        handle.cancel()
        handle.close()
      }
    }
  })
}
