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

  /// "1 файл", "3 файла", "12 файлов"
  String get filesCountLabel {
    final n = filesCount % 100;
    final d = n % 10;
    if (n >= 11 && n <= 14) return '$filesCount файлов';
    if (d == 1) return '$filesCount файл';
    if (d >= 2 && d <= 4) return '$filesCount файла';
    return '$filesCount файлов';
  }

  factory DocumentFolderModel.fromJson(Map<String, dynamic> json) {
    return DocumentFolderModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name']),
      filesCount: JsonHelpers.toInt(json['filesCount'] ?? json['files_count']),
    );
  }
}

class DocumentFileModel {
  final String id;
  final String folderId;
  final String name;
  final String extension; // lower case, without the dot; '' when unknown
  final int sizeBytes;
  final String url;
  final DateTime createdAt;

  const DocumentFileModel({
    required this.id,
    required this.folderId,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.url,
    required this.createdAt,
  });

  static const imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp'];

  bool get isImage => imageExtensions.contains(extension);

  String get sizeFormatted {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} КБ';
    }
    return '$sizeBytes Б';
  }

  factory DocumentFileModel.fromJson(Map<String, dynamic> json) {
    final name = JsonHelpers.toStr(json['name']);
    var ext = JsonHelpers.toStr(json['extension'] ?? json['ext'] ?? json['file_type']).toLowerCase().replaceAll('.', '');
    if (ext.isEmpty && name.contains('.')) ext = name.split('.').last.toLowerCase();
    return DocumentFileModel(
      id: JsonHelpers.toStr(json['id']),
      folderId: JsonHelpers.toStr(json['folderId'] ?? json['folder_id']),
      name: name,
      extension: ext,
      sizeBytes: JsonHelpers.toInt(json['sizeBytes'] ?? json['file_size'] ?? json['size']),
      url: JsonHelpers.toStr(json['url'] ?? json['file_path']),
      createdAt: JsonHelpers.toDateTime(json['created_at'] ?? json['createdAt']).toLocal(),
    );
  }
}
