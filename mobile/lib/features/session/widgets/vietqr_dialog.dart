import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../services/vietqr_service.dart';
import '../models/session_model.dart';

class VietQrDialog extends StatelessWidget {
  const VietQrDialog({
    super.key,
    required this.member,
    required this.bill,
    required this.bankAccount,
    required this.paymentCode,
    required this.onPaymentReported,
  });

  final SessionMember member;
  final SessionBill bill;
  final VietQrBankAccount bankAccount;
  final VietQrPaymentCode paymentCode;
  final VoidCallback onPaymentReported;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      title: Text('VietQR · ${member.displayName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatVnd(bill.totalAmountVnd),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _BillLine(label: 'Tiền sân', amountVnd: bill.courtShareVnd),
            _BillLine(label: 'Tiền cầu', amountVnd: bill.shuttleShareVnd),
            _BillLine(label: 'Phạt trễ', amountVnd: bill.lateFeeVnd),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: QrImageView(
                  data: paymentCode.payload,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  semanticsLabel: 'Mã VietQR của ${member.displayName}',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Nội dung chuyển khoản: ${paymentCode.transferMemo}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${bankAccount.bankName.isEmpty ? '' : '${bankAccount.bankName} · '}'
              '${bankAccount.accountName} · ${bankAccount.accountNumber}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _copyAccountNumber(context),
          icon: const Icon(Icons.copy),
          label: const Text('Copy số tài khoản'),
        ),
        FilledButton(
          onPressed: member.paymentStatus == SessionPaymentStatus.approved
              ? null
              : () {
                  onPaymentReported();
                  Navigator.of(context).pop();
                },
          child: const Text('Đã chuyển khoản'),
        ),
      ],
    );
  }

  Future<void> _copyAccountNumber(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: bankAccount.accountNumber));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Đã copy số tài khoản.')),
        );
    } on PlatformException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể copy số tài khoản.')),
      );
    }
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({required this.label, required this.amountVnd});

  final String label;
  final int amountVnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(formatVnd(amountVnd)),
        ],
      ),
    );
  }
}
