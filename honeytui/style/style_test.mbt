///|
test "Color fg_code - named colors" {
  assert_eq(@style.Default.fg_code(), "39")
  assert_eq(@style.Black.fg_code(), "30")
  assert_eq(@style.Red.fg_code(), "31")
  assert_eq(@style.Green.fg_code(), "32")
  assert_eq(@style.Yellow.fg_code(), "33")
  assert_eq(@style.Blue.fg_code(), "34")
  assert_eq(@style.White.fg_code(), "37")
  assert_eq(@style.BrightRed.fg_code(), "91")
  assert_eq(@style.BrightWhite.fg_code(), "97")
}

///|
test "Color bg_code - named colors" {
  assert_eq(@style.Default.bg_code(), "49")
  assert_eq(@style.Black.bg_code(), "40")
  assert_eq(@style.Red.bg_code(), "41")
  assert_eq(@style.White.bg_code(), "47")
  assert_eq(@style.BrightBlack.bg_code(), "100")
}

///|
test "Color fg_code - Ansi256" {
  assert_eq(@style.Ansi256(0).fg_code(), "38;5;0")
  assert_eq(@style.Ansi256(255).fg_code(), "38;5;255")
}

///|
test "Color bg_code - Ansi256" {
  assert_eq(@style.Ansi256(128).bg_code(), "48;5;128")
}

///|
test "Color fg_code - Rgb" {
  assert_eq(@style.Rgb(255, 128, 0).fg_code(), "38;2;255;128;0")
}

///|
test "Color bg_code - Rgb" {
  assert_eq(@style.Rgb(0, 0, 0).bg_code(), "48;2;0;0;0")
}

///|
test "Modifier empty has no codes" {
  assert_eq(@style.Modifier::empty().sgr_codes(), [])
}

///|
test "Modifier single flags" {
  assert_eq(@style.bold.sgr_codes(), ["1"])
  assert_eq(@style.dim.sgr_codes(), ["2"])
  assert_eq(@style.italic.sgr_codes(), ["3"])
  assert_eq(@style.underline.sgr_codes(), ["4"])
  assert_eq(@style.blink.sgr_codes(), ["5"])
  assert_eq(@style.reverse.sgr_codes(), ["7"])
  assert_eq(@style.hidden.sgr_codes(), ["8"])
  assert_eq(@style.strikethrough.sgr_codes(), ["9"])
}

///|
test "Modifier::or combines flags" {
  let m = @style.bold.or(@style.italic)
  assert_eq(m.sgr_codes(), ["1", "3"])
}

///|
test "Modifier::contains" {
  let m = @style.bold.or(@style.underline)
  assert_true(m.contains(@style.bold))
  assert_true(m.contains(@style.underline))
  assert_false(m.contains(@style.italic))
}

///|
test "Style::default produces reset sequence" {
  let s = @style.Style::default()
  assert_eq(s.to_ansi(), "\u001b[0;39;49m")
}

///|
test "Style::fg changes foreground" {
  let s = @style.Style::default().fg(@style.Red)
  assert_eq(s.to_ansi(), "\u001b[0;31;49m")
}

///|
test "Style::bg changes background" {
  let s = @style.Style::default().bg(@style.Blue)
  assert_eq(s.to_ansi(), "\u001b[0;39;44m")
}

///|
test "Style with modifier" {
  let s = @style.Style::default()
    .fg(@style.Green)
    .add_modifier(@style.bold)
  assert_eq(s.to_ansi(), "\u001b[0;1;32;49m")
}

///|
test "Style with multiple modifiers" {
  let s = @style.Style::default()
    .add_modifier(@style.bold.or(@style.italic))
  assert_eq(s.to_ansi(), "\u001b[0;1;3;39;49m")
}
