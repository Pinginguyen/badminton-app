import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:club_squad_app/core/storage/vietqr_settings_store.dart';
import 'package:club_squad_app\services\vietqr_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and restores bank details without a backend', () async {
    const account = VietQrBankAccount(
      bankBin: '970436',
      bankName: 'Test Bank',
      accountNumber: '0123456789',
      accountName: 'CLUB ACCOUNT',
    );
    final store = VietQrSettingsStore();

    await store.save(account);
    final restored = await store.load();

    expect(restored?.bankBin, account.bankBin);
    expect(restored?.bankName, account.bankName);
    expect(restored?.accountNumber, account.accountNumber);
    expect(restored?.accountName, account.accountName);
  });

  test('rejects incomplete bank details', () async {
    await expectLater(
      VietQrSettingsStore().save(
        const VietQrBankAccount(
          bankBin: '9704',
          bankName: '',
          accountNumber: '123',
          accountName: '',
        ),
      ),
      throwsArgumentError,
    );
  });
}