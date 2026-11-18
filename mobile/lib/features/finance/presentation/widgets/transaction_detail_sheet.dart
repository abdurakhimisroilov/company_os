import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/attachment_opener.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/company_currency.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/finance_repository.dart';

Color transactionColor(TransactionModel tx) {
  if (tx.isTransfer) return AppColors.info;
  return tx.isIncome ? AppColors.success : AppColors.error;
}

Color transactionIconBg(TransactionModel tx) {
  if (tx.isTransfer) return AppColors.infoLight;
  return tx.isIncome ? AppColors.iconBgGreen : AppColors.iconBgRed;
}

IconData transactionIcon(TransactionModel tx) {
  if (tx.isTransfer) return Icons.swap_horiz;
  return tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward;
}

String transactionAmountText(TransactionModel tx) => '${tx.isInflow ? '+' : '-'}${money(tx.amount)}';

/// Read-only details of one operation with its document and a delete action.
/// Pops `true` when the operation has been deleted on the server.
class TransactionDetailSheet extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  static Future<bool?> show(BuildContext context, TransactionModel tx) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(transaction: tx),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  bool _isDeleting = false;
  String? _error;

  TransactionModel get tx => widget.transaction;

  /// Sale payments and transfers are removed together with their document on the server.
  bool get _canDelete {
    final ref = (tx.referenceType ?? '').toUpperCase();
    return !tx.isTransfer && ref != 'SALE' && ref != 'TRANSFER';
  }

  String get _title {
    if (tx.isTransfer) return tx.isTransferIn ? 'Перевод: зачисление' : 'Перевод: списание';
    return tx.isIncome ? 'Поступление средств' : 'Расход средств';
  }

  String get _counterpartyLabel {
    if (tx.isTransfer) return tx.isTransferIn ? 'Со счёта' : 'На счёт';
    return tx.isIncome ? 'Плательщик' : 'Получатель';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Удалить операцию?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Операция на ${money(tx.amount)} будет удалена, а баланс счёта пересчитан. Отменить это действие нельзя.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await getIt<FinanceRepository>().deleteTransaction(tx.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось удалить операцию');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = transactionColor(tx);
    final hasDocument = tx.documentUrl != null && tx.documentUrl!.isNotEmpty;
    final method = tx.paymentMethodLabel;

    return PopScope(
      canPop: !_isDeleting,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.neutral300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: transactionIconBg(tx), shape: BoxShape.circle),
                      child: Icon(transactionIcon(tx), color: amountColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(Formatters.formatDate(tx.date), style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      transactionAmountText(tx),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: amountColor),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                _detailRow('Дата операции', Formatters.formatDate(tx.date)),
                _detailRow('Категория', tx.category),
                if (tx.accountName != null) _detailRow('Счет / Касса', tx.accountName!),
                if (method != null) _detailRow('Способ оплаты', method),
                if (tx.counterparty != null) _detailRow(_counterpartyLabel, tx.counterparty!),
                if (tx.description.isNotEmpty) _detailRow('Описание', tx.description),
                if (tx.employeeName != null) _detailRow('Внёс сотрудник', tx.employeeName!),
                _detailRow('Записано', Formatters.formatDateTime(tx.createdAt)),

                if (hasDocument) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Прикрепленный документ:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.description, color: AppColors.primaryBlue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.documentName ?? 'Документ операции',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text('Прикреплен к операции', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isDeleting
                              ? null
                              : () => openServerFile(context, tx.documentUrl!, fileName: tx.documentName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Открыть', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],

                const SizedBox(height: 20),
                if (_canDelete) ...[
                  OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _confirmDelete,
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: Text(_isDeleting ? 'Удаление…' : 'Удалить операцию'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton(
                  onPressed: _isDeleting ? null : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
