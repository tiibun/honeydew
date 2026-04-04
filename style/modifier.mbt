///|
/// Text modifiers represented as a bitflag integer.
/// Multiple modifiers can be combined with `Modifier::or`.
pub struct Modifier {
  bits : Int
} derive(Eq, Show)

///|
pub fn Modifier::empty() -> Modifier {
  { bits: 0 }
}

///|
pub let bold : Modifier = { bits: 1 }

///|
pub let dim : Modifier = { bits: 2 }

///|
pub let italic : Modifier = { bits: 4 }

///|
pub let underline : Modifier = { bits: 8 }

///|
pub let blink : Modifier = { bits: 16 }

///|
pub let reverse : Modifier = { bits: 32 }

///|
pub let hidden : Modifier = { bits: 64 }

///|
pub let strikethrough : Modifier = { bits: 128 }

///|
pub fn Modifier::or(self : Modifier, other : Modifier) -> Modifier {
  { bits: self.bits | other.bits }
}

///|
pub fn Modifier::contains(self : Modifier, other : Modifier) -> Bool {
  (self.bits & other.bits) != 0
}

///|
/// Return all active SGR codes for this modifier set.
pub fn Modifier::sgr_codes(self : Modifier) -> Array[String] {
  let codes = []
  if self.contains(bold) {
    codes.push("1")
  }
  if self.contains(dim) {
    codes.push("2")
  }
  if self.contains(italic) {
    codes.push("3")
  }
  if self.contains(underline) {
    codes.push("4")
  }
  if self.contains(blink) {
    codes.push("5")
  }
  if self.contains(reverse) {
    codes.push("7")
  }
  if self.contains(hidden) {
    codes.push("8")
  }
  if self.contains(strikethrough) {
    codes.push("9")
  }
  codes
}
