///|
pub fn copy_to_clipboard(text : String) -> Result[Unit, String] {
  let bytes = str_to_bytes(text)
  if hd_copy_to_clipboard(bytes, bytes.length()) == 0 {
    Ok(())
  } else {
    Err("Could not copy to clipboard")
  }
}
