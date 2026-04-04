///|
/// Terminal color.
pub(all) enum Color {
  /// Use the terminal's default color.
  Default
  Black
  Red
  Green
  Yellow
  Blue
  Magenta
  Cyan
  White
  /// Bright variants
  BrightBlack
  BrightRed
  BrightGreen
  BrightYellow
  BrightBlue
  BrightMagenta
  BrightCyan
  BrightWhite
  /// 256-color palette (0–255).
  Ansi256(Int)
  /// 24-bit RGB color.
  Rgb(Int, Int, Int)
} derive(Eq, Show)

///|
/// Return the ANSI SGR code for this color as a foreground.
pub fn Color::fg_code(self : Color) -> String {
  match self {
    Default => "39"
    Black => "30"
    Red => "31"
    Green => "32"
    Yellow => "33"
    Blue => "34"
    Magenta => "35"
    Cyan => "36"
    White => "37"
    BrightBlack => "90"
    BrightRed => "91"
    BrightGreen => "92"
    BrightYellow => "93"
    BrightBlue => "94"
    BrightMagenta => "95"
    BrightCyan => "96"
    BrightWhite => "97"
    Ansi256(n) => "38;5;\{n}"
    Rgb(r, g, b) => "38;2;\{r};\{g};\{b}"
  }
}

///|
/// Return the ANSI SGR code for this color as a background.
pub fn Color::bg_code(self : Color) -> String {
  match self {
    Default => "49"
    Black => "40"
    Red => "41"
    Green => "42"
    Yellow => "43"
    Blue => "44"
    Magenta => "45"
    Cyan => "46"
    White => "47"
    BrightBlack => "100"
    BrightRed => "101"
    BrightGreen => "102"
    BrightYellow => "103"
    BrightBlue => "104"
    BrightMagenta => "105"
    BrightCyan => "106"
    BrightWhite => "107"
    Ansi256(n) => "48;5;\{n}"
    Rgb(r, g, b) => "48;2;\{r};\{g};\{b}"
  }
}
