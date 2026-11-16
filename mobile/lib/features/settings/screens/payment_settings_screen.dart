import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/vietqr_settings_store.dart';
import '../../../services/vietqr_service.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key, this.initialAccount});

  final VietQrBankAccount? initialAccount;

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _store = VietQrSettingsStore();
  late final TextEditingController _bankBinController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.initialAccount;
    _bankBinController = TextEditingController(text: account?.bankBin ?? '');
    _bankNameController = TextEditingController(text: account?.bankName ?? '');
    _accountNumberController =
        TextEditingController(text: account?.accountNumber ?? '');
    _accountNameController =
        TextEditingController(text: account?.accountName ?? '');
    if (account == null) _loadSavedAccount();
  }

  @override
  void dispose() {
    _bankBinController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccount() async {
    try {
      final account = await _store.load();
      if (!mounted || account == null) return;
      _bankBinController.text = account.bankBin;
      _bankNameController.text = account.bankName;
      _accountNumberController.text = account.accountNumber;
      _accountNameController.text = account.accountName;
    } catch (_) {
      if (mounted) _showMessage('Không thể đọc cấu hình đã lưu.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final account = VietQrBankAccount(
      bankBin: _bankBinController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      accountName: _accountNameController.text.trim(),
    );
    try {
      await _store.save(account);
      if (mounted) Navigator.of(context).pop(account);
    } on Exception catch (error) {
      if (mounted) _showMessage('Không thể lưu: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống.' : null;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt thanh toán')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _bankNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ngân hàng nhận tiền',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bankBinController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mã BIN VietQR (6 chữ số)',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) => value != null &&
                        RegExp(r'^\d{6}$').hasMatch(value.trim())
                    ? null
                    : 'Nhập đúng mã BIN 6 chữ số của ngân hàng.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Số tài khoản',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                validator: (value) => value != null &&
                        RegExp(r'^[A-Za-z0-9]{6,32}$')
                            .hasMatch(value.trim())
                    ? null
                    : 'Số tài khoản phải có 6-32 chữ hoặc số.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _accountNameController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Tên chủ tài khoản',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _required,
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Đang lưu...' : 'Lưu trên thiết bị'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}