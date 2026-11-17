import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/documents_bloc.dart';
import '../../data/models/document_model.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _searchController = TextEditingController();
  String? _selectedFolderId;
  String? _selectedFolderName;

  @override
  void initState() {
    super.initState();
    context.read<DocumentsBloc>().add(const LoadDocumentsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFolder(String id, String name) {
    setState(() {
      _selectedFolderId = id;
      _selectedFolderName = name;
    });
    context.read<DocumentsBloc>().add(
          LoadDocumentsEvent(folderId: id, folderName: name, search: _searchController.text.trim()),
        );
  }

  void _goBackToRoot() {
    setState(() {
      _selectedFolderId = null;
      _selectedFolderName = null;
    });
    context.read<DocumentsBloc>().add(const LoadDocumentsEvent());
  }

  void _uploadFileDialog() {
    final fileNameController = TextEditingController(text: 'Документ_${DateTime.now().millisecondsSinceEpoch}.pdf');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Загрузить документ', style: AppTextStyles.titleMedium),
            const SizedBox(height: 14),
            TextField(
              controller: fileNameController,
              decoration: InputDecoration(
                labelText: 'Имя файла',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<DocumentsBloc>().add(
                      UploadDocumentEvent(
                        folderId: _selectedFolderId ?? 'contracts',
                        fileName: fileNameController.text.trim(),
                      ),
                    );
              },
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Загрузить в хранилище'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
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
                    if (state is DocumentsActionSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is DocumentsLoading) {
                      return const LoadingShimmer();
                    }
                    if (state is DocumentsError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is DocumentsLoaded) {
                      return _buildContent(state);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadFileDialog,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.cloud_upload, color: Colors.white),
        label: const Text('Загрузить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          const Expanded(
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
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: (q) {
            context.read<DocumentsBloc>().add(
                  LoadDocumentsEvent(folderId: _selectedFolderId, folderName: _selectedFolderName, search: q),
                );
          },
          decoration: InputDecoration(
            hintText: 'Поиск файлов по названию...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
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
            const Text(' / ', style: TextStyle(color: AppColors.textTertiary)),
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
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DocumentsBloc>().add(
              LoadDocumentsEvent(folderId: _selectedFolderId, folderName: _selectedFolderName),
            );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Folders grid if at root
          if (_selectedFolderId == null && state.folders.isNotEmpty) ...[
            Text('Папки', style: AppTextStyles.titleMedium),
            const SizedBox(height: 10),
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
              itemBuilder: (context, idx) {
                final f = state.folders[idx];
                return GlassCard(
                  onTap: () => _openFolder(f.id, f.name),
                  padding: const EdgeInsets.all(12),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text('${f.filesCount} файлов', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          Text(
            _selectedFolderId == null ? 'Недавние документы' : 'Файлы в папке (${state.files.length})',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 10),

          if (state.files.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(32),
              borderRadius: 16,
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.insert_drive_file_outlined, size: 56, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text('Данных пока нет', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('В этой папке пока нет файлов', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _uploadFileDialog,
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
                ),
              ),
            )
          else
            ...state.files.map((file) => _buildFileRow(file)),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildFileRow(DocumentFileModel file) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    final ext = file.extension.toLowerCase();
    if (ext == 'pdf') {
      icon = Icons.picture_as_pdf;
      iconColor = AppColors.error;
      iconBg = AppColors.iconBgRed;
    } else if (ext == 'docx' || ext == 'doc') {
      icon = Icons.description;
      iconColor = AppColors.primaryBlue;
      iconBg = AppColors.iconBgBlue;
    } else if (ext == 'xlsx' || ext == 'xls') {
      icon = Icons.table_chart;
      iconColor = AppColors.success;
      iconBg = AppColors.iconBgGreen;
    } else {
      icon = Icons.image;
      iconColor = AppColors.secondaryLavender;
      iconBg = AppColors.iconBgPurple;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${file.sizeFormatted} • ${Formatters.formatDate(file.updatedAt)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined, color: AppColors.primaryBlue),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Скачивание файла: ${file.name}')),
                );
              },
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
          Text(message, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<DocumentsBloc>().add(const LoadDocumentsEvent()),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
