class CodeReference {
  final String filePath;
  final int lineNumber;
  final String lineContent;
  final String usageType;

  const CodeReference({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.usageType,
  });

  @override
  String toString() => '$usageType $filePath:$lineNumber';
}
