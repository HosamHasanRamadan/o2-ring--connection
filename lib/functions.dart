import 'dart:typed_data';

import 'package:flutter/material.dart';

///  https://pub.dev/packages/flutter_reactive_ble
/// https://pub.dev/packages/flutter_nearby_connections
/// https://pub.dev/packages/flutter_ble_peripheral
/// https://pub.dev/packages/bluetooth_low_energy
/// https://pub.dev/packages/nearby_service
/// https://pub.dev/packages/flutter_blue_plus
/// https://pub.dev/packages/universal_ble
///
/*
Only 1 service is used, UUID: 14839ac4-7d7e-415c-9a42-167340cf2339
And 2 characteristics, 1 for read and 1 for write.
Read Characteristic UUID: 0734594A-A8E7-4B1A-A6B1-CD5243059A57
Write Characteristic UUID: 8B00ACE7-EB0B-49B0-BBE9-9AEE0A26E1A3

I/flutter (10069): 8b00ace7-eb0b-49b0-bbe9-9aee0a26e1a3
I/flutter (10069): 0734594a-a8e7-4b1a-a6b1-cd5243059a57

D6:7D:87:A8:69:4F
data should be sent in chunks of 40 * 0xZZ bytes
*/

const serviceUUID = '14839ac4-7d7e-415c-9a42-167340cf2339';

const readCharacteristicUuid = '0734594A-A8E7-4B1A-A6B1-CD5243059A57';
const writeCharacteristicUuid = '8B00ACE7-EB0B-49B0-BBE9-9AEE0A26E1A3';

const waveformCommand = [0xAA, 0x1B, 0xE4, 0x00, 0x00, 0x01, 0x00, 0x00, 0x5E];
const ringDataCommand = [0xAA, 0x17, 0xE8, 0x00, 0x00, 0x01, 0x00, 0x00, 0x1B];
const deviceInfoCommand = [0xaa, 0x14, 0xeb, 0x00, 0x00, 0x00, 0x00, 0xc6];

int flippingBits(int n, [int maskSizeInBits = 4]) {
  final numberInBits = n.toRadixString(2).padLeft(32, '0');
  var flippedBits = '';
  for (final bit in numberInBits.characters) {
    if (bit.isZero) flippedBits = '${flippedBits}1';
    if (bit.isOne) flippedBits = '${flippedBits}0';
  }

  final flippedValue = int.parse(flippedBits, radix: 2);

  var hexMaskText = '';
  for (int index = 0; index < numberInBits.characters.length; index++) {
    if (index < maskSizeInBits) {
      hexMaskText = '1$hexMaskText';
      continue;
    }
    hexMaskText = '0$hexMaskText';
  }
  final maskValue = int.parse(hexMaskText, radix: 2);
  return flippedValue & maskValue;
}

int crc8(Uint8List data, [int polynomial = 0x07]) {
  int crc = 0x00;
  for (int byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 0x80) != 0 ? (crc << 1) ^ polynomial : crc << 1;
    }
  }
  return crc & 0xff;
}

bool validateCRC8(Iterable<int> payload) {
  final immutablePayload = [...payload];
  final packetCRC8 = immutablePayload.last;
  immutablePayload.removeLast();
  final result = crc8(Uint8List.fromList(immutablePayload));
  print('$result - $packetCRC8');
  return result == packetCRC8;
}

extension on String {
  bool get isZero => this == '0';
  bool get isOne => this == '1';
}
