import '../core/engine/emvco_vietqr.dart';

/// Builds local EMVCo VietQR payloads rendered by qr_flutter.
class VietQrBankAccount {
  const VietQrBankAccount({
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
    this.bankName = '',
  });

  /// Six-digit VietQR/NAPAS bank BIN (for example, configured by the admin).
  final String bankBin;
  final String accountNumber;
  final String accountName;
  final String bankName;
}

class VietQrPaymentCode {
  const VietQrPaymentCode({
    required this.amountVnd,
    required this.transferMemo,
    required this.payload,
  });

  final int amountVnd;
  final String transferMemo;
  final String payload;
}

class VietQrService {
  const VietQrService();

  /// Creates an EMVCo VietQR payload with the exact amount and transfer memo.
  VietQrPaymentCode createPaymentCode({
    required VietQrBankAccount bankAccount,
    required int amountVnd,
    required String sessionId,
    required String memberId,
  }) {
    _validateBankAccount(bankAccount);
    if (amountVnd <= 0) {
      throw ArgumentError.value(amountVnd, 'amountVnd', 'Must be positive VND');
    }
    if (!_isSafeIdentifier(sessionId) || !_isSafeIdentifier(memberId)) {
      throw ArgumentError('Session and member IDs must be non-empty URL-safe IDs');
    }
    final memo = 'CLB_${sessionId}_${memberId}';
    final payload = EmvcoVietQr.buildPayload(
      bankBin: bankAccount.bankBin,
      accountNumber: bankAccount.accountNumber,
      amount: amountVnd,
      memo: memo,
    );
    return VietQrPaymentCode(
      amountVnd: amountVnd,
      transferMemo: memo,
      payload: payload,
    );
  }

  static void _validateBankAccount(VietQrBankAccount account) {
    if (!RegExp(r'^\d{6}$').hasMatch(account.bankBin)) {
      throw ArgumentError.value(account.bankBin, 'bankBin', 'Must be a six-digit BIN');
    }
    if (!RegExp(r'^[A-Za-z0-9]{6,32}$').hasMatch(account.accountNumber)) {
      throw ArgumentError.value(
        account.accountNumber,
        'accountNumber',
        'Must be 6–32 letters or digits',
      );
    }
    if (account.accountName.trim().isEmpty) {
      throw ArgumentError.value(account.accountName, 'accountName', 'Must not be empty');
    }
  }

  static bool _isSafeIdentifier(String value) =>
      RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value);
}
