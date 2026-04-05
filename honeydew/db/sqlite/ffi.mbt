///|
/// Raw C FFI bindings for the SQLite stub. Not intended for direct use
/// outside this package.

///|
#borrow(path)
extern "c" fn hd_sqlite_open(path : Bytes, len : Int) -> Int = "hd_sqlite_open"

///|
extern "c" fn hd_sqlite_close(id : Int) -> Unit = "hd_sqlite_close"

///|
#borrow(sql)
extern "c" fn hd_sqlite_prepare(conn_id : Int, sql : Bytes, len : Int) -> Int = "hd_sqlite_prepare"

///|
extern "c" fn hd_sqlite_finalize(stmt_id : Int) -> Unit = "hd_sqlite_finalize"

///|
/// Returns SQLITE_ROW (100), SQLITE_DONE (101), or negative on error.
extern "c" fn hd_sqlite_step(stmt_id : Int) -> Int = "hd_sqlite_step"

///|
extern "c" fn hd_sqlite_column_count(stmt_id : Int) -> Int = "hd_sqlite_column_count"

///|
#borrow(buf)
extern "c" fn hd_sqlite_column_name(
  stmt_id : Int,
  col : Int,
  buf : FixedArray[Byte],
  buf_len : Int,
) -> Int = "hd_sqlite_column_name"

///|
#borrow(buf)
extern "c" fn hd_sqlite_column_text(
  stmt_id : Int,
  col : Int,
  buf : FixedArray[Byte],
  buf_len : Int,
) -> Int = "hd_sqlite_column_text"

///|
#borrow(buf)
extern "c" fn hd_sqlite_errmsg(
  conn_id : Int,
  buf : FixedArray[Byte],
  buf_len : Int,
) -> Int = "hd_sqlite_errmsg"
