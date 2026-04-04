///|
/// A rectangular area in the terminal, using 1-based column/row coordinates.
pub struct Rect {
  /// Left edge (1-based column).
  x : Int
  /// Top edge (1-based row).
  y : Int
  width : Int
  height : Int
} derive(Eq)

///|
pub fn Rect::new(x : Int, y : Int, width : Int, height : Int) -> Rect {
  { x, y, width, height }
}

///|
/// A zero-size rect at the origin.
pub fn Rect::zero() -> Rect {
  { x: 1, y: 1, width: 0, height: 0 }
}

///|
/// Right edge (exclusive), i.e. x + width.
pub fn Rect::right(self : Rect) -> Int {
  self.x + self.width
}

///|
/// Bottom edge (exclusive), i.e. y + height.
pub fn Rect::bottom(self : Rect) -> Int {
  self.y + self.height
}

///|
/// Return the inner rect after removing a border of `size` on each side.
pub fn Rect::inner(self : Rect, size : Int) -> Rect {
  let d = size * 2
  if self.width <= d || self.height <= d {
    return Rect::zero()
  }
  {
    x: self.x + size,
    y: self.y + size,
    width: self.width - d,
    height: self.height - d,
  }
}
