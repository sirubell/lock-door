import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Door'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final cameraController = MobileScannerController(
    // facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );
  Uint8List secret = Uint8List(0);
  Uint8List share1 = Uint8List(0);
  Color topBarColor = Colors.red;
  Widget qrcode = const SizedBox.shrink();
  int _seed = 0;

  @override
  void initState() {
    super.initState();

    rootBundle.load('assets/images/secret.png').then((data) {
      final buffer = img
          .decodeImage(data.buffer.asUint8List())!
          .getBytes(format: img.Format.luminance)
          .map((e) => e == 0 ? 1 : 0)
          .toList();

      setState(() {
        secret = Uint8List.fromList(buffer);
      });
    });
    rootBundle.load('assets/images/share1.png').then((data) {
      final buffer = img
          .decodeImage(data.buffer.asUint8List())!
          .getBytes(format: img.Format.luminance)
          .map((e) => e == 0 ? 1 : 0)
          .toList();

      setState(() {
        share1 = Uint8List.fromList(buffer);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: topBarColor,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: MobileScanner(
              allowDuplicates: false,
              controller: cameraController,
              onDetect: (barcode, args) {
                if (barcode.rawValue == null) {
                  debugPrint('Failed to scan Barcode');
                } else {
                  final String code = barcode.rawValue!;
                  handleQrCode(code);
                }
              },
            ),
          ),
          Flexible(
            child: Column(
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: Center(child: qrcode),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          qrcode = generateQrCode();
                        });
                      },
                      child: const Text('Refresh'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget generateQrCode() {
    DateTime time = DateTime.now();
    int seed = time.millisecondsSinceEpoch;
    setState(() {
      _seed = seed;
    });

    debugPrint('seed is $seed');
    return QrImage(
      data: 'door=door1&seed=$seed',
      version: QrVersions.auto,
    );
  }

  void handleQrCode(String data) {
    debugPrint(data);
    var buffer = base64Decode(data);
    if (buffer.length * 8 != share1.length) {
      return;
    }

    Random rng = Random(_seed);

    final buffer2 = buffer
        .map((e) => e ^ rng.nextInt(256))
        .map(
          (e) {
            final tmp = List.filled(8, 0);
            for (int i = 0; i < 8; i++) {
              tmp[i] = (e >> i) & 1;
            }
            return tmp;
          },
        )
        .expand((e) => e)
        .toList();

    Uint8List overlapped = Uint8List(share1.length);
    for (int i = 0; i < share1.length; i++) {
      overlapped[i] = buffer2[i] | share1[i];
    }

    if (validSecret(overlapped)) {
      debugPrint('Unlock!!!!!!!!!!!!!!!!!!!');
      setState(() {
        topBarColor = Colors.green;
        Timer(const Duration(seconds: 5), () {
          setState(() {
            topBarColor = Colors.red;
          });
        });
      });
    } else {
      debugPrint(';;;;;;;;;;;;;;;;;;;;;;;;;');
    }
  }

  bool validSecret(Uint8List overlapped) {
    for (int i = 0; i < 20; i++) {
      for (int j = 0; j < 20; j++) {
        int count = 0;
        count += overlapped[i * 2 * 40 + j * 2];
        count += overlapped[i * 2 * 40 + j * 2 + 1];
        count += overlapped[(i * 2 + 1) * 40 + j * 2];
        count += overlapped[(i * 2 + 1) * 40 + j * 2 + 1];

        assert(count == 3 || count == 4);

        if (secret[i * 20 + j] == 0) {
          if (count != 4) return false;
        } else {
          if (count != 3) return false;
        }
      }
    }
    return true;
  }
}
