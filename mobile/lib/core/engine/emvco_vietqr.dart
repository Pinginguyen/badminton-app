import 'dart:convert';

class EmvcoVietQr {
  const EmvcoVietQr._();

  static const _vietQrAid = 'A000000727';
  static const _bankTransferToAccount = 'QRIBFTTA';
  static const _maxAmount = 9999999999999;

  static String buildPayload({
    required String bankBin,
    required String accountNumber,
    required int amount,
    required String memo,
  }) {
    _validateBankBin(bankBin);
    _validateAccountNumber(accountNumber);
    _validateAmount(amount);
    _validateMemo(memo);

    final bankAccountTemplate = _tlv('00', bankBin) +
        _tlv('01', accountNumber) +
        _tlv('02', _bankTransferToAccount);
    final merchantAccountInformation =
        _tlv('00', _vietQrAid) + _tlv('01', bankAccountTemplate);
    final additionalData = _tlv('08', memo.trim());

    final payloadWithoutCrc = '000201'
        '010212'
        '${_tlv('38', merchantAccountInformation)}'
        '52040000'
        '5303704'
        '${_tlv('54', amount.toString())}'
        '5802VN'
        '${_tlv('62', additionalData)}'
        '6304';
    final crc = crc16CcittFalse(utf8.encode(payloadWithoutCrc));
    return '$payloadWithoutCrc${crc.toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }

  static int crc16CcittFalse(List<int> bytes) {
    var crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }

  static String _tlv(String tag, String value) {
    final byteLength = utf8.encode(value).length;
    if (byteLength > 99) {
      throw ArgumentError.value(value, 'value', 'TLV value exceeds 99 bytes.');
    }
    return '$tag${byteLength.toString().padLeft(2, '0')}$value';
  }

  static void _validateBankBin(String bankBin) {
    if (!RegExp(r'^\d{6}$').hasMatch(bankBin)) {
      throw ArgumentError.value(bankBin, 'bankBin', 'Must be a six-digit BIN.');
    }
  }

  static void _validateAccountNumber(String accountNumber) {
    if (!RegExp(r'^[A-Za-z0-9]{6,32}$').hasMatch(accountNumber)) {
      throw ArgumentError.value(
        accountNumber,
        'accountNumber',
        'Must be 6-32 letters or digits.',
      );
    }
  }

  static void _validateAmount(int amount) {
    if (amount < 1 || amount > _maxAmount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Must be between 1 and $_maxAmount VND.',
      );
    }
  }

  static void _validateMemo(String memo) {
    final normalizedMemo = memo.trim();
    if (normalizedMemo.isEmpty) {
      throw ArgumentError.value(memo, 'memo', 'Must not be empty.');
    }
    if (normalizedMemo.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
      throw ArgumentError.value(memo, 'memo', 'Must not contain control characters.');
    }
    if (utf8.encode(normalizedMemo).length > 95) {
      throw ArgumentError.value(
        memo,
        'memo',
        'Must not exceed 95 UTF-8 bytes.',
      );
    }
  }
}
