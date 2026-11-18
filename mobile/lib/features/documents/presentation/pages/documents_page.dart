import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/attachment_opener.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/documents_bloc.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/documents_repository.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _searchController = TextEditingController();
  final _repository = getIt<DocumentsRepository>();
  String? _selectedFolderId;
  String? _selectedFolderName;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _search => _searchController.text.trim();

  void _reload({bool silent = false, Completer<void>? completer}) {
    context.read<DocumentsBloc>().add(LoadDocumentsEvent(
          folderId: _selectedFolderId,
          folderName: _selectedFolderName,
          search: _search,
          silent: silent,
          completer: completer,
        ));
  }

  Future<void> _refresh() {
    final completer = Completer<void>();
    _reload(silent: true, completer: completer);
    return completer.future;
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  void _openFolder(String id, String name) {
    setState(() {
      _selectedFolderId = id;
      _selectedFolderName = name;
    });
    _reload();
  }

  void _goBackToRoot() {
    setState(() {
      _selectedFolderId = null;
      _selectedFolderName = null;
    });
    _reload();
  }

  // ─── Upload ────────────────────────────────────────────────────────────────

  void _showUploadSheet() {
    if (_uploading) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Загрузить документ', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                _selectedFolderName != null ? 'В папку «$_selectedFolderName»' : 'Без папки',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _uploadOption(Icons.insert_drive_file, 'Файл', AppColors.primaryBlue, () {
                    Navigator.pop(ctx);
                    _pickDocument();
                  }),
                  _uploadOption(Icons.image, 'Галерея', AppColors.secondaryLavender, () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  }),
                  _uploadOption(Icons.photo_camera, 'Камера', AppColors.success, () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _uploadOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 26, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final picked = result?.files.single;
      if (picked?.path == null) return;
      await _upload(picked!.path!, picked.name);
    } on PlatformException {
      _showMessage('Не удалось открыть выбор файла', error: true);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (photo == null) return;
      var name = photo.name;
      // Camera shots and re-encoded gallery picks come with a generated temp name.
      if (source == ImageSource.camera || name.startsWith('image_picker') || name.isEmpty) {
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
        name = 'Фото ${DateFormat('dd.MM.yyyy HH-mm-ss').format(DateTime.now())}.$ext';
      }
      await _upload(photo.path, name);
    } on PlatformException catch (e) {
      final denied = e.code.contains('denied');
      _showMessage(
        denied
            ? (source == ImageSource.camera
                ? 'Нет доступа к камере. Разрешите доступ в настройках устройства'
                : 'Нет доступа к фото. Разрешите доступ в настройках устройства')
            : (source == ImageSource.camera ? 'Камера недоступна на этом устройстве' : 'Не удалось открыть галерею'),
        error: true,
      );
    }
  }

  Future<void> _upload(String path, String name) async {
    if (!mounted || _uploading) return;
    final size = await File(path).length();
    if (!mounted) return;
    if (size > DocumentsRepository.maxFileBytes) {
      _showMessage('Файл слишком большой (максимум 25 МБ)', error: true);
      return;
    }
    if (size == 0) {
      _showMessage('Файл пуст', error: true);
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = ValueNotifier<double>(0);
    final cancelToken = CancelToken();
    final folderId = _selectedFolderId;
    var dialogOpen = true;
    _uploading = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: value),
                const SizedBox(height: 12),
                Text(
                  value >= 1 ? 'Обработка на сервере…' : 'Загрузка… ${(value * 100).round()}%',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: cancelToken.cancel, child: const Text('Отмена')),
          ],
        ),
      ),
    ).whenComplete(() => dialogOpen = false);

    void closeDialog() {
      if (dialogOpen) navigator.pop();
    }

    try {
      await _repository.uploadFile(
        filePath: path,
        folderId: folderId,
        fileName: name,
        cancelToken: cancelToken,
        onProgress: (p) => progress.value = p,
      );
      closeDialog();
      _showMessage('Файл «$name» загружен');
      if (mounted) _reload(silent: true);
    } catch (e) {
      closeDialog();
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _showMessage('Загрузка отменена', error: true);
        // A cancel that arrives after the last byte may already be stored.
        if (mounted) _reload(silent: true);
      } else {
        _showMessage(apiErrorMessage(e, fallback: 'Не удалось загрузить файл'), error: true);
      }
    } finally {
      _uploading = false;
      progress.dispose();
    }
  }

  // ─── Folders & files actions ───────────────────────────────────────────────

  /// Asks for a folder name and runs [onSubmit]; closes only when it succeeds.
  Future<bool> _folderNameDialog({
    required String title,
    required String action,
    String initial = '',
    required Future<void> Function(String name) onSubmit,
  }) async {
    final controller = TextEditingController(text: initial);
    var saving = false;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> submit() async {
            final name = controller.text.trim();
            if (name.isEmpty) {
              setDialog(() => error = 'Укажите название папки');
              return;
            }
            setDialog(() {
              saving = true;
              error = null;
            });
            try {
              await onSubmit(name);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) {
                setDialog(() {
                  saving = false;
                  error = apiErrorMessage(e, fallback: 'Не удалось сохранить папку');
                });
              }
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
            content: TextField(
              controller: controller,
              autofocus: true,
              enabled: !saving,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: 'Название папки',
                errorText: error,
                errorMaxLines: 3,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              TextButton(
                onPressed: saving ? null : submit,
                child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(action),
              ),
            ],
          );
        },
      ),
    );
    return ok == true;
  }

  Future<void> _createFolder() async {
    final ok = await _folderNameDialog(title: 'Новая папка', action: 'Создать', onSubmit: _repository.createFolder);
    if (ok && mounted) {
      _showMessage('Папка создана');
      _reload(silent: true);
    }
  }

  Future<void> _renameFolder(DocumentFolderModel folder) async {
    final ok = await _folderNameDialog(
      title: 'Переименовать папку',
      action: 'Сохранить',
      initial: folder.name,
      onSubmit: (name) => _repository.renameFolder(folder.id, name),
    );
    if (ok && mounted) {
      _showMessage('Папка переименована');
      _reload(silent: true);
    }
  }

  Future<bool> _confirm(String title, String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
        content: Text(text, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteFolder(DocumentFolderModel folder) async {
    final text = folder.filesCount > 0
        ? 'Папка «${folder.name}» и все файлы в ней (${folder.filesCountLabel}) будут удалены без возможности восстановления.'
        : 'Папка «${folder.name}» будет удалена.';
    if (!await _confirm('Удалить папку?', text)) return;
    try {
      await _repository.deleteFolder(folder.id);
      _showMessage('Папка удалена');
    } catch (e) {
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить папку'), error: true);
    }
    if (mounted) _reload(silent: true);
  }

  Future<void> _deleteFile(DocumentFileModel file) async {
    if (!await _confirm('Удалить файл?', 'Файл «${file.name}» будет удалён без возможности восстановления.')) return;
    try {
      await _repository.deleteFile(file.id);
      _showMessage('Файл удалён');
    } catch (e) {
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить файл'), error: true);
    }
    if (mounted) _reload(silent: true);
  }

  void _openFile(DocumentFileModel file) {
    if (file.url.isEmpty) {
      _showMessage('Файл недоступен на сервере', error: true);
      return;
    }
    openServerFile(context, file.url, fileName: file.name);
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The system back gesture leaves an open folder first.
      canPop: _selectedFolderId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackToRoot();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildBreadcrumb(),
                Expanded(
                  child: BlocConsumer<DocumentsBloc, DocumentsState>(
                    listener: (context, state) {
                      if (state is DocumentsLoaded && state.refreshError != null) {
                        _showMessage(state.refreshError!, error: true);
                      }
                    },
                    builder: (context, state) {
                      if (state is DocumentsError) {
                        return _buildErrorState(state.message);
                      }
                      // A state left over from another folder is not shown.
                      if (state is DocumentsLoaded && state.currentFolderId == _selectedFolderId) {
                        return _buildContent(state);
                      }
                      return const LoadingShimmer();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showUploadSheet,
          backgroundColor: AppColors.primaryBlue,
          icon: const Icon(Icons.cloud_upload, color: Colors.white),
          label: const Text('Загрузить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'Документы',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _reload(),
          decoration: InputDecoration(
            hintText: 'Поиск файлов по названию...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      _reload();
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          InkWell(
            onTap: _selectedFolderId != null ? _goBackToRoot : null,
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 18,
                  color: _selectedFolderId == null ? AppColors.primaryBlue : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Все папки',
                  style: TextStyle(
                    fontWeight: _selectedFolderId == null ? FontWeight.bold : FontWeight.normal,
                    color: _selectedFolderId == null ? AppColors.primaryBlue : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedFolderName != null) ...[
            Text(' / ', style: TextStyle(color: AppColors.textTertiary)),
            Flexible(
              child: Text(
                _selectedFolderName!,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(DocumentsLoaded state) {
    final atRoot = _selectedFolderId == null;
    final searching = state.searchQuery.isNotEmpty;

    String filesTitle;
    if (searching) {
      filesTitle = 'Результаты поиска (${state.files.length})';
    } else if (atRoot) {
      filesTitle = 'Недавние документы';
    } else {
      filesTitle = 'Файлы в папке (${state.files.length})';
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Folders grid if at root
          if (atRoot && !searching) ...[
            Row(
              children: [
                Expanded(child: Text('Папки', style: AppTextStyles.titleMedium)),
                TextButton.icon(
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('Новая папка'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (state.folders.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                child: Center(child: Text('Папок пока нет', style: AppTextStyles.caption)),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: state.folders.length,
                itemBuilder: (context, idx) => _buildFolderCard(state.folders[idx]),
              ),
            const SizedBox(height: 20),
          ],

          Text(filesTitle, style: AppTextStyles.titleMedium),
          const SizedBox(height: 10),

          if (state.files.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(32),
              borderRadius: 16,
              child: Center(
                child: Column(
                  children: [
                    Icon(searching ? Icons.search_off : Icons.insert_drive_file_outlined, size: 56, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(searching ? 'Ничего не найдено' : 'Данных пока нет', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      searching
                          ? 'Файлов с названием «${state.searchQuery}» нет'
                          : atRoot
                              ? 'Загруженных документов пока нет'
                              : 'В этой папке пока нет файлов',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    if (!searching) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showUploadSheet,
                        icon: const Icon(Icons.cloud_upload, size: 18),
                        label: const Text('Загрузить документ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...state.files.map((file) => _buildFileRow(file)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFolderCard(DocumentFolderModel f) {
    return GlassCard(
      onTap: () => _openFolder(f.id, f.name),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.iconBgBlue, shape: BoxShape.circle),
            child: const Icon(Icons.folder, color: AppColors.primaryBlue, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  f.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(f.filesCountLabel, style: AppTextStyles.caption),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            color: AppColors.cardBackground,
            onSelected: (v) => v == 'rename' ? _renameFolder(f) : _deleteFolder(f),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text('Переименовать', style: TextStyle(color: AppColors.textPrimary))),
              const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileRow(DocumentFileModel file) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    final ext = file.extension;
    if (ext == 'pdf') {
      icon = Icons.picture_as_pdf;
      iconColor = AppColors.error;
      iconBg = AppColors.iconBgRed;
    } else if (ext == 'docx' || ext == 'doc') {
      icon = Icons.description;
      iconColor = AppColors.primaryBlue;
      iconBg = AppColors.iconBgBlue;
    } else if (ext == 'xlsx' || ext == 'xls' || ext == 'csv') {
      icon = Icons.table_chart;
      iconColor = AppColors.success;
      iconBg = AppColors.iconBgGreen;
    } else if (file.isImage) {
      icon = Icons.image;
      iconColor = AppColors.secondaryLavender;
      iconBg = AppColors.iconBgPurple;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = AppColors.primaryBlue;
      iconBg = AppColors.iconBgBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => _openFile(file),
        padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
        borderRadius: 14,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${file.sizeFormatted} • ${Formatters.formatDate(file.createdAt)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
              color: AppColors.cardBackground,
              onSelected: (v) => v == 'open' ? _openFile(file) : _deleteFile(file),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'open', child: Text('Открыть', style: TextStyle(color: AppColors.textPrimary))),
                const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: AppColors.error))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _reload,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
