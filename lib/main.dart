import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

class DoorModel {
  Uint8List secret;
  Uint8List share1;

  DoorModel({required this.secret, required this.share1});
}

class DoorsModel extends ChangeNotifier {
  final Map<String, DoorModel> _map = {};
  String currentDoorName = "";
  int seed;
  DateTime lastRefreshTime;

  DoorsModel()
      : seed = DateTime.now().millisecondsSinceEpoch,
        lastRefreshTime = DateTime.now();

  void setDoor(String doorName, DoorModel door) {
    _map[doorName] = door;
    notifyListeners();
  }

  DoorModel query(String doorName) {
    return _map[doorName]!;
  }

  void setCurrentDoorName(String doorName) {
    currentDoorName = doorName;
    notifyListeners();
  }

  void setSeed(int seed) {
    this.seed = seed;
    lastRefreshTime = DateTime.now();
    notifyListeners();
  }
}

Future<Uint8List> loadDataFromAsset(String location) async {
  final data = await rootBundle.load(location);
  final buffer = img
      .decodeImage(data.buffer.asUint8List())!
      .getBytes(format: img.Format.luminance)
      .map((e) => e == 0 ? 0 : 1)
      .toList();
  return Uint8List.fromList(buffer);
}

Future<DoorModel> loadDoor(
  String secretLocation,
  String share1Location,
) async {
  final secret = await loadDataFromAsset(secretLocation);
  final share1 = await loadDataFromAsset(share1Location);

  return DoorModel(
    secret: secret,
    share1: share1,
  );
}

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    final doors = ['door1', 'door2'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
      ),
      body: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Door: '),
                DropdownButton(
                  value: context.watch<DoorsModel>().currentDoorName,
                  items: doors
                      .map((String doorName) => DropdownMenuItem(
                          value: doorName, child: Text(doorName)))
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      debugPrint(newValue);
                      context.read<DoorsModel>().setCurrentDoorName(newValue);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final door1 = await loadDoor(
    'assets/images/door1/door1_secret.png',
    'assets/images/door1/door1_share1.png',
  );
  final door2 = await loadDoor(
    'assets/images/door2/door2_secret.png',
    'assets/images/door2/door2_share1.png',
  );
  final doors = DoorsModel();
  doors.setDoor('door1', door1);
  doors.setDoor('door2', door2);

  doors.setCurrentDoorName('door1');

  runApp(
    ChangeNotifierProvider.value(
      value: doors,
      child: const MyApp(),
    ),
  );
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
    facing: CameraFacing.front,
    formats: [BarcodeFormat.qrCode],
  );
  Color topBarColor = Colors.red;
  DateTime currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        currentTime = DateTime.now();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    int seed = context.watch<DoorsModel>().seed;
    String currentDoorName = context.watch<DoorsModel>().currentDoorName;
    final lastRefreshTime = context.watch<DoorsModel>().lastRefreshTime;
    final remainingTime =
        lastRefreshTime.add(const Duration(minutes: 1)).difference(currentTime);
    if (remainingTime.isNegative) {
      context.read<DoorsModel>().setSeed(DateTime.now().millisecondsSinceEpoch);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: topBarColor,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Setting()),
              );
            },
            icon: const Icon(Icons.settings),
          )
        ],
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
                  handleQrCode(
                    code,
                    seed,
                    context.read<DoorsModel>().query(currentDoorName),
                  );
                }
              },
            ),
          ),
          Flexible(
            child: Column(
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: Center(
                    child: generateQrCode(
                      currentDoorName,
                      seed,
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Refresh in '),
                          Text(remainingTime.inSeconds.toString()),
                          const Text(' sec'),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<DoorsModel>()
                              .setSeed(DateTime.now().millisecondsSinceEpoch);
                        },
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget generateQrCode(String doorName, int seed) {
    debugPrint('seed is $seed');
    return QrImage(
      data: 'd=$doorName&s=$seed',
      version: QrVersions.auto,
    );
  }

  void handleQrCode(String data, int seed, DoorModel door) {
    debugPrint(data);
    final buffer = base64Decode(data);
    if (buffer.length * 8 != door.share1.length) {
      return;
    }

    Random rng = Random(seed);

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

    Uint8List overlapped = Uint8List(door.share1.length);
    for (int i = 0; i < door.share1.length; i++) {
      overlapped[i] = buffer2[i] & door.share1[i];
    }

    if (validateSecret(overlapped, door)) {
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

  bool validateSecret(Uint8List overlapped, DoorModel door) {
    for (int i = 0; i < 20; i++) {
      for (int j = 0; j < 20; j++) {
        int count = 0;
        count += overlapped[i * 2 * 40 + j * 2];
        count += overlapped[i * 2 * 40 + j * 2 + 1];
        count += overlapped[(i * 2 + 1) * 40 + j * 2];
        count += overlapped[(i * 2 + 1) * 40 + j * 2 + 1];

        // debugPrint('$i, $j, $count ${door.secret[i * 20 + j]}');
        assert(count == 0 || count == 1);

        if (door.secret[i * 20 + j] == 0) {
          if (count != 0) return false;
        } else {
          if (count != 1) return false;
        }
      }
    }
    return true;
  }
}
