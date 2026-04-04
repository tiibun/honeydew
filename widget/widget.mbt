///|
/// The core trait every widget must implement.
/// `render` writes into `buf` within the given `area`.
pub trait Widget {
  render(Self, @layout.Rect, @buffer.Buffer) -> Unit
}
