class PageData {
  final int pageNumber;
  final List<String> lines;
  final int totalPages;

  PageData({
    required this.pageNumber,
    required this.lines,
    required this.totalPages,
  });

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;
}
