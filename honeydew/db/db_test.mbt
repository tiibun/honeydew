///|
test "QueryResult::empty" {
  let r = @db.QueryResult::empty()
  assert_eq(r.columns, ([] : Array[String]))
  assert_eq(r.rows, ([] : Array[Array[String]]))
  assert_eq(r.affected_rows, None)
}

///|
test "first_column" {
  assert_eq(@db.first_column([]), ([] : Array[String]))
  assert_eq(@db.first_column([["a", "b"], ["c", "d"]]), ["a", "c"])
  // empty row returns ""
  assert_eq(@db.first_column([[]]), [""])
}

///|
test "is_write_statement" {
  // writes
  assert_true(@db.is_write_statement("INSERT INTO t VALUES (1)"))
  assert_true(@db.is_write_statement("UPDATE t SET x=1"))
  assert_true(@db.is_write_statement("DELETE FROM t"))
  assert_true(@db.is_write_statement("CREATE TABLE t (id INT)"))
  assert_true(@db.is_write_statement("DROP TABLE t"))
  assert_true(@db.is_write_statement("ALTER TABLE t ADD COLUMN name TEXT"))
  assert_true(@db.is_write_statement("TRUNCATE TABLE t"))
  assert_true(@db.is_write_statement("REPLACE INTO t VALUES (1)"))
  // leading whitespace / mixed case
  assert_true(@db.is_write_statement("  insert into t values (1)"))
  assert_true(@db.is_write_statement("\nUPDATE t SET x=2"))
  // non-writes
  assert_false(@db.is_write_statement("SELECT 1"))
  assert_false(@db.is_write_statement(""))
}

///|
test "str_to_bytes: ASCII" {
  let b = @db.str_to_bytes("hi")
  assert_eq(b, b"hi")
}

///|
test "str_to_bytes: 2-byte UTF-8 (U+0080..U+07FF)" {
  // "é" = U+00E9 → UTF-8: 0xC3 0xA9
  let b = @db.str_to_bytes("é")
  assert_eq(b, (Bytes::from_array([0xC3, 0xA9]) : Bytes))
}

///|
test "str_to_bytes: 3-byte UTF-8 (U+0800..U+FFFF)" {
  // "中" = U+4E2D → UTF-8: 0xE4 0xB8 0xAD
  let b = @db.str_to_bytes("中")
  assert_eq(b, (Bytes::from_array([0xE4, 0xB8, 0xAD]) : Bytes))
}

///|
test "str_to_bytes: 4-byte UTF-8 surrogate pair (U+10000+)" {
  // "😀" = U+1F600 → UTF-16 surrogate pair → UTF-8: 0xF0 0x9F 0x98 0x80
  let b = @db.str_to_bytes("😀")
  assert_eq(b, (Bytes::from_array([0xF0, 0x9F, 0x98, 0x80]) : Bytes))
}

///|
test "fixed_bytes_to_str: ASCII" {
  let buf : FixedArray[Byte] = [b'h', b'i']
  assert_eq(@db.fixed_bytes_to_str(buf, 2), "hi")
}

///|
test "fixed_bytes_to_str: 2-byte UTF-8" {
  // "é" = 0xC3 0xA9
  let buf : FixedArray[Byte] = [0xC3, 0xA9]
  assert_eq(@db.fixed_bytes_to_str(buf, 2), "é")
}

///|
test "fixed_bytes_to_str: 3-byte UTF-8" {
  // "中" = 0xE4 0xB8 0xAD
  let buf : FixedArray[Byte] = [0xE4, 0xB8, 0xAD]
  assert_eq(@db.fixed_bytes_to_str(buf, 3), "中")
}

///|
test "fixed_bytes_to_str: 4-byte UTF-8" {
  // "😀" = U+1F600 → 0xF0 0x9F 0x98 0x80
  let buf = FixedArray::make(4, b'\x00')
  buf[0] = b'\xF0'
  buf[1] = b'\x9F'
  buf[2] = b'\x98'
  buf[3] = b'\x80'
  assert_eq(@db.fixed_bytes_to_str(buf, 4), "😀")
}

///|
test "fixed_bytes_to_str: truncated 4-byte sequence skips byte" {
  // A lone 0xF0 byte (4-byte leading byte with no continuation bytes)
  // does not satisfy `i + 3 < len`, so the else branch fires: i = i + 1.
  let buf = FixedArray::make(1, b'\x00')
  buf[0] = b'\xF0'
  assert_eq(@db.fixed_bytes_to_str(buf, 1), "")
}

///|
test "str_to_bytes and fixed_bytes_to_str round-trip" {
  let cases = ["hello", "café", "日本語", "😀🎉"]
  for s in cases {
    let bytes = @db.str_to_bytes(s)
    let fixed : FixedArray[Byte] = FixedArray::make(bytes.length(), b'\x00')
    for i, b in bytes {
      fixed[i] = b
    }
    assert_eq(@db.fixed_bytes_to_str(fixed, bytes.length()), s)
  }
}
