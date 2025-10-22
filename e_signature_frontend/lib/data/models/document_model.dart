class Document {
  final int documentId;
  final String fileName;
  final int statusId;
  final DateTime createdAt;

  Document({
    required this.documentId,
    required this.fileName,
    required this.statusId,
    required this.createdAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      documentId: json['document_id'],
      fileName: json['file_name'],
      statusId: json['status_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}