class CodeReference {
  final String filePath;
  final int lineNumber;
  final String lineContent;
  final String usageType;
  final int occurrences;

  const CodeReference({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.usageType,
    this.occurrences = 1,
  });

  @override
  String toString() => '$usageType $filePath:$lineNumber';
}
