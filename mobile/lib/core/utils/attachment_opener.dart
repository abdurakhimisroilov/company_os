import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';
import '../theme/app_colors.dart';

/// Downloads a file stored on the server (absolute URL or `/uploads/...`) with
/// a real progress indicator and opens it in the system viewer.
Future<void> openServerFile(BuildContext context, String url, {String? fileName}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<double?>(null);
  var dialogOpen = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.cardBackground,
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 16),
              Text(
                value == null ? 'Загрузка документа…' : 'Загрузка документа… ${(value * 100).round()}%',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (dialogOpen) navigator.pop();
  }

  try {
    final cleanUrl = url.split('?').first;
    final rawName = (fileName != null && fileName.trim().isNotEmpty) ? fileName.trim() : cleanUrl.split('/').last;
    final urlExt = cleanUrl.contains('.') ? cleanUrl.split('.').last : '';
    // The viewer picks the app by extension, so the saved name must carry the real one.
    final safeName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final name = safeName.contains('.') || urlExt.isEmpty ? safeName : '$safeName.$urlExt';

    final dir = Directory('${(await getTemporaryDirectory()).path}/attachments');
    await dir.create(recursive: true);
    final path = '${dir.path}/$name';
    await getIt<ApiClient>().downloadFile(url, path, onProgress: (p) => progress.value = p);
    closeDialog();

    final result = await OpenFilex.open(path);
    if (result.type == ResultType.noAppToOpen) {
      messenger.showSnackBar(SnackBar(content: Text('На устройстве нет приложения для открытия файла «$name»')));
    } else if (result.type != ResultType.done) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось открыть файл: ${result.message}'), backgroundColor: AppColors.error));
    }
  } catch (e) {
    closeDialog();
    messenger.showSnackBar(
      SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось загрузить документ')), backgroundColor: AppColors.error),
    );
  } finally {
    progress.dispose();
  }
}
