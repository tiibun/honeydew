///|
/// RawMode is a RAII guard for raw terminal mode.
/// Call `RawMode::enter()` to switch the terminal into raw mode.
/// The original settings are restored when `exit()` is called.
pub struct RawMode {
  active : Bool
}

///|
/// Enter raw mode. Returns an error string on failure.
pub fn RawMode::enter() -> Result[RawMode, String] {
  let ret = hd_enter_raw_mode()
  if ret < 0 {
    Err("failed to enter raw mode")
  } else {
    Ok({ active: true })
  }
}

///|
/// Restore the terminal to its original state.
pub fn RawMode::exit(self : RawMode) -> Result[Unit, String] {
  if self.active {
    let ret = hd_exit_raw_mode()
    if ret < 0 {
      return Err("failed to exit raw mode")
    }
  }
  Ok(())
}

///|
/// Read a single Key event from stdin (blocking).
pub fn read_key() -> Key {
  let b0 = hd_read_byte()
  if b0 != 27 {
    return Key::from_bytes([b0])
  }
  // ESC — try to read an escape sequence
  let b1 = hd_read_byte()
  if b1 < 0 {
    return Esc
  }
  if b1 != 91 {
    // ESC + something other than '['
    return Key::from_bytes([27, b1])
  }
  let b2 = hd_read_byte()
  if b2 < 0 {
    return Unknown([27, b1])
  }
  // ESC [ digit ~ sequences (e.g. PageUp/PageDown/Delete)
  if b2 >= 48 && b2 <= 57 {
    let b3 = hd_read_byte()
    return Key::from_bytes([27, b1, b2, b3])
  }
  Key::from_bytes([27, b1, b2])
}

///|
/// Return the current terminal size as (cols, rows).
pub fn get_size() -> Result[(Int, Int), String] {
  let packed = hd_get_winsize()
  if packed < 0 {
    Err("failed to get terminal size")
  } else {
    let cols = packed >> 16
    let rows = packed & 0xFFFF
    Ok((cols, rows))
  }
}

///|
/// Write a string directly to stdout (no newline, flushed immediately).
pub fn write(s : String) -> Unit {
  let bytes = string_to_utf8_bytes(s)
  hd_write(bytes, bytes.length())
}

///|
/// Convert a MoonBit String to a UTF-8 encoded Bytes.
fn string_to_utf8_bytes(str : String) -> Bytes {
  let res : Array[Byte] = []
  let len = str.length()
  let mut i = 0
  while i < len {
    let mut c = str.code_unit_at(i).to_int()
    if 0xD800 <= c && c <= 0xDBFF {
      c -= 0xD800
      i = i + 1
      let l = str.code_unit_at(i).to_int() - 0xDC00
      c = (c << 10) + l + 0x10000
    }
    if c < 0x80 {
      res.push(c.to_byte())
    } else if c < 0x800 {
      res.push((0xC0 + (c >> 6)).to_byte())
      res.push((0x80 + (c & 0x3F)).to_byte())
    } else if c < 0x10000 {
      res.push((0xE0 + (c >> 12)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 + (c & 0x3F)).to_byte())
    } else {
      res.push((0xF0 + (c >> 18)).to_byte())
      res.push((0x80 + ((c >> 12) & 0x3F)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 + (c & 0x3F)).to_byte())
    }
    i = i + 1
  }
  Bytes::from_array(res)
}
