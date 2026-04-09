///|
/// Keyring service name used for all honeydew credentials.
let keyring_service : String = "honeydew"

///|
/// Retrieve the stored password for a profile.
/// Returns an empty string if no password is stored or keyring is unavailable.
pub fn keyring_get(profile_name : String) -> String {
  let svc = str_to_bytes(keyring_service)
  let acct = str_to_bytes(profile_name)
  let out : FixedArray[Byte] = FixedArray::make(1024, b'\x00')
  let n = hd_keyring_get(
    svc,
    svc.length(),
    acct,
    acct.length(),
    out,
    out.length(),
  )
  if n <= 0 {
    return ""
  }
  fixed_bytes_to_str(out, n)
}

///|
/// Store (or update) the password for a profile in the OS keyring.
/// Does nothing if the keyring is unavailable (silently ignores errors).
pub fn keyring_set(profile_name : String, password : String) -> Unit {
  if password == "" {
    return
  }
  let svc = str_to_bytes(keyring_service)
  let acct = str_to_bytes(profile_name)
  let pass = str_to_bytes(password)
  hd_keyring_set(svc, svc.length(), acct, acct.length(), pass, pass.length())
  |> ignore
}

///|
/// Delete the stored password for a profile from the OS keyring.
pub fn keyring_delete(profile_name : String) -> Unit {
  let svc = str_to_bytes(keyring_service)
  let acct = str_to_bytes(profile_name)
  hd_keyring_delete(svc, svc.length(), acct, acct.length()) |> ignore
}

///|
/// Returns true if the keyring is supported on this OS.
pub fn keyring_available() -> Bool {
  hd_get_os() != 3 // all implemented OSes return something
}
