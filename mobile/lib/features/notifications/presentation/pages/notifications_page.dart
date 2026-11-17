import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/notifications_bloc.dart';
import '../../data/models/notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(LoadNotificationsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Уведомления'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: AppColors.primaryBlue),
            tooltip: 'Прочитать все',
            onPressed: () {
              context.read<NotificationsBloc>().add(MarkAllNotificationsReadEvent());
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            if (state is NotificationsLoading) {
              return const LoadingShimmer();
            }
            if (state is NotificationsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.message,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<NotificationsBloc>().add(LoadNotificationsEvent()),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            }
            if (state is NotificationsLoaded) {
              return _buildList(state.notifications);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildList(List<AppNotificationModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Уведомлений пока нет',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<NotificationsBloc>().add(LoadNotificationsEvent());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final n = list[index];
          return Dismissible(
            key: ValueKey(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 10),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
            ),
            onDismissed: (_) {
              context.read<NotificationsBloc>().add(DeleteNotificationEvent(n.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Уведомление удалено'), duration: Duration(seconds: 2)),
              );
            },
            child: _buildNotificationCard(n),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(AppNotificationModel n) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    final typeLower = n.type.toLowerCase();
    if (typeLower.contains('finance') || typeLower.contains('payment')) {
      icon = Icons.payments_outlined;
      iconColor = AppColors.success;
      iconBg = AppColors.iconBgGreen;
    } else if (typeLower.contains('inventory') || typeLower.contains('stock') || typeLower.contains('shipment')) {
      icon = Icons.local_shipping_outlined;
      iconColor = AppColors.warning;
      iconBg = AppColors.warningLight;
    } else if (typeLower.contains('task')) {
      icon = Icons.assignment_outlined;
      iconColor = AppColors.secondaryLavender;
      iconBg = AppColors.iconBgPurple;
    } else if (typeLower.contains('deal')) {
      icon = Icons.handshake_outlined;
      iconColor = AppColors.primaryBlue;
      iconBg = AppColors.iconBgBlue;
    } else {
      icon = Icons.notifications_outlined;
      iconColor = AppColors.primaryBlue;
      iconBg = AppColors.iconBgBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          if (!n.isRead) {
            context.read<NotificationsBloc>().add(MarkNotificationReadEvent(n.id));
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 16,
          borderColor: !n.isRead ? AppColors.primaryBlue.withOpacity(0.5) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: !n.isRead ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.formatTime(n.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
