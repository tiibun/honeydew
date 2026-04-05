///|
/// Information about a single column returned by schema introspection.
pub(all) struct ColumnInfo {
  name : String
  col_type : String
}

///|
/// The result of a SELECT query: column names and rows of string values.
/// All cell values are represented as strings (NULL becomes "NULL").
pub(all) struct QueryResult {
  columns : Array[String]
  rows : Array[Array[String]]
}

///|
pub fn QueryResult::empty() -> QueryResult {
  { columns: [], rows: [] }
}
