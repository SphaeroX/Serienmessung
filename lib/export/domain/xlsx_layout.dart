import 'package:excel/excel.dart';

// Colours of the workbooks: the brand colour of the app and quiet greys.
final _brand = ExcelColor.fromHexString('FF0B6B8A');
final _brandTint = ExcelColor.fromHexString('FFDCEBF0');
final _band = ExcelColor.fromHexString('FFF3F7F9');
final _line = ExcelColor.fromHexString('FFCFD8DC');
final _label = ExcelColor.fromHexString('FF37474F');
final _link = ExcelColor.fromHexString('FF0563C1');

const _fontFamily = 'Calibri';
const _fontSize = 11;

const _minWidth = 9.0;
const _maxWidth = 50.0;

/// Widest second column of a sheet without tables (a contents sheet), so
/// that a description fits next to its label.
const _wideWidth = 60.0;

/// Room around the text of a cell, in characters.
const _padding = 2.5;

/// Width of an average text character relative to the "0" that Excel
/// measures column widths in (Calibri). Used to decide whether a text needs
/// more than one line.
const _textFactor = 0.9;

/// Texts longer than this may wrap inside a table instead of widening it.
const _wrapChars = 46;

/// Longest text of a key figure that still widens its column; longer texts
/// (descriptions, notes) run over the empty cells to their right, or widen
/// the second column of a sheet without tables.
const _valueChars = 24;

const _rowHeight = 18.0;
const _headerHeight = 24.0;
const _sectionHeight = 24.0;
const _titleHeight = 32.0;

final _decimalsOf = Expando<int>('decimals');
final _linkTextOf = Expando<String>('link text');

/// Marks a number or a formula to be shown with [decimals] decimals.
T fixed<T extends CellValue>(T value, int decimals) {
  _decimalsOf[value] = decimals;
  return value;
}

/// Quotes a sheet name for formulas (`'name'`).
String sheetRef(String sheet) => "'${sheet.replaceAll("'", "''")}'";

/// Link to cell A1 of [sheet], shown as [text].
FormulaCellValue sheetLink(String sheet, String text) {
  final link = FormulaCellValue(
    'HYPERLINK("#${sheetRef(sheet).replaceAll('"', '""')}!A1",'
    '"${text.replaceAll('"', '""')}")',
  );
  _linkTextOf[link] = text;
  return link;
}

/// Writes one worksheet from top to bottom and gives it a consistent look:
/// title, labelled key figures, tables with a coloured header, banded rows
/// and fine borders, fixed decimals, empty rows between blocks and column
/// widths that follow the content. Call [finish] after the last row.
///
/// Empty rows are real gaps (the excel package ignores `appendRow([])`), so
/// row numbers for formulas come from [nextRow] and the return values.
class SheetLayout {
  SheetLayout(this.sheet);

  final Sheet sheet;
  int _row = 0;

  /// Widest content per column, in characters.
  final _chars = <int, double>{};

  /// Highest column index that holds a value.
  int _lastColumn = 0;

  /// Long texts that wrap when their column turns out too narrow; decided
  /// in [finish], once the column widths are known.
  final _wrapping = <_LongText>[];

  /// Long key values: they widen the second column of a sheet without
  /// tables and run over the empty cells to their right otherwise.
  final _longValues = <_LongText>[];

  // The table that is being written.
  int? _headerRow;
  List<String> _titles = const [];
  int _dataRows = 0;
  final _numbers = <int>{};
  final _texts = <int>{};

  /// 1-based number of the row that is written next.
  int get nextRow => _row + 1;

  /// Large heading of the sheet.
  void title(String text) => _heading(text, 16, _titleHeight);

  /// Heading of a block inside the sheet.
  void section(String text) => _heading(text, 12, _sectionHeight);

  /// Free text over the full width; it never widens a column.
  void note(String text) {
    _endTable();
    _put(0, TextCellValue(text), _style());
    _next(_rowHeight);
  }

  /// One empty row.
  void gap() {
    _endTable();
    _row++;
  }

  /// A labelled value in the first two columns; returns its row number.
  /// Numbers stand at the left edge like texts, close to their label.
  int keyValue(String key, CellValue? value) {
    _endTable();
    _put(0, TextCellValue(key), _style(bold: true, color: _label));
    _measure(0, key.length, bold: true);
    if (value != null) {
      CellStyle style(bool wrap) =>
          _style(value: value, numbersLeft: true, wrap: wrap);
      _put(1, value, style(false));
      final chars = _charsOf(value);
      if (value is! TextCellValue || chars <= _valueChars) {
        _measure(1, chars);
      } else {
        _longValues.add(_LongText(_row, 1, chars, style));
      }
    }
    return _next(_rowHeight);
  }

  /// Unstyled cells such as a list of links; returns the row number.
  int cells(List<CellValue?> values) {
    _endTable();
    for (var c = 0; c < values.length; c++) {
      final v = values[c];
      if (v == null) continue;
      _put(c, v, _style(value: v));
      _measure(c, _charsOf(v));
    }
    return _next(_rowHeight);
  }

  /// Header of a table; the rows follow with [row].
  void header(List<String> titles) {
    _endTable();
    _headerRow = _row;
    _titles = titles;
    for (var c = 0; c < titles.length; c++) {
      _put(c, TextCellValue(titles[c]), _headerStyle(HorizontalAlign.Left));
      _measure(c, titles[c].length, bold: true);
    }
    _next(_headerHeight);
  }

  /// One row of the table; [total] marks a summary row. Returns the row
  /// number.
  int row(List<CellValue?> values, {bool total = false}) {
    final banded = !total && _dataRows.isOdd;
    final count = values.length > _titles.length
        ? values.length
        : _titles.length;
    for (var c = 0; c < count; c++) {
      final v = c < values.length ? values[c] : null;
      final chars = v == null ? 0 : _charsOf(v);
      final long = v is TextCellValue && chars > _wrapChars;
      CellStyle style(bool wrap) => _style(
        value: v,
        bold: total,
        fill: total ? _brandTint : (banded ? _band : ExcelColor.none),
        wrap: wrap,
        border: _line,
        topBorder: total ? _brand : _line,
      );
      _put(c, v, style(false));
      if (v == null) continue;
      if (long) _wrapping.add(_LongText(_row, c, chars, style));
      if (!total) (_isNumber(v) ? _numbers : _texts).add(c);
      _measure(c, long ? _wrapChars : chars, bold: total);
    }
    _dataRows++;
    return _next(_rowHeight);
  }

  /// Sets the column widths and wraps the texts that do not fit their
  /// column; call once after the last row.
  void finish() {
    _endTable();
    // Without tables the second column takes the long key values.
    final wide = _lastColumn <= 1;
    if (wide) {
      for (final v in _longValues) {
        _measure(v.column, v.chars);
        _wrapping.add(v);
      }
    }
    final widths = <int, double>{};
    _chars.forEach((column, chars) {
      final max = wide && column == 1 ? _wideWidth : _maxWidth;
      final width = (chars + _padding).clamp(_minWidth, max);
      widths[column] = (width * 10).ceil() / 10;
      sheet.setColumnWidth(column, widths[column]!);
    });
    final heights = <int, double>{};
    for (final t in _wrapping) {
      final room = (widths[t.column] ?? _minWidth) - _padding;
      final lines = (t.chars * _textFactor / room).ceil();
      if (lines < 2) continue;
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: t.column, rowIndex: t.row),
          )
          .cellStyle = t.style(
        true,
      );
      final height = lines * 15.0 + 3;
      if (height > (heights[t.row] ?? 0)) heights[t.row] = height;
    }
    heights.forEach(sheet.setRowHeight);
  }

  void _heading(String text, int size, double height) {
    _endTable();
    _put(0, TextCellValue(text), _style(bold: true, size: size, color: _brand));
    _next(height);
  }

  /// Closes the open table: headers of number columns are aligned to the
  /// right, like their numbers. A column without values counts as numbers
  /// when its title ends with a unit (`[s]`); total rows are not counted.
  void _endTable() {
    final header = _headerRow;
    if (header != null) {
      for (var c = 0; c < _titles.length; c++) {
        final numbers = _numbers.contains(c) || _titles[c].endsWith(']');
        if (!numbers || _texts.contains(c)) continue;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: header))
            .cellStyle = _headerStyle(
          HorizontalAlign.Right,
        );
      }
    }
    _headerRow = null;
    _titles = const [];
    _dataRows = 0;
    _numbers.clear();
    _texts.clear();
  }

  CellStyle _headerStyle(HorizontalAlign align) => _style(
    bold: true,
    color: ExcelColor.white,
    fill: _brand,
    align: align,
    border: _brand,
  );

  void _put(int column, CellValue? value, CellStyle style) {
    if (value != null && column > _lastColumn) _lastColumn = column;
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: _row),
      value,
      cellStyle: style,
    );
  }

  /// Finishes the current row with [height]; returns its row number.
  int _next(double height) {
    sheet.setRowHeight(_row, height);
    return ++_row;
  }

  void _measure(int column, int chars, {bool bold = false}) {
    final width = chars * (bold ? 1.1 : 1.0);
    if (width > (_chars[column] ?? 0)) _chars[column] = width;
  }
}

/// A long text in [row] and [column]; [style] gives its look, wrapped or not.
class _LongText {
  _LongText(this.row, this.column, this.chars, this.style);

  final int row;
  final int column;
  final int chars;
  final CellStyle Function(bool wrap) style;
}

/// Style of a cell in the workbook font; [value] decides the number format
/// and whether the cell looks like a link.
CellStyle _style({
  CellValue? value,
  bool bold = false,
  int size = _fontSize,
  ExcelColor? color,
  ExcelColor fill = ExcelColor.none,
  HorizontalAlign align = HorizontalAlign.Left,
  bool wrap = false,
  bool numbersLeft = false,
  ExcelColor? border,
  ExcelColor? topBorder,
}) {
  final link = _isLink(value);
  Border? edge(ExcelColor? color) => color == null
      ? null
      : Border(borderStyle: BorderStyle.Thin, borderColorHex: color);
  final style = CellStyle(
    fontFamily: _fontFamily,
    fontSize: size,
    bold: bold,
    fontColorHex: color ?? (link ? _link : ExcelColor.black),
    backgroundColorHex: fill,
    horizontalAlign: align,
    verticalAlign: VerticalAlign.Center,
    textWrapping: wrap ? TextWrapping.WrapText : null,
    leftBorder: edge(border),
    rightBorder: edge(border),
    topBorder: edge(topBorder ?? border),
    bottomBorder: edge(border),
    numberFormat: _formatOf(value, left: numbersLeft),
  );
  // The constructor of the excel package ignores its underline argument.
  if (link) style.underline = Underline.Single;
  return style;
}

bool _isLink(CellValue? value) => value != null && _linkTextOf[value] != null;

bool _isNumber(CellValue value) => switch (value) {
  IntCellValue() || DoubleCellValue() => true,
  FormulaCellValue() => _decimalsOf[value] != null,
  _ => false,
};

/// Number format of [value]. With [left] a number is followed by a fill of
/// spaces (`* `), which moves it to the left edge of its cell; the excel
/// package cannot write a left alignment.
NumFormat _formatOf(CellValue? value, {bool left = false}) {
  if (value == null || !_isNumber(value)) return NumFormat.defaultFor(value);
  final decimals = _decimalsOf[value] ?? (value is DoubleCellValue ? 2 : 0);
  final code = decimals == 0 ? '0' : '0.${'0' * decimals}';
  if (left) return CustomNumericNumFormat(formatCode: '$code* ');
  if (decimals == 0) return NumFormat.standard_1;
  return CustomNumericNumFormat(formatCode: code);
}

/// Number of characters [value] needs when it is displayed.
int _charsOf(CellValue value) {
  final decimals = _decimalsOf[value];
  return switch (value) {
    TextCellValue() => value.toString().length,
    IntCellValue(:final value) => '$value'.length,
    DoubleCellValue(:final value) =>
      decimals == null
          ? '$value'.length
          : value.toStringAsFixed(decimals).length,
    // The result of a formula is unknown here: room for a link text or for
    // a five-digit number with its decimals.
    FormulaCellValue() => _linkTextOf[value]?.length ?? 6 + (decimals ?? 0),
    _ => value.toString().length,
  };
}
