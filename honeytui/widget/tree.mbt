///|
/// A single node in the tree widget.
/// Use `TreeItem::leaf` for leaf nodes and `TreeItem::node` for expandable nodes.
pub(all) struct TreeItem {
  label : String
  /// Nesting level: 0 = root, 1 = first-level child, etc.
  depth : Int
  /// True if this node can be expanded to show children.
  expandable : Bool
  /// True if children are currently visible.
  expanded : Bool
  /// Opaque data payload (e.g. table name). Empty string means no payload.
  data : String
}

///|
/// Create a leaf node (no children).
pub fn TreeItem::leaf(label : String, depth : Int, data : String) -> TreeItem {
  { label, depth, expandable: false, expanded: false, data }
}

///|
/// Create an expandable (parent) node, initially expanded.
pub fn TreeItem::node(label : String, depth : Int) -> TreeItem {
  { label, depth, expandable: true, expanded: true, data: "" }
}

///|
/// Create an expandable (parent) node, initially collapsed.
pub fn TreeItem::collapsed_node(label : String, depth : Int) -> TreeItem {
  { label, depth, expandable: true, expanded: false, data: "" }
}

///|
/// A collapsible tree widget.
/// All items (visible and hidden) are stored in `items`; visibility is
/// computed dynamically from the `expanded` flags using a single-pass algorithm.
pub struct Tree {
  items : Array[TreeItem]
  /// Index into the *visible* item list.
  selected : Int
  /// Vertical scroll offset (in visible items).
  offset : Int
  style : @style.Style
  selected_style : @style.Style
  block : Block?
}

///|
pub fn Tree::new(items : Array[TreeItem]) -> Tree {
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
pub fn Tree::block(self : Tree, block : Block) -> Tree {
  { ..self, block: Some(block) }
}

///|
pub fn Tree::selected_style(self : Tree, style : @style.Style) -> Tree {
  { ..self, selected_style: style }
}

///|
/// Return the number of currently visible items.
pub fn Tree::visible_count(self : Tree) -> Int {
  compute_visible(self.items).length()
}

///|
/// Return the data payload of the currently selected item,
/// or None if it is empty (e.g. a group header or root).
pub fn Tree::selected_data(self : Tree) -> String? {
  let vis = compute_visible(self.items)
  if self.selected >= vis.length() {
    return None
  }
  let item = self.items[vis[self.selected]]
  if item.data == "" {
    None
  } else {
    Some(item.data)
  }
}

///|
/// Return the currently selected TreeItem, or None.
pub fn Tree::selected_item(self : Tree) -> TreeItem? {
  let vis = compute_visible(self.items)
  if self.selected >= vis.length() {
    return None
  }
  Some(self.items[vis[self.selected]])
}

///|
/// Handle key events:
///   Up / k         — move selection up
///   Down / j       — move selection down
///   Right          — expand selected node
///   Left           — collapse expanded node, or move to its parent
///   Enter / Space  — toggle expand/collapse
///   Home / End     — jump to first/last visible item
pub fn Tree::handle_key(self : Tree, key : @terminal.Key) -> Tree {
  self.handle_key_inner(key)
}

///|
/// Handle a mouse click at terminal coordinates `(mx, my)`.
/// `area` is the outer rect of the tree widget (including all-borders block).
/// Clicking an expandable node toggles it; clicking a leaf selects it.
pub fn Tree::handle_click(
  self : Tree,
  mx : Int,
  my : Int,
  area : @layout.Rect,
) -> Tree {
  // Inner area: block has 1-cell borders on all sides.
  let inner_x = area.x + 1
  let inner_y = area.y + 1
  let inner_h = if area.height > 2 { area.height - 2 } else { 0 }
  let _ = mx
  let _ = inner_x
  if inner_h == 0 || my < inner_y || my >= inner_y + inner_h {
    return self
  }
  let vis = compute_visible(self.items)
  let n = vis.length()
  // Same offset formula as in render so the clicked row maps correctly.
  let offset = if self.selected >= self.offset + inner_h {
    self.selected - inner_h + 1
  } else {
    self.offset
  }
  let vis_idx = my - inner_y + offset
  if vis_idx < 0 || vis_idx >= n {
    return self
  }
  let item_idx = vis[vis_idx]
  let item = self.items[item_idx]
  if item.expandable {
    // Toggle expand/collapse.
    let new_items = self.items.copy()
    new_items[item_idx] = { ..item, expanded: !item.expanded }
    let new_vis = compute_visible(new_items)
    let new_sel = find_visible_index(new_vis, item_idx)
    { ..self, items: new_items, selected: new_sel }
  } else {
    // Select the leaf.
    { ..self, selected: vis_idx }
  }
}

///|
fn Tree::handle_key_inner(self : Tree, key : @terminal.Key) -> Tree {
  let vis = compute_visible(self.items)
  let n = vis.length()
  match key {
    Up | Char('k') => {
      let s = if self.selected > 0 { self.selected - 1 } else { 0 }
      let off = if s < self.offset { s } else { self.offset }
      { ..self, selected: s, offset: off }
    }
    Down | Char('j') => {
      let s = if self.selected < n - 1 {
        self.selected + 1
      } else {
        self.selected
      }
      { ..self, selected: s }
    }
    Right => {
      if self.selected >= n {
        return self
      }
      let item_idx = vis[self.selected]
      let item = self.items[item_idx]
      if !item.expandable || item.expanded {
        return self
      }
      let new_items = self.items.copy()
      new_items[item_idx] = { ..item, expanded: true }
      { ..self, items: new_items }
    }
    Left => {
      if self.selected >= n {
        return self
      }
      let item_idx = vis[self.selected]
      let item = self.items[item_idx]
      if item.expandable && item.expanded {
        // Collapse: selection stays on this node.
        let new_items = self.items.copy()
        new_items[item_idx] = { ..item, expanded: false }
        let new_vis = compute_visible(new_items)
        let new_sel = find_visible_index(new_vis, item_idx)
        let off = if new_sel < self.offset { new_sel } else { self.offset }
        { ..self, items: new_items, selected: new_sel, offset: off }
      } else if item.depth > 0 {
        // Move selection to the parent node.
        match find_parent(self.items, item_idx, item.depth) {
          None => self
          Some(pidx) => {
            let new_sel = find_visible_index(vis, pidx)
            let off = if new_sel < self.offset { new_sel } else { self.offset }
            { ..self, selected: new_sel, offset: off }
          }
        }
      } else {
        self
      }
    }
    Enter | Char(' ') => {
      if self.selected >= n {
        return self
      }
      let item_idx = vis[self.selected]
      let item = self.items[item_idx]
      if !item.expandable {
        return self
      }
      let new_items = self.items.copy()
      new_items[item_idx] = { ..item, expanded: !item.expanded }
      let new_vis = compute_visible(new_items)
      let new_sel = find_visible_index(new_vis, item_idx)
      let off = if new_sel < self.offset { new_sel } else { self.offset }
      { ..self, items: new_items, selected: new_sel, offset: off }
    }
    Home => { ..self, selected: 0, offset: 0 }
    End => { ..self, selected: if n > 0 { n - 1 } else { 0 } }
    _ => self
  }
}

///|
pub impl Widget for Tree with render(self, area, buf) {
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
  let vis = compute_visible(self.items)
  let n = vis.length()
  // Adjust offset so selected is always in view.
  let offset = if self.selected >= self.offset + height {
    self.selected - height + 1
  } else {
    self.offset
  }
  for i = 0; i < height && offset + i < n; i = i + 1 {
    let vis_idx = offset + i
    let item = self.items[vis[vis_idx]]
    let is_selected = vis_idx == self.selected
    let indent = String::make(item.depth * 2, ' ')
    let icon = if item.expandable {
      if item.expanded {
        "▼ "
      } else {
        "▶ "
      }
    } else {
      "  "
    }
    let raw = "\{indent}\{icon}\{item.label}"
    let style = if is_selected { self.selected_style } else { self.style }
    let display = if raw.length() > inner.width {
      raw[:inner.width].to_string()
    } else {
      let pad = inner.width - raw.length()
      "\{raw}\{String::make(pad, ' ')}"
    }
    buf.set_string(inner.x, inner.y + i, display, style)
  }
}

///|
/// Compute which indices into `items` are currently visible.
/// An item is visible unless one of its ancestors is collapsed.
///
/// Algorithm: single pass. `hide_below` tracks the depth at which a
/// collapsed node was seen. Items deeper than that depth are skipped.
/// When we see an item at depth ≤ hide_below we exit the hidden region.
fn compute_visible(items : Array[TreeItem]) -> Array[Int] {
  let visible : Array[Int] = []
  let mut hide_below = -1
  for i = 0; i < items.length(); i = i + 1 {
    let item = items[i]
    let d = item.depth
    if hide_below >= 0 && d <= hide_below {
      hide_below = -1
    }
    if hide_below < 0 {
      visible.push(i)
      if item.expandable && !item.expanded {
        hide_below = d
      }
    }
  }
  visible
}

///|
/// Return the position of `item_idx` in `vis`, or 0 if not found.
fn find_visible_index(vis : Array[Int], item_idx : Int) -> Int {
  for i = 0; i < vis.length(); i = i + 1 {
    if vis[i] == item_idx {
      return i
    }
  }
  0
}

///|
/// Return the index in `items` of the parent of `items[idx]`.
/// The parent is the nearest preceding item with depth = items[idx].depth - 1.
fn find_parent(items : Array[TreeItem], idx : Int, depth : Int) -> Int? {
  if depth == 0 {
    return None
  }
  let parent_depth = depth - 1
  let mut j = idx - 1
  while j >= 0 {
    if items[j].depth == parent_depth {
      return Some(j)
    }
    j = j - 1
  }
  None
}
