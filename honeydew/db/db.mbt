///|
/// Information about a single column returned by schema introspection.
pub(all) struct ColumnInfo {
  name : String
  col_type : String
}

///|
/// The result of a SELECT query: column names and rows of string values.
/// All cell values are represented as strings (NULL becomes "NULL").
pub(all) struct QueryResult {
  columns : Array[String]
  rows : Array[Array[String]]
}

///|
pub fn QueryResult::empty() -> QueryResult {
  { columns: [], rows: [] }
}

///|
/// Convert a MoonBit String to UTF-8 encoded Bytes.
pub fn str_to_bytes(str : String) -> Bytes {
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
      res.push((0xC0 | (c >> 6)).to_byte())
      res.push((0x80 | (c & 0x3F)).to_byte())
    } else if c < 0x10000 {
      res.push((0xE0 | (c >> 12)).to_byte())
      res.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 | (c & 0x3F)).to_byte())
    } else {
      res.push((0xF0 | (c >> 18)).to_byte())
      res.push((0x80 | ((c >> 12) & 0x3F)).to_byte())
      res.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 | (c & 0x3F)).to_byte())
    }
    i = i + 1
  }
  Bytes::from_array(res)
}

///|
/// Decode the first `len` bytes of a FixedArray[Byte] as UTF-8 into a String.
pub fn fixed_bytes_to_str(buf : FixedArray[Byte], len : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < len {
    let b0 = buf[i].to_int() & 0xFF
    if b0 < 0x80 {
      sb.write_char(Int::unsafe_to_char(b0))
      i = i + 1
    } else if b0 < 0xE0 && i + 1 < len {
      let b1 = buf[i + 1].to_int() & 0xFF
      let cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 2
    } else if b0 < 0xF0 && i + 2 < len {
      let b1 = buf[i + 1].to_int() & 0xFF
      let b2 = buf[i + 2].to_int() & 0xFF
      let cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 3
    } else if i + 3 < len {
      let b1 = buf[i + 1].to_int() & 0xFF
      let b2 = buf[i + 2].to_int() & 0xFF
      let b3 = buf[i + 3].to_int() & 0xFF
      let cp = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      sb.write_char(Int::unsafe_to_char(cp))
      i = i + 4
    } else {
      i = i + 1
    }
  }
  sb.to_string()
}
