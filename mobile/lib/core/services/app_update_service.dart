import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final int minSupportedVersion;
  final String downloadUrl;
  final int fileSize;
  final String title;
  final List<String> changelog;
  final bool forceUpdate;
  final DateTime? releaseDate;

  AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.minSupportedVersion,
    required this.downloadUrl,
    required this.fileSize,
    required this.title,
    required this.changelog,
    required this.forceUpdate,
    this.releaseDate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionCode: json['versionCode'] is int
          ? json['versionCode'] as int
          : int.tryParse(json['versionCode']?.toString() ?? '1') ?? 1,
      versionName: json['versionName']?.toString() ?? '1.0.0',
      minSupportedVersion: json['minSupportedVersion'] is int
          ? json['minSupportedVersion'] as int
          : int.tryParse(json['minSupportedVersion']?.toString() ?? '1') ?? 1,
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      fileSize: json['fileSize'] is int
          ? json['fileSize'] as int
          : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? 'Доступно обновление',
      changelog: (json['changelog'] is List)
          ? (json['changelog'] as List).map((e) => e.toString()).toList()
          : [],
      forceUpdate: json['forceUpdate'] == true,
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'].toString())
          : null,
    );
  }
}

class AppUpdateService {
  final ApiClient apiClient;
  static const MethodChannel _channel = MethodChannel('com.companyos.app/updater');
  static bool _hasAutoCheckedThisSession = false;

  static const int currentCodeConstant = 3;
  static const String currentNameConstant = '1.0.2';

  AppUpdateService({required this.apiClient});

  /// Получить текущую установленную версию приложения из Android PackageManager
  Future<Map<String, dynamic>> getCurrentVersion() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
      if (res != null) {
        final nativeCode = (res['versionCode'] is int)
            ? res['versionCode'] as int
            : int.tryParse(res['versionCode']?.toString() ?? '0') ?? 0;
        final nativeName = res['versionName']?.toString();

        final effectiveCode = nativeCode > currentCodeConstant ? nativeCode : currentCodeConstant;
        final effectiveName = (nativeName != null && nativeName != '1.0.0') ? nativeName : currentNameConstant;

        return {
          'versionName': effectiveName,
          'versionCode': effectiveCode,
        };
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Native getAppVersion error: $e');
    }
    return {'versionName': currentNameConstant, 'versionCode': currentCodeConstant};
  }

  /// Проверить наличие обновления на сервере
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.appVersion);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final updateInfo = AppUpdateInfo.fromJson(response.data as Map<String, dynamic>);
        final current = await getCurrentVersion();
        final currentCode = current['versionCode'] as int;
        final currentName = current['versionName'] as String;

        // Если версия на сервере совпадает с текущей или меньше — обновление НЕ требуется
        if (updateInfo.versionCode <= currentCode || updateInfo.versionName == currentName) {
          debugPrint('[AppUpdateService] Already up to date: local v$currentName ($currentCode) >= remote v${updateInfo.versionName} (${updateInfo.versionCode})');
          return null;
        }

        return updateInfo;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] checkForUpdate error: $e');
    }
    return null;
  }

  /// Скачать и запустить установку APK
  Future<void> downloadAndInstall({
    required String downloadUrl,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/company_os_latest.apk';

    // Удалить старый файл загрузки, если остался
    final file = File(filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    // Скачивание через Dio
    await apiClient.dio.download(
      downloadUrl,
      filePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );

    // Запуск нативной установки Android
    await _channel.invokeMethod('installApk', {'filePath': filePath});
  }

  /// Показать диалоговое окно обновления
  Future<void> showUpdatePrompt(
    BuildContext context, {
    AppUpdateInfo? updateInfo,
    bool isManualCheck = false,
  }) async {
    // Для автопроверки: показывать диалог максимум один раз за сессию
    if (!isManualCheck && _hasAutoCheckedThisSession) {
      return;
    }

    AppUpdateInfo? info = updateInfo;
    if (info == null) {
      info = await checkForUpdate();
    }

    if (!context.mounted) return;

    if (info == null) {
      if (isManualCheck) {
        final current = await getCurrentVersion();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'У вас установлена последняя версия (${current['versionName']})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    // Отмечаем, что автопроверка показана в этой сессии
    _hasAutoCheckedThisSession = true;

    await showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (dialogCtx) => _AppUpdateDialog(
        updateInfo: info!,
        updateService: this,
      ),
    );
  }
}

class _AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final AppUpdateService updateService;

  const _AppUpdateDialog({
    required this.updateInfo,
    required this.updateService,
  });

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  CancelToken? _cancelToken;
  String? _errorMessage;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.updateInfo.fileSize;
      _cancelToken = CancelToken();
    });

    try {
      await widget.updateService.downloadAndInstall(
        downloadUrl: widget.updateInfo.downloadUrl,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = received;
            _totalBytes = total > 0 ? total : widget.updateInfo.fileSize;
            if (_totalBytes > 0) {
              _progress = (received / _totalBytes).clamp(0.0, 1.0);
            }
          });
        },
      );
      if (mounted && !widget.updateInfo.forceUpdate) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Ошибка загрузки: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя плашка с иконкой и версией
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.updateInfo.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'v${widget.updateInfo.versionName}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          if (widget.updateInfo.fileSize > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatBytes(widget.updateInfo.fileSize),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Список изменений
            if (widget.updateInfo.changelog.isNotEmpty) ...[
              const Text(
                'Что нового в этой версии:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                padding: const EdgeInsets.all(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.updateInfo.changelog.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 6, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.updateInfo.changelog[i],
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Индикатор процесса загрузки
            if (_isDownloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Загрузка: ${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'По завершении откроется окно установки',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // Ошибка, если возникла
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],

            // Кнопки действий
            Row(
              children: [
                if (!widget.updateInfo.forceUpdate && !_isDownloading)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Позже',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                if (!widget.updateInfo.forceUpdate && !_isDownloading)
                  const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isDownloading ? null : _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isDownloading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Обновить сейчас',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
