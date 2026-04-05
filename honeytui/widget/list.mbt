///|
/// A scrollable list widget with keyboard-navigable selection.
pub struct List {
  items : Array[String]
  /// Index of the currently selected item.
  selected : Int
  /// First visible item index (vertical scroll offset).
  offset : Int
  style : @style.Style
  selected_style : @style.Style
  block : Block?
}

///|
pub fn List::new(items : Array[String]) -> List {
  {
    items,
    selected: 0,
    offset: 0,
    style: @style.Style::default(),
    selected_style: @style.Style::default().fg(@style.Black).bg(@style.Cyan),
    block: None,
  }
}

///|
pub fn List::style(self : List, style : @style.Style) -> List {
  { ..self, style, }
}

///|
pub fn List::selected_style(self : List, style : @style.Style) -> List {
  { ..self, selected_style: style }
}

///|
pub fn List::block(self : List, block : Block) -> List {
  { ..self, block: Some(block) }
}

///|
/// Return the currently selected item, or None if the list is empty.
pub fn List::selected_item(self : List) -> String? {
  if self.items.length() == 0 {
    None
  } else {
    Some(self.items[self.selected])
  }
}

///|
/// Return the selected index.
pub fn List::selected_index(self : List) -> Int {
  self.selected
}

///|
/// Update selection and scroll offset in response to a key event.
pub fn List::handle_key(self : List, key : @terminal.Key) -> List {
  let n = self.items.length()
  if n == 0 {
    return self
  }
  match key {
    Up | Char('k') => {
      let s = if self.selected > 0 { self.selected - 1 } else { 0 }
      let off = if s < self.offset { s } else { self.offset }
      { ..self, selected: s, offset: off }
    }
    Down | Char('j') => {
      let s = if self.selected < n - 1 { self.selected + 1 } else { n - 1 }
      // Scroll down is handled in render (we don't know height here)
      { ..self, selected: s }
    }
    Home => { ..self, selected: 0, offset: 0 }
    End => { ..self, selected: n - 1 }
    _ => self
  }
}

///|
pub impl Widget for List with render(self, area, buf) {
  let inner = match self.block {
    Some(b) => {
      b.render(area, buf)
      b.inner(area)
    }
    None => area
  }
  if inner.width == 0 || inner.height == 0 {
    return
  }
  let height = inner.height
  // Adjust offset so selected is always visible
  let offset = if self.selected >= self.offset + height {
    self.selected - height + 1
  } else {
    self.offset
  }
  let n = self.items.length()
  for i = 0; i < height && offset + i < n; i = i + 1 {
    let idx = offset + i
    let item = self.items[idx]
    let style = if idx == self.selected {
      self.selected_style
    } else {
      self.style
    }
    // Pad / truncate to fill the width
    let text = if item.length() > inner.width {
      item[:inner.width].to_string()
    } else {
      let pad = inner.width - item.length()
      "\{item}\{String::make(pad, ' ')}"
    }
    buf.set_string(inner.x, inner.y + i, text, style)
  }
}
