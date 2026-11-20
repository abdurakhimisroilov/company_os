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
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/attachment_opener.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/chat_cubit.dart';
import '../../data/models/chat_model.dart';
import '../../data/repositories/messenger_repository.dart';

class ChatPage extends StatefulWidget {
  final String roomId;
  final String? roomName;

  const ChatPage({super.key, required this.roomId, this.roomName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  /// There is no live socket in the app: the open room is re-read on a timer.
  static const _pollInterval = Duration(seconds: 4);
  static const _imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp'];

  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _repository = getIt<MessengerRepository>();
  late final ChatCubit _cubit;
  Timer? _pollTimer;

  String? _replyToText;
  bool _sending = false;
  String? _uploadingName;
  double _uploadProgress = 0;
  CancelToken? _uploadCancel;

  @override
  void initState() {
    super.initState();
    _cubit = ChatCubit(repository: _repository, roomId: widget.roomId)..load();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _uploadCancel?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cubit.poll();
      _startPolling();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _cubit.poll());
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: AppColors.error));
  }

  void _scrollToBottom() {
    // The list is reversed: offset 0 is the newest message.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await _cubit.send(text, replyTo: _replyToText);
      if (!mounted) return;
      _messageController.clear();
      setState(() => _replyToText = null);
      _scrollToBottom();
    } catch (e) {
      // The draft stays in the field so it can be sent again.
      _showError(apiErrorMessage(e, fallback: 'Не удалось отправить сообщение'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showAttachMenu() {
    if (_uploadingName != null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _attachOption(Icons.image, 'Фото', AppColors.primaryBlue, () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              }),
              _attachOption(Icons.photo_camera, 'Камера', AppColors.success, () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              }),
              _attachOption(Icons.insert_drive_file, 'Документ', AppColors.secondaryLavender, () {
                Navigator.pop(ctx);
                _pickDocument();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final picked = result?.files.single;
      if (picked?.path == null) return;
      await _sendAttachment(picked!.path!, picked.name);
    } on PlatformException {
      _showError('Не удалось открыть выбор файла');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400);
      if (photo == null) return;
      var name = photo.name;
      // Camera shots and re-encoded gallery picks come with a generated temp name.
      if (source == ImageSource.camera || name.startsWith('image_picker') || name.isEmpty) {
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
        name = 'Фото ${DateFormat('dd.MM.yyyy HH-mm-ss').format(DateTime.now())}.$ext';
      }
      await _sendAttachment(photo.path, name);
    } on PlatformException catch (e) {
      final denied = e.code.contains('denied');
      if (source == ImageSource.camera) {
        _showError(denied ? 'Нет доступа к камере. Разрешите доступ в настройках устройства' : 'Камера недоступна на этом устройстве');
      } else {
        _showError(denied ? 'Нет доступа к фото. Разрешите доступ в настройках устройства' : 'Не удалось открыть галерею');
      }
    }
  }

  /// Uploads the file first, then sends a message that points to it.
  Future<void> _sendAttachment(String path, String name) async {
    if (!mounted || _uploadingName != null) return;
    final size = await File(path).length();
    if (!mounted) return;
    if (size > MessengerRepository.maxFileBytes) {
      _showError('Файл слишком большой (максимум 25 МБ)');
      return;
    }

    final cancel = CancelToken();
    setState(() {
      _uploadingName = name;
      _uploadProgress = 0;
      _uploadCancel = cancel;
    });
    try {
      final url = await _repository.uploadAttachment(
        path,
        fileName: name,
        cancelToken: cancel,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      await _cubit.send(
        name,
        replyTo: _replyToText,
        attachmentUrl: url,
        attachmentType: _imageExtensions.contains(ext) ? 'image' : 'file',
      );
      if (!mounted) return;
      setState(() => _replyToText = null);
      _scrollToBottom();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _showError('Загрузка отменена');
      } else {
        _showError('Файл не отправлен: ${apiErrorMessage(e, fallback: 'ошибка загрузки')}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingName = null;
          _uploadCancel = null;
        });
      }
    }
  }

  static const _reportReasons = ['Оскорбление или угрозы', 'Спам или мошенничество', 'Неприемлемый контент', 'Другое'];

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _sheet(BuildContext ctx, List<Widget> children) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: children)),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color == AppColors.error ? AppColors.error : AppColors.textPrimary)),
      onTap: onTap,
    );
  }

  /// Long press on a message: reply, and for other people's messages report or block.
  void _showMessageActions(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(ctx, [
        _sheetTile(Icons.reply, 'Ответить', AppColors.primaryBlue, () {
          Navigator.pop(ctx);
          setState(() => _replyToText = msg.hasAttachment ? msg.attachmentName : msg.content);
        }),
        if (!msg.isMine && msg.senderId.isNotEmpty) ...[
          _sheetTile(Icons.flag_outlined, 'Пожаловаться', AppColors.error, () {
            Navigator.pop(ctx);
            _reportMessage(msg);
          }),
          _sheetTile(Icons.block, 'Заблокировать ${msg.senderName.isNotEmpty ? msg.senderName : 'пользователя'}', AppColors.error, () {
            Navigator.pop(ctx);
            _blockSender(msg);
          }),
        ],
      ]),
    );
  }

  Future<void> _reportMessage(MessageModel msg) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(ctx, [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('Причина жалобы', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        ),
        for (final r in _reportReasons)
          ListTile(title: Text(r, style: TextStyle(color: AppColors.textPrimary)), onTap: () => Navigator.pop(ctx, r)),
      ]),
    );
    if (reason == null) return;
    try {
      await _cubit.report(msg, reason);
      _showSnack('Жалоба отправлена. Сообщение скрыто, мы рассмотрим его в течение 24 часов');
    } catch (e) {
      _showError(apiErrorMessage(e, fallback: 'Не удалось отправить жалобу'));
    }
  }

  Future<void> _blockSender(MessageModel msg) async {
    final name = msg.senderName.isNotEmpty ? msg.senderName : 'этого пользователя';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заблокировать?'),
        content: Text('Вы больше не будете видеть сообщения от $name. Разблокировать можно в списке «Заблокированные».'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Заблокировать', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _cubit.blockSender(msg);
      _showSnack('Пользователь заблокирован');
    } catch (e) {
      _showError(apiErrorMessage(e, fallback: 'Не удалось заблокировать пользователя'));
    }
  }

  Future<void> _showBlockedUsers() async {
    List<({String id, String name})> users;
    try {
      users = await _repository.getBlockedUsers();
    } catch (e) {
      _showError(apiErrorMessage(e, fallback: 'Не удалось загрузить список'));
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _sheet(ctx, [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Заблокированные', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Вы никого не заблокировали', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            ),
          for (final u in users)
            ListTile(
              leading: Icon(Icons.person_off_outlined, color: AppColors.textSecondary),
              title: Text(u.name, style: TextStyle(color: AppColors.textPrimary)),
              trailing: TextButton(
                child: const Text('Разблокировать'),
                onPressed: () async {
                  try {
                    await _repository.unblockUser(u.id);
                    setSheet(() => users = users.where((x) => x.id != u.id).toList());
                    _cubit.poll();
                  } catch (e) {
                    _showError(apiErrorMessage(e, fallback: 'Не удалось разблокировать'));
                  }
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
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

  @override
  Widget build(BuildContext context) {
    final title = (widget.roomName ?? '').isNotEmpty ? widget.roomName! : 'Чат';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground.withValues(alpha: 0.9),
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.iconBgPurple,
              child: const Icon(Icons.groups, color: AppColors.secondaryLavender, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.block, color: AppColors.textSecondary, size: 22),
            tooltip: 'Заблокированные',
            onPressed: _showBlockedUsers,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatCubit, ChatState>(
                bloc: _cubit,
                builder: (context, state) {
                  final messages = state.messages;
                  if (messages != null) return _buildMessagesList(messages);
                  if (state.error != null) return _buildError(state.error!);
                  return const LoadingShimmer();
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
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
          ElevatedButton(onPressed: _cubit.load, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<MessageModel> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Text('Начните диалог первым', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
      );
    }

    // Reversed so the newest message stays at the bottom as history grows.
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(messages[messages.length - 1 - index]),
    );
  }

  Widget _buildMessageBubble(MessageModel msg) {
    final isMine = msg.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.selectionClick();
          _showMessageActions(msg);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primaryBlue : AppColors.cardBackground.withValues(alpha: 0.9),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine && msg.senderName.isNotEmpty)
                Text(
                  msg.senderName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryBlue),
                ),
              if (msg.replyToContent != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.white.withValues(alpha: 0.2) : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: isMine ? Colors.white : AppColors.primaryBlue, width: 3)),
                  ),
                  child: Text(
                    msg.replyToContent!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              if (msg.hasAttachment)
                _buildAttachment(msg)
              else
                Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                Formatters.formatTime(msg.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white70 : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachment(MessageModel msg) {
    final isMine = msg.isMine;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;

    final fileTile = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(msg.isImage ? Icons.image : Icons.insert_drive_file, color: isMine ? Colors.white : AppColors.primaryBlue, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            msg.attachmentName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor, decoration: TextDecoration.underline, decorationColor: textColor),
          ),
        ),
      ],
    );

    return InkWell(
      onTap: () => openServerFile(context, msg.attachmentUrl!, fileName: msg.attachmentName),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: msg.isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  getIt<ApiClient>().resolveFileUrl(msg.attachmentUrl!),
                  width: 200,
                  height: 200,
                  cacheWidth: 600,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: isMine ? Colors.white : AppColors.primaryBlue),
                            ),
                          ),
                        ),
                  // A preview that cannot be decoded still opens as a file.
                  errorBuilder: (_, __, ___) => fileTile,
                ),
              )
            : fileTile,
      ),
    );
  }

  Widget _buildInputArea() {
    final uploading = _uploadingName != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (uploading)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                color: AppColors.background,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _uploadProgress >= 1
                                ? 'Отправка «$_uploadingName»…'
                                : 'Загрузка «$_uploadingName»… ${(_uploadProgress * 100).round()}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Отменить загрузку',
                          onPressed: () => _uploadCancel?.cancel(),
                        ),
                      ],
                    ),
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 3,
                      backgroundColor: AppColors.neutral200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
            if (_replyToText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: AppColors.background,
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ответ: $_replyToText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _replyToText = null),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBlue),
                    onPressed: uploading ? null : _showAttachMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Сообщение...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
