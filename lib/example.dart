import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:universal_ble/universal_ble.dart';

// 244 bytes

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  final List<BleScanResult> foundDevices = [];

  BleScanResult? connectedDevice;
  final result = <Uint8List>[];
  String textResult = '';
  @override
  void initState() {
    super.initState();

    UniversalBle.onScanResult = (scanResult) {
      log(scanResult.name ?? scanResult.deviceId);

      if (foundDevices.map((e) => e.deviceId).contains(scanResult.deviceId)) {
        return;
      }
      if (scanResult.name == null) return;
      foundDevices.add(scanResult);
      setState(() {});
    };
    UniversalBle.onAvailabilityChange = (state) {
      print(state.name);
    };
    UniversalBle.onValueChanged = (
      String deviceId,
      String characteristicId,
      Uint8List value,
    ) {
      result.add(value);
    };

    UniversalBle.onConnectionChanged =
        (String deviceId, BleConnectionState state) {
      print('$deviceId -- $state');
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        child: Scaffold(
          body: Column(
            children: [
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
                      if (connectedDevice != null) {
                        UniversalBle.disconnect(connectedDevice!.deviceId)
                            .then((value) {
                          connectedDevice = null;
                          foundDevices.clear();
                          textResult = '';
                          setState(() {});
                        });
                      }
                    },
                    child: Text('Disconnect'),
                  ),
                  TextButton(
                    onPressed: setNotifying,
                    child: const Text('Notifying'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (connectedDevice != null) {
                        await UniversalBle.discoverServices(
                          connectedDevice!.deviceId,
                        );
                      }
                    },
                    child: Text('Discover Services'),
                  ),
                  TextButton(
                    onPressed: write,
                    child: Text('Write'),
                  ),
                ],
              ),
              Text(
                'Result:\n$textResult',
                textAlign: TextAlign.center,
              ),
              Text('Scan Result'),
              Expanded(
                child: ListView(
                  children: [
                    ...foundDevices.map(
                          (value) {
                            return ListTile(
                              onTap: () {
                                UniversalBle.connect(value.deviceId);

                                connectedDevice = value;
                              },
                              title: Text('${value.name}'),
                            );
                          },
                        ) ??
                        [],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void setNotifying() {
    final readCharacteristicUuid = '';
    final serviceUuid = '';

    if (connectedDevice != null) {
      UniversalBle.setNotifiable(
        connectedDevice!.deviceId,
        serviceUuid,
        readCharacteristicUuid,
        BleInputProperty.notification,
      );
    }
  }

  Future<void> write() async {
    final writeCharacteristicUuid = '';
    final serviceUuid = '';
    final command = Uint8List.fromList([]);

    if (connectedDevice != null) {
      UniversalBle.writeValue(
        connectedDevice!.deviceId,
        serviceUuid,
        writeCharacteristicUuid,
        command,
        BleOutputProperty.withoutResponse,
      );
    }
  }
}
