///|
/// Raw C FFI bindings for the MySQL (libmysqlclient) stub.

///|
#borrow(host, db, user, pass)
extern "c" fn hd_mysql_connect(
  host : Bytes,
  host_len : Int,
  port : Int,
  db : Bytes,
  db_len : Int,
  user : Bytes,
  user_len : Int,
  pass : Bytes,
  pass_len : Int,
) -> Int = "hd_mysql_connect"

///|
extern "c" fn hd_mysql_close(id : Int) -> Unit = "hd_mysql_close"

///|
#borrow(buf)
extern "c" fn hd_mysql_errmsg(
  id : Int,
  buf : FixedArray[Byte],
  buf_len : Int,
) -> Int = "hd_mysql_errmsg"

///|
#borrow(sql)
extern "c" fn hd_mysql_exec(conn_id : Int, sql : Bytes, len : Int) -> Int = "hd_mysql_exec"

///|
extern "c" fn hd_mysql_result_free(res_id : Int) -> Unit = "hd_mysql_result_free"

///|
extern "c" fn hd_mysql_nrows(res_id : Int) -> Int = "hd_mysql_nrows"

///|
extern "c" fn hd_mysql_nfields(res_id : Int) -> Int = "hd_mysql_nfields"

///|
#borrow(buf)
extern "c" fn hd_mysql_fname(
  res_id : Int,
  col : Int,
  buf : FixedArray[Byte],
  buf_len : Int,
) -> Int = "hd_mysql_fname"

///|
#borrow(buf)
extern "c" fn hd_mysql_getvalue(
  res_id : Int,
  row_idx : Int,
  col : Int,
  buf : FixedArray[Byte],
  buf_len : Int,
) -> Int = "hd_mysql_getvalue"
