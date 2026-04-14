///|
/// A saved connection profile (no password – stored in OS keyring).
pub(all) struct ConnProfile {
  name : String
  kind_idx : Int
  host : String
  port : Int
  database : String
  username : String
  tls_enabled : Bool
  ca_cert_path : String
  client_cert_path : String
  client_key_path : String
  connect_timeout_secs : Int
}

///|
/// Return the honeydew config directory: $HOME/.config/honeydew
pub fn config_dir() -> String {
  let buf : FixedArray[Byte] = FixedArray::make(4096, b'\x00')
  let n = hd_home_dir(buf, buf.length())
  let home = if n > 0 { fixed_bytes_to_str(buf, n) } else { "." }
  "\{home}/.config/honeydew"
}

///|
/// Load saved profiles from $HOME/.config/honeydew/connections.json.
/// Returns an empty array if the file does not exist or cannot be parsed.
pub fn load_profiles() -> Array[ConnProfile] {
  let dir = config_dir()
  let path = "\{dir}/connections.json"
  let path_b = str_to_bytes(path)
  let buf : FixedArray[Byte] = FixedArray::make(65536, b'\x00')
  let n = hd_file_read(path_b, path_b.length(), buf, buf.length())
  if n <= 0 {
    return []
  }
  let content = fixed_bytes_to_str(buf, n)
  parse_profiles(content)
}

///|
/// Persist profiles to $HOME/.config/honeydew/connections.json.
pub fn save_profiles(profiles : Array[ConnProfile]) -> Unit {
  let dir = config_dir()
  let dir_b = str_to_bytes(dir)
  hd_mkdir_p(dir_b, dir_b.length()) |> ignore
  let path = "\{dir}/connections.json"
  let json = profiles_to_json(profiles)
  let path_b = str_to_bytes(path)
  let json_b = str_to_bytes(json)
  hd_file_write(path_b, path_b.length(), json_b, json_b.length()) |> ignore
}

///|
fn parse_profiles(content : String) -> Array[ConnProfile] {
  try {
    let json = @json.parse(content)
    match json {
      Array(items) => {
        let result : Array[ConnProfile] = []
        for item in items {
          match parse_profile_json(item) {
            Some(p) => result.push(p)
            None => ()
          }
        }
        result
      }
      _ => []
    }
  } catch {
    _ => []
  }
}

///|
fn parse_profile_json(json : Json) -> ConnProfile? {
  match json {
    Object(obj) => {
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ => return None
      }
      let kind_idx = match obj.get("kind") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
      let host = match obj.get("host") {
        Some(String(s)) => s
        _ => ""
      }
      let port = match obj.get("port") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
      let database = match obj.get("database") {
        Some(String(s)) => s
        _ => ""
      }
      let username = match obj.get("username") {
        Some(String(s)) => s
        _ => ""
      }
      let tls_enabled = match obj.get("tls_enabled") {
        Some(True) => true
        Some(False) => false
        _ => false
      }
      let ca_cert_path = match obj.get("ca_cert_path") {
        Some(String(s)) => s
        _ => ""
      }
      let client_cert_path = match obj.get("client_cert_path") {
        Some(String(s)) => s
        _ => ""
      }
      let client_key_path = match obj.get("client_key_path") {
        Some(String(s)) => s
        _ => ""
      }
      let connect_timeout_secs = match obj.get("connect_timeout_secs") {
        Some(Number(n, ..)) => n.to_int()
        _ => 10
      }
      Some({
        name,
        kind_idx,
        host,
        port,
        database,
        username,
        tls_enabled,
        ca_cert_path,
        client_cert_path,
        client_key_path,
        connect_timeout_secs,
      })
    }
    _ => None
  }
}

///|
fn profiles_to_json(profiles : Array[ConnProfile]) -> String {
  let sb = StringBuilder::new()
  sb.write_char('[')
  for i = 0; i < profiles.length(); i = i + 1 {
    if i > 0 {
      sb.write_char(',')
    }
    profile_to_json(profiles[i], sb)
  }
  sb.write_char(']')
  sb.to_string()
}

///|
fn profile_to_json(p : ConnProfile, sb : StringBuilder) -> Unit {
  sb.write_string("{\"name\":")
  json_write_str(p.name, sb)
  sb.write_string(",\"kind\":")
  sb.write_string(p.kind_idx.to_string())
  sb.write_string(",\"host\":")
  json_write_str(p.host, sb)
  sb.write_string(",\"port\":")
  sb.write_string(p.port.to_string())
  sb.write_string(",\"database\":")
  json_write_str(p.database, sb)
  sb.write_string(",\"username\":")
  json_write_str(p.username, sb)
  sb.write_string(",\"tls_enabled\":")
  sb.write_string(if p.tls_enabled { "true" } else { "false" })
  sb.write_string(",\"ca_cert_path\":")
  json_write_str(p.ca_cert_path, sb)
  sb.write_string(",\"client_cert_path\":")
  json_write_str(p.client_cert_path, sb)
  sb.write_string(",\"client_key_path\":")
  json_write_str(p.client_key_path, sb)
  sb.write_string(",\"connect_timeout_secs\":")
  sb.write_string(p.connect_timeout_secs.to_string())
  sb.write_char('}')
}

///|
fn json_write_str(s : String, sb : StringBuilder) -> Unit {
  sb.write_char('"')
  for c in s.iter() {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.write_char('"')
}

///|
/// Encode a MoonBit String to UTF-8 Bytes.
fn str_to_bytes(s : String) -> Bytes {
  let res : Array[Byte] = []
  let len = s.length()
  let mut i = 0
  while i < len {
    let mut c = s.code_unit_at(i).to_int()
    if 0xD800 <= c && c <= 0xDBFF {
      c -= 0xD800
      i = i + 1
      let l = s.code_unit_at(i).to_int() - 0xDC00
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
fn fixed_bytes_to_str(buf : FixedArray[Byte], len : Int) -> String {
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
