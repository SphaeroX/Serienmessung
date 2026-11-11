/// Result of inserting dictated text into a text field.
class DictationEdit {
  const DictationEdit(this.text, this.cursor);

  final String text;
  final int cursor;
}

/// Inserts [dictated] into the multi-line step text [text] at [cursor] as a
/// line of its own (one recording = one step).
///
/// A negative or out-of-range cursor appends at the end. Empty dictation
/// leaves the text unchanged.
DictationEdit insertDictatedLine(String text, int cursor, String dictated) {
  final words = dictated.trim();
  final at = (cursor < 0 || cursor > text.length) ? text.length : cursor;
  if (words.isEmpty) return DictationEdit(text, at);
  final before = text.substring(0, at);
  final after = text.substring(at);
  final lead = before.isEmpty || before.endsWith('\n') ? '' : '\n';
  final trail = after.isEmpty || after.startsWith('\n') ? '' : '\n';
  final inserted = '$lead$words$trail';
  final cursorAfter = before.length + lead.length + words.length;
  return DictationEdit('$before$inserted$after', cursorAfter);
}

/// Appends [dictated] to a single-line field, separated by a space.
DictationEdit appendDictatedWords(String text, String dictated) {
  final words = dictated.trim();
  if (words.isEmpty) return DictationEdit(text, text.length);
  final joined = text.trim().isEmpty ? words : '${text.trimRight()} $words';
  return DictationEdit(joined, joined.length);
}
