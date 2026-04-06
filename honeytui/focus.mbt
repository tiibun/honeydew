///|
/// A circular ring of focusable items.
/// `next()` and `prev()` advance/retreat through the ring, wrapping around.
/// Immutable: each operation returns a new `FocusRing`.
pub struct FocusRing[T] {
  items : Array[T]
  current_idx : Int
}

///|
pub fn[T] FocusRing::new(items : Array[T]) -> FocusRing[T] {
  { items, current_idx: 0 }
}

///|
/// Return the currently focused item.
pub fn[T] FocusRing::current(self : FocusRing[T]) -> T {
  self.items[self.current_idx]
}

///|
/// Advance focus to the next item (wraps around).
pub fn[T] FocusRing::next(self : FocusRing[T]) -> FocusRing[T] {
  let n = self.items.length()
  if n == 0 {
    return self
  }
  { ..self, current_idx: (self.current_idx + 1) % n }
}

///|
/// Retreat focus to the previous item (wraps around).
pub fn[T] FocusRing::prev(self : FocusRing[T]) -> FocusRing[T] {
  let n = self.items.length()
  if n == 0 {
    return self
  }
  { ..self, current_idx: (self.current_idx + n - 1) % n }
}

///|
/// Return a new ring with the current index pointing at `item`.
/// If `item` is not in the ring, the index is unchanged.
pub fn[T : Eq] FocusRing::set(self : FocusRing[T], item : T) -> FocusRing[T] {
  let mut idx = self.current_idx
  for i = 0; i < self.items.length(); i = i + 1 {
    if self.items[i] == item {
      idx = i
      break
    }
  }
  { ..self, current_idx: idx }
}
