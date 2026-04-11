///|
pub(all) enum HorizontalAnchor {
  Left
  Center
  Right
}

///|
pub(all) enum VerticalAnchor {
  Top
  Middle
  Bottom
}

///|
pub(all) enum PlacementSize {
  Fixed(Int)
  AtMost(Int)
  Percent(Int)
  Fill
}

///|
pub struct Placement {
  width : PlacementSize
  height : PlacementSize
  h_anchor : HorizontalAnchor
  v_anchor : VerticalAnchor
  margin_x : Int
  margin_y : Int
}

///|
pub fn Placement::new(
  width : PlacementSize,
  height : PlacementSize,
) -> Placement {
  { width, height, h_anchor: Left, v_anchor: Top, margin_x: 0, margin_y: 0 }
}

///|
pub fn Placement::centered(
  width : PlacementSize,
  height : PlacementSize,
) -> Placement {
  Placement::new(width, height).anchor(Center, Middle)
}

///|
pub fn Placement::bottom_right(
  width : PlacementSize,
  height : PlacementSize,
) -> Placement {
  Placement::new(width, height).anchor(Right, Bottom)
}

///|
pub fn Placement::anchor(
  self : Placement,
  h_anchor : HorizontalAnchor,
  v_anchor : VerticalAnchor,
) -> Placement {
  { ..self, h_anchor, v_anchor }
}

///|
pub fn Placement::margin(
  self : Placement,
  margin_x : Int,
  margin_y : Int,
) -> Placement {
  { ..self, margin_x, margin_y }
}

///|
pub fn Placement::resolve(self : Placement, area : Rect) -> Rect {
  let available_w = shrink(area.width, self.margin_x)
  let available_h = shrink(area.height, self.margin_y)
  let width = resolve_size(self.width, available_w)
  let height = resolve_size(self.height, available_h)
  if width == 0 || height == 0 {
    return Rect::new(area.x, area.y, width, height)
  }
  let left = area.x + self.margin_x
  let top = area.y + self.margin_y
  let right = area.right() - self.margin_x - width
  let bottom = area.bottom() - self.margin_y - height
  let x = clamp(
    match self.h_anchor {
      Left => left
      Center => area.x + (area.width - width) / 2
      Right => area.right() - self.margin_x - width
    },
    left,
    right,
  )
  let y = clamp(
    match self.v_anchor {
      Top => top
      Middle => area.y + (area.height - height) / 2
      Bottom => area.bottom() - self.margin_y - height
    },
    top,
    bottom,
  )
  Rect::new(x, y, width, height)
}

///|
fn shrink(axis : Int, margin : Int) -> Int {
  let remaining = axis - margin * 2
  if remaining > 0 {
    remaining
  } else {
    0
  }
}

///|
fn resolve_size(size : PlacementSize, available : Int) -> Int {
  match size {
    Fixed(v) => limit(v, available)
    AtMost(v) => limit(v, available)
    Percent(v) => limit(available * v / 100, available)
    Fill => available
  }
}

///|
fn limit(value : Int, ceiling : Int) -> Int {
  if value <= 0 {
    0
  } else if value < ceiling {
    value
  } else {
    ceiling
  }
}

///|
fn clamp(value : Int, lo : Int, hi : Int) -> Int {
  if hi < lo {
    lo
  } else if value < lo {
    lo
  } else if value > hi {
    hi
  } else {
    value
  }
}
