///|
/// Split direction for a layout.
pub(all) enum Direction {
  Horizontal
  Vertical
}

///|
/// A size constraint for a layout segment.
pub(all) enum Constraint {
  /// Fixed number of columns/rows.
  Length(Int)
  /// Percentage of the available space (0–100).
  Percentage(Int)
  /// At least this many columns/rows.
  Min(Int)
  /// At most this many columns/rows.
  Max(Int)
}

///|
/// Layout builder for splitting a `Rect` into sub-rects.
pub struct Layout {
  direction : Direction
  constraints : Array[Constraint]
  margin : Int
}

///|
pub fn Layout::new(
  direction : Direction,
  constraints : Array[Constraint],
) -> Layout {
  { direction, constraints, margin: 0 }
}

///|
pub fn Layout::margin(self : Layout, margin : Int) -> Layout {
  { ..self, margin, }
}

///|
/// Split `area` according to the constraints and return the sub-rects.
pub fn Layout::split(self : Layout, area : Rect) -> Array[Rect] {
  let m = self.margin
  let inner = {
    x: area.x + m,
    y: area.y + m,
    width: area.width - m * 2,
    height: area.height - m * 2,
  }
  let total = match self.direction {
    Horizontal => inner.width
    Vertical => inner.height
  }
  let n = self.constraints.length()
  if n == 0 {
    return []
  }
  // First pass: resolve fixed and percentage constraints
  let sizes : Array[Int] = Array::make(n, 0)
  let mut remaining = total
  for i = 0; i < n; i = i + 1 {
    let size = match self.constraints[i] {
      Length(v) => v
      Percentage(p) => total * p / 100
      Min(v) => v
      Max(v) => v
    }
    sizes[i] = size
    remaining = remaining - size
  }
  // Distribute any leftover to the last segment
  if remaining > 0 {
    sizes[n - 1] = sizes[n - 1] + remaining
  }
  // Build rects
  let rects = []
  let mut offset = 0
  for i = 0; i < n; i = i + 1 {
    let size = sizes[i]
    let rect = match self.direction {
      Horizontal => Rect::new(inner.x + offset, inner.y, size, inner.height)
      Vertical => Rect::new(inner.x, inner.y + offset, inner.width, size)
    }
    rects.push(rect)
    offset = offset + size
  }
  rects
}
