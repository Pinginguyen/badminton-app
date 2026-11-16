import 'package:shared_preferences/shared_preferences.dart';

import '../../services/vietqr_service.dart';

class VietQrSettingsStore {
  static const _bankBinKey = 'vietqr.bank_bin.v1';
  static const _bankNameKey = 'vietqr.bank_name.v1';
  static const _accountNumberKey = 'vietqr.account_number.v1';
  static const _accountNameKey = 'vietqr.account_name.v1';

  Future<VietQrBankAccount?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final bankBin = preferences.getString(_bankBinKey)?.trim() ?? '';
    final bankName = preferences.getString(_bankNameKey)?.trim() ?? '';
    final accountNumber =
        preferences.getString(_accountNumberKey)?.trim() ?? '';
    final accountName = preferences.getString(_accountNameKey)?.trim() ?? '';
    if (bankBin.isEmpty &&
        bankName.isEmpty &&
        accountNumber.isEmpty &&
        accountName.isEmpty) {
      return null;
    }
    if (!_isValid(bankBin, bankName, accountNumber, accountName)) return null;
    return VietQrBankAccount(
      bankBin: bankBin,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  Future<void> save(VietQrBankAccount account) async {
    final bankBin = account.bankBin.trim();
    final bankName = account.bankName.trim();
    final accountNumber = account.accountNumber.trim();
    final accountName = account.accountName.trim();
    if (!_isValid(bankBin, bankName, accountNumber, accountName)) {
      throw ArgumentError('Thông tin tài khoản VietQR không hợp lệ.');
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = await Future.wait([
      preferences.setString(_bankBinKey, bankBin),
      preferences.setString(_bankNameKey, bankName),
      preferences.setString(_accountNumberKey, accountNumber),
      preferences.setString(_accountNameKey, accountName),
    ]);
    if (saved.any((success) => !success)) {
      throw StateError('Không thể lưu cấu hình VietQR trên thiết bị.');
    }
  }

  static bool _isValid(
    String bankBin,
    String bankName,
    String accountNumber,
    String accountName,
  ) {
    return RegExp(r'^\d{6}$').hasMatch(bankBin) &&
        bankName.isNotEmpty &&
        RegExp(r'^[A-Za-z0-9]{6,32}$').hasMatch(accountNumber) &&
        accountName.isNotEmpty;
  }
}