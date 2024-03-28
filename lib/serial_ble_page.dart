import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:binarize/binarize.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:ring_flutter_sdk/functions.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

// 244 bytes

class BigHopes extends StatefulWidget {
  const BigHopes({super.key});

  @override
  State<BigHopes> createState() => _BigHopesState();
}

class _BigHopesState extends State<BigHopes> {
  final resultSignal = setSignal<BleScanResult>(
    {},
  );

  final connectedDevice = signal<BleScanResult?>(null);
  // final bluetoothChange = streamSignal(() => BluetoothManager.instance.state);
  final result = <Uint8List>[];
  String textResult = '';
  @override
  void initState() {
    super.initState();

    UniversalBle.queuesCommands = true;
    UniversalBle.onScanResult = (scanResult) {
      log(scanResult.name ?? scanResult.deviceId);

      if (resultSignal.value
          .map((e) => e.deviceId)
          .contains(scanResult.deviceId)) return;
      if (scanResult.name == null) return;
      resultSignal.add(scanResult);
    };
    UniversalBle.onAvailabilityChange = (state) {
      log(state.name);
    };
    UniversalBle.onValueChanged =
        (String deviceId, String characteristicId, Uint8List value) {
      // log('$deviceId -- $characteristicId');
      print(value.map((e) => e.toRadixString(16)));
      result.add(value);
      // print(UniversalBle.readValue(
      //   deviceId,
      //   serviceUUID,
      //   readCharacteristicUuid,
      // ));
    };

    UniversalBle.onConnectionChanged =
        (String deviceId, BleConnectionState state) {
      log('$deviceId -- $state');
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        child: Scaffold(
          body: Column(
            children: [
              Watch((context) {
                return Text("No State");
              }),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () async {
                      UniversalBle.startScan();
                    },
                    child: Text('Scan'),
                  ),
                  TextButton(
                    onPressed: () async {
                      UniversalBle.stopScan();
                    },
                    child: Text('Stop'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (connectedDevice() != null) {
                        UniversalBle.disconnect(connectedDevice()!.deviceId)
                            .then((value) {
                          connectedDevice.value = null;
                          resultSignal.clear();
                          textResult = '';
                        });
                      }
                    },
                    child: Text('disconnect'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (connectedDevice() != null) {
                        UniversalBle.setNotifiable(
                          connectedDevice()!.deviceId,
                          serviceUUID,
                          readCharacteristicUuid,
                          BleInputProperty.notification,
                        );
                      }
                    },
                    child: Text('Notifying'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (connectedDevice() != null) {
                        setSettings();
                      }
                    },
                    child: Text('Settings'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (connectedDevice() != null) {
                        await UniversalBle.discoverServices(
                          connectedDevice()!.deviceId,
                        );
                      }
                    },
                    child: Text('Discover Services'),
                  ),
                  TextButton(
                    onPressed: readDeviceInfo,
                    child: Text('Data'),
                  ),
                  TextButton(
                    onPressed: getRingData,
                    child: Text('Ring Data'),
                  ),
                  TextButton(
                    onPressed: getWaveForm,
                    child: const Text('Waveform'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (connectedDevice() != null) {
                        final id = connectedDevice()!.deviceId;
                        final chars = await UniversalBle.discoverServices(
                          id,
                        );
                        chars.forEach((a) {
                          a.characteristics.forEach((b) {
                            print(b.properties);
                          });
                        });
                        return;
                        chars.forEach((service) {
                          print('Service: ${service.uuid}');
                          service.characteristics.forEach((char) {
                            print(char.uuid);

                            char.properties.forEach((prop) async {
                              if (prop == CharacteristicProperty.read) {
                                final result = await UniversalBle.readValue(
                                  id,
                                  service.uuid,
                                  char.uuid,
                                );
                                print('Result: ${result.map(
                                      (e) => e.toRadixString(16),
                                    ).join()}');
                              }
                              print('${prop.name} -- ${prop.value}');
                            });
                          });
                          print('-' * 20);
                        });
                      }
                    },
                    child: const Text('Read'),
                  ),
                ],
              ),
              Text(textResult),
              Expanded(
                child: Watch((context) {
                  final result = resultSignal();
                  return ListView(
                    children: [
                      ...resultSignal.value?.map(
                            (value) {
                              return ListTile(
                                onTap: () {
                                  UniversalBle.connect(value.deviceId);

                                  connectedDevice.value =
                                      resultSignal.value.first;
                                },
                                title: Text('${value.name}'),
                              );
                            },
                          ) ??
                          [],
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void readDeviceInfo() async {
    final deviceId = connectedDevice()!.deviceId;
    final service = serviceUUID;
    final char = writeCharacteristicUuid;

    const header = 0xaa;
    const readDeviceInfoCommand = 0x14;
    final negatedCommand = flippingBits(readDeviceInfoCommand, 8);
    final fillOrderPayload = Payload.write();
    fillOrderPayload.set(int8, header);
    fillOrderPayload.set(int8, readDeviceInfoCommand);
    fillOrderPayload.set(int8, negatedCommand);
    fillOrderPayload.set(int8, 0);
    fillOrderPayload.set(int8, 0);
    fillOrderPayload.set(int8, 0);
    fillOrderPayload.set(int8, 0);
    final crc = crc8(binarize(fillOrderPayload));
    fillOrderPayload.set(int8, crc);

    final deviceInfoFullCommand = binarize(fillOrderPayload);

    result.clear();

    UniversalBle.writeValue(
      deviceId,
      serviceUUID,
      writeCharacteristicUuid,
      deviceInfoFullCommand,
      BleOutputProperty.withoutResponse,
    );
    Future.delayed(const Duration(seconds: 1)).then((value) {
      textResult =
          result.map((e) => e.map((e) => e.toRadixString(16))).join('\n');
      setState(() {});
      // final aa = LinkedHashSet<Uint8List>(
      //   equals: (key1, key2) => listEquals(key1, key2),
      //   hashCode: (p0) => Object.hashAll(p0),
      // );
      print(result.length);
      result.forEach((element) {
        // aa.add(element);
      });

      final flattened = result.flattened;
      final isValidPacket = validateCRC8(flattened);

      final deserializedValue = utf8.decode(
        flattened
            .whereIndexed(
                (index, _) => index > 6 && index < flattened.length - 1)
            .toList(),
        allowMalformed: true,
      );

      if (isValidPacket) {
        print('Data could be invalid');
      }
      print(deserializedValue);

      print(result.length);

      result.clear();
    });
  }

  void setSettings() async {
    final settings = {
      "SetTIME": "2024-04-06,16:20:00",
      "SetOxiThr": "90",
      "SetMotor": "80",
      "SetPedtar": "1000"
    };
    final settingsEncoded = jsonEncode(settings);
    const header = 0xAA;
    const readDeviceInfoCommand = 0x16;
    final settingsBinaryData = utf8.encode(settingsEncoded);

    final dataLength = settingsBinaryData.length.toRadixString(2);
    final negatedCommand = flippingBits(readDeviceInfoCommand, 8);
    final payload = Payload.write();
    payload.set(int8, header);
    payload.set(int8, readDeviceInfoCommand);
    payload.set(int8, negatedCommand);
    // packet number 2 bytes
    payload.set(int8, 0);
    payload.set(int8, 0);
    // payload buff size
    // payload.set(int8, 0);
    // payload.set(int8, 0);
    payload.set(int16, (settingsBinaryData.length / 20).ceil());

    for (final chunk in settingsBinaryData) {
      payload.set(int8, chunk);
    }
    final crc = crc8(binarize(payload));
    payload.set(int8, crc);

    final fullCommand = binarize(payload);
    final chunks = fullCommand.slices(20);
    final readableChunks =
        fullCommand.map((e) => e.toRadixString(16)).slices(20);
    // print(chunks.join('\n'));
    textResult = readableChunks.join('\n');
    setState(() {});

    chunks.forEach((element) async {
      var payload = <int>[];
      if (element.length < 20) {
        payload = [...List.filled(20 - element.length, 0), ...element];
      } else {
        payload = element;
      }

      await UniversalBle.writeValue(
        connectedDevice()!.deviceId,
        serviceUUID,
        writeCharacteristicUuid,
        Uint8List.fromList(payload),
        BleOutputProperty.withoutResponse,
      );
      UniversalBle.getConnectedDevices();
      // await Future.delayed(Duration(milliseconds: 10));
    });

    // Future.delayed(Duration(seconds: 1)).then((value){
    //   result.clear();
    //         textResult =
    //       result.map((e) => e.map((e) => e.toRadixString(16))).join('\n');
    //   setState(() {});
    // });
  }

  Future<void> getRingData() async {
    const readDeviceInfoCommand = 0x17;

    const header = 0xAA;

    final negatedCommand = flippingBits(readDeviceInfoCommand, 8);

    final payload = Payload.write();
    payload.set(int8, header);
    payload.set(int8, readDeviceInfoCommand);
    payload.set(int8, negatedCommand);
    // packet number 2 bytes
    payload.set(int8, 0);
    payload.set(int8, 0);
    // payload buff size
    payload.set(int8, 0);
    payload.set(int8, 0);

    final crc = crc8(binarize(payload));
    payload.set(int8, crc);

    final fullCommand = binarize(payload);
    result.clear();
    UniversalBle.writeValue(
      connectedDevice()!.deviceId,
      serviceUUID,
      writeCharacteristicUuid,
      fullCommand,
      BleOutputProperty.withoutResponse,
    );
    Future.delayed(const Duration(seconds: 1)).then((value) {
      textResult =
          result.map((e) => e.map((e) => e.toRadixString(16))).join('\n');
      setState(() {});
    });
  }

  Future<void> getWaveForm() async {
    const readDeviceInfoCommand = 0x1B;

    const header = 0xAA;

    final negatedCommand = flippingBits(readDeviceInfoCommand, 8);

    final payload = Payload.write();
    payload.set(int8, header);
    payload.set(int8, readDeviceInfoCommand);
    payload.set(int8, negatedCommand);
    // packet number 2 bytes
    payload.set(int8, 0);
    payload.set(int8, 0);
    // payload buff size
    payload.set(int8, 0);
    payload.set(int8, 1);
    // sample rate
    payload.set(int8, 0);

    final crc = crc8(binarize(payload));
    payload.set(int8, crc);

    // final fullCommand = binarize(payload);
    final fullCommand = Uint8List.fromList(
        [0xaa, 0x1b, 0xe4, 0x00, 0x00, 0x01, 0x00, 0x00, 0x5e]);

    result.clear();

    UniversalBle.writeValue(
      connectedDevice()!.deviceId,
      serviceUUID,
      writeCharacteristicUuid,
      fullCommand,
      BleOutputProperty.withoutResponse,
    );

    Future.delayed(const Duration(seconds: 1)).then((value) {
      textResult =
          result.map((e) => e.map((e) => e.toRadixString(16))).join('\n');
      setState(() {});
    });
  }
}
