///|
/// Raw C FFI bindings for config_stub.c.

///|
extern "c" fn hd_get_os() -> Int = "hd_get_os"

///|
#borrow(buf)
extern "c" fn hd_home_dir(buf : FixedArray[Byte], buf_len : Int) -> Int = "hd_home_dir"

///|
#borrow(path)
extern "c" fn hd_mkdir_p(path : Bytes, path_len : Int) -> Int = "hd_mkdir_p"

///|
#borrow(path, buf)
extern "c" fn hd_file_read(
  path : Bytes,
  path_len : Int,
  buf : FixedArray[Byte],
  buf_len : Int,
) -> Int = "hd_file_read"

///|
#borrow(path, data)
extern "c" fn hd_file_write(
  path : Bytes,
  path_len : Int,
  data : Bytes,
  data_len : Int,
) -> Int = "hd_file_write"

///|
#borrow(data)
extern "c" fn hd_copy_to_clipboard(data : Bytes, data_len : Int) -> Int = "hd_copy_to_clipboard"

///|
#borrow(svc, acct, out)
extern "c" fn hd_keyring_get(
  svc : Bytes,
  svc_len : Int,
  acct : Bytes,
  acct_len : Int,
  out : FixedArray[Byte],
  out_len : Int,
) -> Int = "hd_keyring_get"

///|
#borrow(svc, acct, pass)
extern "c" fn hd_keyring_set(
  svc : Bytes,
  svc_len : Int,
  acct : Bytes,
  acct_len : Int,
  pass : Bytes,
  pass_len : Int,
) -> Int = "hd_keyring_set"

///|
#borrow(svc, acct)
extern "c" fn hd_keyring_delete(
  svc : Bytes,
  svc_len : Int,
  acct : Bytes,
  acct_len : Int,
) -> Int = "hd_keyring_delete"
