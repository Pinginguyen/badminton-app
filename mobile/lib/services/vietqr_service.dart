/// Builds dynamic VietQR image URLs without an additional Dart package.
///
/// The returned image URL is rendered by VietQR's image service. Keep the
/// recipient bank details in admin-managed configuration, never source code.
class VietQrBankAccount {
  const VietQrBankAccount({
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
  });

  /// Six-digit VietQR/NAPAS bank BIN (for example, configured by the admin).
  final String bankBin;
  final String accountNumber;
  final String accountName;
}

class VietQrPaymentCode {
  const VietQrPaymentCode({
    required this.amountVnd,
    required this.transferMemo,
    required this.imageUri,
  });

  final int amountVnd;
  final String transferMemo;
  final Uri imageUri;
}

class VietQrService {
  const VietQrService({this.template = 'compact2'});

  static const _allowedTemplates = {
    'compact',
    'compact2',
    'qr_only',
    'print',
  };

  final String template;

  /// Creates a VietQR image URL containing the exact bill amount and required
  /// `CLB_{sessionId}_{memberId}` transfer memo. This method is synchronous
  /// and does not install dependencies or perform a network request.
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
    if (!_allowedTemplates.contains(template)) {
      throw ArgumentError.value(template, 'template', 'Unsupported VietQR template');
    }

    final memo = 'CLB_${sessionId}_${memberId}';
    final uri = Uri.https(
      'img.vietqr.io',
      '/image/${bankAccount.bankBin}-${bankAccount.accountNumber}-$template.png',
      {
        'amount': amountVnd.toString(),
        'addInfo': memo,
        'accountName': bankAccount.accountName.trim(),
      },
    );
    return VietQrPaymentCode(
      amountVnd: amountVnd,
      transferMemo: memo,
      imageUri: uri,
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
