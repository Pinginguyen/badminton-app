import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:club_squad_app/core/engine/emvco_vietqr.dart';

void main() {
  test('CRC-16/CCITT-FALSE matches the standard check value', () {
    expect(
      EmvcoVietQr.crc16CcittFalse(utf8.encode('123456789')),
      0x29B1,
    );
  });

  test('builds a dynamic VietQR payload with a valid CRC field', () {
    final payload = EmvcoVietQr.buildPayload(
      bankBin: '970436',
      accountNumber: '0123456789',
      amount: 125000,
      memo: 'CLB buoi cau long',
    );

    expect(payload, startsWith('000201010212'));
    expect(payload, contains('5303704'));
    expect(payload, contains('5406125000'));
    expect(payload, endsWith('6304${_crcSuffix(payload)}'));
  });

  test('counts UTF-8 bytes for a Vietnamese memo TLV', () {
    final payload = EmvcoVietQr.buildPayload(
      bankBin: '970436',
      accountNumber: '0123456789',
      amount: 10000,
      memo: 'Cầu',
    );

    expect(payload, contains('62080804Cầu'));
  });

  test('rejects invalid bank BINs and amounts', () {
    expect(
      () => EmvcoVietQr.buildPayload(
        bankBin: '9704',
        accountNumber: '0123456789',
        amount: 10000,
        memo: 'CLB test',
      ),
      throwsArgumentError,
    );
    expect(
      () => EmvcoVietQr.buildPayload(
        bankBin: '970436',
        accountNumber: '0123456789',
        amount: 0,
        memo: 'CLB test',
      ),
      throwsArgumentError,
    );
  });
}

String _crcSuffix(String payload) {
  final crcInput = payload.substring(0, payload.length - 4);
  final crc = EmvcoVietQr.crc16CcittFalse(utf8.encode(crcInput));
  return crc.toRadixString(16).padLeft(4, '0').toUpperCase();
}
