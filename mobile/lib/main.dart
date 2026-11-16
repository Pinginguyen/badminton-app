import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/mobile_frame.dart';
import 'features/home/screens/home_dashboard_screen.dart';
import 'services/vietqr_service.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _vietQrBankBin = String.fromEnvironment('VIETQR_BANK_BIN');
const _vietQrAccountNumber = String.fromEnvironment('VIETQR_ACCOUNT_NUMBER');
const _vietQrAccountName = String.fromEnvironment('VIETQR_ACCOUNT_NAME');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');

  final supabaseConfigured =
      _supabaseUrl.trim().isNotEmpty && _supabaseAnonKey.trim().isNotEmpty;
  if (supabaseConfigured) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
    } catch (error) {
      debugPrint('Supabase initialization failed; continuing offline: $error');
    }
  }

  runApp(const ClubSquadApp());
}

class ClubSquadApp extends StatelessWidget {
  const ClubSquadApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bankAccount = _createBankAccount();

    return MaterialApp(
      title: 'Court Side',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      builder: (context, child) => MobileFrame(
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomeDashboardScreen(bankAccount: bankAccount),
    );
  }
}

VietQrBankAccount? _createBankAccount() {
  if (_vietQrBankBin.trim().isEmpty ||
      _vietQrAccountNumber.trim().isEmpty ||
      _vietQrAccountName.trim().isEmpty) {
    return null;
  }
  return VietQrBankAccount(
    bankBin: _vietQrBankBin.trim(),
    accountNumber: _vietQrAccountNumber.trim(),
    accountName: _vietQrAccountName.trim(),
  );
}

