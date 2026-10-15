/// What a key is, for styling (theme colours and label weight) and sounds.
///
/// Lives in the theme layer so themes never depend on the calculator
/// feature; `calc_keys.dart` re-exports it.
enum KeyRole {
  digit,
  decimal,
  operator,
  equals,
  function,
  constant,
  paren,
  clear,
  backspace,
  sign,
  percent,
  memory,
  mode,
}
