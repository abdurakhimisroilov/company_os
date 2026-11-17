import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

class AttachmentPickerCard extends StatefulWidget {
  final String? initialDocumentUrl;
  final String? initialDocumentName;
  final ValueChanged<Map<String, String>?> onAttachmentChanged;

  const AttachmentPickerCard({
    super.key,
    this.initialDocumentUrl,
    this.initialDocumentName,
    required this.onAttachmentChanged,
  });

  @override
  State<AttachmentPickerCard> createState() => _AttachmentPickerCardState();
}

class _AttachmentPickerCardState extends State<AttachmentPickerCard> {
  String? _documentUrl;
  String? _documentName;
  int? _fileSizeBytes;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _documentUrl = widget.initialDocumentUrl;
    _documentName = widget.initialDocumentName;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  IconData _getFileIcon(String? name) {
    if (name == null) return Icons.insert_drive_file_outlined;
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'doc':
      case 'docx':
        return Icons.article_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.attach_file_rounded;
    }
  }

  Color _getFileColor(String? name) {
    if (name == null) return AppColors.primaryBlue;
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'doc':
      case 'docx':
        return const Color(0xFF2B579A); // Word Blue
      case 'xls':
      case 'xlsx':
        return const Color(0xFF217346); // Excel Green
      case 'pdf':
        return const Color(0xFFD32F2F); // PDF Red
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Color(0xFF7B1FA2); // Image Purple
      default:
        return AppColors.primaryBlue;
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;

      setState(() {
        _isUploading = true;
        _error = null;
        _documentName = file.name;
        _fileSizeBytes = file.size;
      });

      final apiClient = getIt<ApiClient>();
      final uploadRes = await apiClient.uploadFile(file.path!, customFileName: file.name);

      final url = uploadRes['url']?.toString();
      final name = uploadRes['fileName']?.toString() ?? file.name;

      if (url != null) {
        setState(() {
          _isUploading = false;
          _documentUrl = url;
          _documentName = name;
        });
        widget.onAttachmentChanged({'url': url, 'name': name});
      } else {
        throw Exception('Сервер не вернул путь к файлу');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Ошибка загрузки: $e';
      });
      widget.onAttachmentChanged(null);
    }
  }

  void _removeAttachment() {
    setState(() {
      _documentUrl = null;
      _documentName = null;
      _fileSizeBytes = null;
      _error = null;
    });
    widget.onAttachmentChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Состояние: файл загружен
    if (_documentUrl != null && !_isUploading) {
      final fileColor = _getFileColor(_documentName);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fileColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fileColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fileColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getFileIcon(_documentName), color: fileColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _documentName ?? 'Документ прикреплен',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        _fileSizeBytes != null
                            ? '${_formatBytes(_fileSizeBytes!)} • Загружен на сервер'
                            : 'Готов к сохранению',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
              onPressed: _removeAttachment,
              tooltip: 'Удалить документ',
            ),
          ],
        ),
      );
    }

    // 2. Состояние: процесс загрузки файла
    if (_isUploading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Загрузка ${_documentName ?? 'файла'}...',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text('Отправка на сервер компании...', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3. Состояние: кнопка добавления документа
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickAndUploadFile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.attach_file, color: AppColors.primaryBlue, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Прикрепить документ (DOCX, PDF, Excel, чек)',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.error, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
