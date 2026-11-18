import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/messenger_bloc.dart';
import '../../data/models/chat_model.dart';

class MessengerPage extends StatefulWidget {
  const MessengerPage({super.key});

  @override
  State<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Coming back to the screen keeps the loaded list visible while it refreshes.
    final bloc = context.read<MessengerBloc>();
    bloc.add(LoadChatRoomsEvent(silent: bloc.state is ChatRoomsLoaded));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    final completer = Completer<void>();
    context.read<MessengerBloc>().add(LoadChatRoomsEvent(silent: true, completer: completer));
    return completer.future;
  }

  Future<void> _openRoom(ChatRoomModel room) async {
    await context.push('/messenger/chat/${room.id}?name=${Uri.encodeComponent(room.title)}');
    // Last message and unread counter changed while the chat was open.
    if (mounted) context.read<MessengerBloc>().add(const LoadChatRoomsEvent(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              const SizedBox(height: 4),
              Expanded(
                child: BlocConsumer<MessengerBloc, MessengerState>(
                  listener: (context, state) {
                    if (state is ChatRoomsLoaded && state.refreshError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.refreshError!), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is MessengerError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is ChatRoomsLoaded) {
                      // The server has no room search, so the loaded list is filtered here.
                      final query = _searchController.text.trim().toLowerCase();
                      final rooms = query.isEmpty
                          ? state.rooms
                          : state.rooms.where((r) => r.title.toLowerCase().contains(query)).toList();
                      return _buildChatList(rooms, searching: query.isNotEmpty);
                    }
                    return const LoadingShimmer();
                  },
                ),
              ),
            ],
          ),
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
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Мессенджер',
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
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Поиск чатов...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(List<ChatRoomModel> rooms, {bool searching = false}) {
    if (rooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          children: [
            Text(
              searching ? 'Чаты не найдены' : 'Нет активных диалогов',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              onTap: () => _openRoom(room),
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: room.isGroup ? AppColors.iconBgPurple : AppColors.iconBgBlue,
                    child: Icon(
                      room.isGroup ? Icons.groups : Icons.person,
                      color: room.isGroup ? AppColors.secondaryLavender : AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                room.title,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (room.lastMessage.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(_formatWhen(room.lastMessageTime), style: AppTextStyles.caption),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                room.lastMessage.isNotEmpty ? room.lastMessage : 'Нет сообщений',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            if (room.unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${room.unreadCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Time for today's messages, date for older ones.
  String _formatWhen(DateTime time) {
    final now = DateTime.now();
    final sameDay = time.year == now.year && time.month == now.month && time.day == now.day;
    return sameDay ? Formatters.formatTime(time) : Formatters.formatRelativeDate(time);
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
            onPressed: () => context.read<MessengerBloc>().add(const LoadChatRoomsEvent()),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
