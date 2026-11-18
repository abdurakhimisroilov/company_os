import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/attachment_opener.dart';
import '../../data/repositories/finance_repository.dart';

/// Picks a file, uploads it to the server with real progress and reports the
/// stored `{url, name}`. A file that ends up not being used (removed, replaced,
/// or the form closed without saving) is deleted from the server again.

class AttachmentPickerCard extends StatefulWidget {
  final String? initialDocumentUrl;
  final String? initialDocumentName;
  final ValueChanged<Map<String, String>?> onAttachmentChanged;
  final ValueChanged<bool>? onUploadingChanged;

  const AttachmentPickerCard({
    super.key,
    this.initialDocumentUrl,
    this.initialDocumentName,
    required this.onAttachmentChanged,
    this.onUploadingChanged,
  });

  @override
  State<AttachmentPickerCard> createState() => _AttachmentPickerCardState();
}

class _AttachmentPickerCardState extends State<AttachmentPickerCard> {
  String? _documentUrl;
  String? _documentName;
  int? _fileSizeBytes;
  bool _isUploading = false;
  double _progress = 0;
  CancelToken? _cancelToken;
  String? _error;

  /// The file was uploaded by this card, so it is ours to delete while unsaved.
  bool _uploadedHere = false;

  @override
  void initState() {
    super.initState();
    _documentUrl = widget.initialDocumentUrl;
    _documentName = widget.initialDocumentName;
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    final url = _documentUrl;
    // The server keeps a file that a saved record refers to and removes an orphan.
    if (_uploadedHere && url != null) _deleteFromServer(url);
    super.dispose();
  }

  void _deleteFromServer(String url) {
    getIt<FinanceRepository>().deleteUploadedFile(url).catchError((_) {});
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 КБ';
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
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png', 'txt'],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось открыть выбор файла');
      return;
    }

    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      setState(() => _error = 'Файл недоступен на устройстве');
      return;
    }

    final cancelToken = CancelToken();
    setState(() {
      _isUploading = true;
      _progress = 0;
      _cancelToken = cancelToken;
      _error = null;
      _documentName = file.name;
      _fileSizeBytes = file.size;
    });
    widget.onUploadingChanged?.call(true);

    try {
      final uploadRes = await getIt<ApiClient>().uploadFile(
        path,
        customFileName: file.name,
        cancelToken: cancelToken,
        onProgress: (value) {
          if (mounted && !cancelToken.isCancelled) setState(() => _progress = value.clamp(0.0, 1.0));
        },
      );
      final url = uploadRes['url']?.toString();
      final name = uploadRes['fileName']?.toString() ?? file.name;
      if (url == null || url.isEmpty) throw Exception('Сервер не вернул путь к файлу');

      if (!mounted || cancelToken.isCancelled) {
        // Cancelled (or the form was closed) after the bytes had already arrived.
        _deleteFromServer(url);
        return;
      }
      setState(() {
        _isUploading = false;
        _cancelToken = null;
        _documentUrl = url;
        _documentName = name;
        _uploadedHere = true;
      });
      widget.onUploadingChanged?.call(false);
      widget.onAttachmentChanged({'url': url, 'name': name});
    } catch (e) {
      if (!mounted) return;
      final cancelled = cancelToken.isCancelled;
      setState(() {
        _isUploading = false;
        _cancelToken = null;
        _documentName = null;
        _fileSizeBytes = null;
        _error = cancelled ? null : apiErrorMessage(e, fallback: 'Не удалось загрузить файл');
      });
      widget.onUploadingChanged?.call(false);
      widget.onAttachmentChanged(null);
    }
  }

  void _cancelUpload() {
    _cancelToken?.cancel();
  }

  void _removeAttachment() {
    final url = _documentUrl;
    if (_uploadedHere && url != null) _deleteFromServer(url);
    setState(() {
      _documentUrl = null;
      _documentName = null;
      _fileSizeBytes = null;
      _uploadedHere = false;
      _error = null;
    });
    widget.onAttachmentChanged(null);
  }

  void _preview() {
    final url = _documentUrl;
    if (url == null) return;
    openServerFile(context, url, fileName: _documentName);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Состояние: файл загружен
    if (_documentUrl != null && !_isUploading) {
      final fileColor = _getFileColor(_documentName);
      return InkWell(
        onTap: _preview,
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
                      Flexible(
                        child: Text(
                          _fileSizeBytes != null
                              ? '${_formatBytes(_fileSizeBytes!)} • Загружен • Нажмите для просмотра'
                              : 'Загружен • Нажмите для просмотра',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
              onPressed: _removeAttachment,
              tooltip: 'Удалить документ',
            ),
          ],
        ),
        ),
      );
    }

    // 2. Состояние: процесс загрузки файла
    if (_isUploading) {
      final percent = (_progress * 100).round();
      return Container(
        padding: const EdgeInsets.only(left: 16, right: 4, top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryBlue,
                value: _progress > 0 ? _progress : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Загрузка ${_documentName ?? 'файла'}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fileSizeBytes != null
                        ? 'Отправлено $percent% из ${_formatBytes(_fileSizeBytes!)}'
                        : 'Отправлено $percent%',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
              onPressed: _cancelUpload,
              tooltip: 'Отменить загрузку',
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
              color: AppColors.cardBackground,
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
                const Flexible(
                  child: Text(
                    'Прикрепить документ (DOCX, PDF, Excel, чек)',
                    softWrap: true,
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
