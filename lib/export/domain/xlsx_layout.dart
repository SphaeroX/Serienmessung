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

/// Texts longer than this wrap inside a table instead of widening it.
const _wrapChars = 46;

/// Longest text of a key figure that still widens its column; longer texts
/// (descriptions, notes) run over the empty cells to their right.
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
      _put(1, value, _style(value: value, numbersLeft: true));
      final chars = _charsOf(value);
      if (value is! TextCellValue || chars <= _valueChars) _measure(1, chars);
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
    var lines = 1;
    for (var c = 0; c < count; c++) {
      final v = c < values.length ? values[c] : null;
      final chars = v == null ? 0 : _charsOf(v);
      final wrap = v is TextCellValue && chars > _wrapChars;
      if (wrap) {
        final needed = (chars / _wrapChars).ceil();
        if (needed > lines) lines = needed;
      }
      _put(
        c,
        v,
        _style(
          value: v,
          bold: total,
          fill: total ? _brandTint : (banded ? _band : ExcelColor.none),
          wrap: wrap,
          border: _line,
          topBorder: total ? _brand : _line,
        ),
      );
      if (v == null) continue;
      if (!total) (_isNumber(v) ? _numbers : _texts).add(c);
      _measure(c, wrap ? _wrapChars : chars, bold: total);
    }
    _dataRows++;
    return _next(lines == 1 ? _rowHeight : lines * 15.0 + 3);
  }

  /// Sets the column widths; call once after the last row.
  void finish() {
    _endTable();
    _chars.forEach((column, chars) {
      final width = (chars + 2.5).clamp(_minWidth, _maxWidth);
      sheet.setColumnWidth(column, (width * 10).ceil() / 10);
    });
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

  void _put(int column, CellValue? value, CellStyle style) => sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: column, rowIndex: _row),
    value,
    cellStyle: style,
  );

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
