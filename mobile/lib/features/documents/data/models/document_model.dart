import '../../../../core/utils/json_helpers.dart';

class DocumentFolderModel {
  final String id;
  final String name;
  final int filesCount;

  const DocumentFolderModel({
    required this.id,
    required this.name,
    this.filesCount = 0,
  });

  factory DocumentFolderModel.fromJson(Map<String, dynamic> json) {
    return DocumentFolderModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name'], 'Папка'),
      filesCount: JsonHelpers.toInt(json['filesCount'] ?? json['files_count']),
    );
  }
}

class DocumentFileModel {
  final String id;
  final String folderId;
  final String name;
  final String extension; // 'pdf', 'docx', 'xlsx', 'png', 'jpg'
  final int sizeBytes;
  final String? url;
  final DateTime updatedAt;

  const DocumentFileModel({
    required this.id,
    required this.folderId,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    this.url,
    required this.updatedAt,
  });

  String get sizeFormatted {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(0)} КБ';
  }

  factory DocumentFileModel.fromJson(Map<String, dynamic> json) {
    return DocumentFileModel(
      id: JsonHelpers.toStr(json['id']),
      folderId: JsonHelpers.toStr(json['folderId'] ?? json['folder_id']),
      name: JsonHelpers.toStr(json['name'], 'Документ'),
      extension: JsonHelpers.toStr(json['extension'] ?? json['ext'], 'pdf').toLowerCase().replaceAll('.', ''),
      sizeBytes: JsonHelpers.toInt(json['sizeBytes'] ?? json['file_size'] ?? json['size'], 1024),
      url: JsonHelpers.extractOptionalString(json['url'] ?? json['file_path']),
      updatedAt: JsonHelpers.toDateTime(json['updatedAt'] ?? json['updated_at'] ?? json['created_at']),
    );
  }
}
