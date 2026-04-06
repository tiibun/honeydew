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

// Reused across all read_byte() calls (single-threaded cooperative scheduler).

///|
let stdin_buf : FixedArray[Byte] = FixedArray::make(1, b'\x00')

///|
/// Read a single byte from stdin asynchronously. Returns -1 on EOF.
async fn read_byte() -> Int {
  let n = @async_stdio.stdin.read(stdin_buf, offset=0, max_len=1)
  if n == 0 {
    -1
  } else {
    stdin_buf[0].to_int()
  }
}

///|
/// Read a single Key event from stdin (async).
/// After an ESC byte, subsequent bytes are read with a 50 ms timeout
/// to distinguish bare ESC from escape sequences (arrow keys, etc.).
pub async fn read_key() -> Key {
  let b0 = read_byte()
  if b0 < 0 {
    return Unknown([])
  }
  // Multi-byte UTF-8: decode continuation bytes immediately (no timeout needed).
  if b0 >= 0xC2 && b0 <= 0xDF {
    // 2-byte sequence
    let b1 = read_byte()
    if b1 < 0 {
      return Unknown([b0])
    }
    let cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
    return Char(Int::unsafe_to_char(cp))
  }
  if b0 >= 0xE0 && b0 <= 0xEF {
    // 3-byte sequence (covers all Japanese hiragana/katakana/kanji)
    let b1 = read_byte()
    if b1 < 0 {
      return Unknown([b0])
    }
    let b2 = read_byte()
    if b2 < 0 {
      return Unknown([b0, b1])
    }
    let cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
    return Char(Int::unsafe_to_char(cp))
  }
  if b0 >= 0xF0 && b0 <= 0xF7 {
    // 4-byte sequence (emoji, rare CJK extension)
    let b1 = read_byte()
    if b1 < 0 {
      return Unknown([b0])
    }
    let b2 = read_byte()
    if b2 < 0 {
      return Unknown([b0, b1])
    }
    let b3 = read_byte()
    if b3 < 0 {
      return Unknown([b0, b1, b2])
    }
    let cp = ((b0 & 0x07) << 18) |
      ((b1 & 0x3F) << 12) |
      ((b2 & 0x3F) << 6) |
      (b3 & 0x3F)
    return Char(Int::unsafe_to_char(cp))
  }
  if b0 != 27 {
    return Key::from_bytes([b0])
  }
  // ESC — attempt to read the rest of the escape sequence within 50 ms.
  match
    @async.with_timeout_opt(50, async fn() {
      let b1 = read_byte()
      if b1 < 0 {
        return Esc
      }
      if b1 != 91 {
        return Key::from_bytes([27, b1])
      }
      let b2 = read_byte()
      if b2 < 0 {
        return Unknown([27, b1])
      }
      // X10 mouse report: ESC [ M <b> <x> <y>
      if b2 == 77 {
        let mb = read_byte()
        let mx = read_byte()
        let my = read_byte()
        if mb < 0 || mx < 0 || my < 0 {
          return Unknown([27, b1, b2])
        }
        // btn & 3: 0=left press, 3=release; ignore non-left-press events
        let btn = mb - 32
        if (btn & 3) == 0 {
          return MouseClick(mx - 32, my - 32)
        }
        return Unknown([27, b1, b2])
      }
      // Generic CSI sequence: read parameter/intermediate bytes until
      // a final byte (0x40–0x7E) terminates the sequence.
      // This handles sequences of any length (e.g. ESC [13;5u, ESC [27;5;13~).
      let seq : Array[Int] = [27, b1, b2]
      if b2 < 0x40 || b2 > 0x7E {
        // b2 is not a final byte — keep reading
        let mut done = false
        while !done {
          let bn = read_byte()
          if bn < 0 {
            done = true
          } else {
            seq.push(bn)
            if bn >= 0x40 && bn <= 0x7E {
              done = true
            }
          }
        }
      }
      Key::from_bytes(seq)
    }) {
    None => Esc // timeout → bare ESC
    Some(key) => key
  }
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
