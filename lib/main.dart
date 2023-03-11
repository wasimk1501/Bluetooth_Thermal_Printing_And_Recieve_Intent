import 'dart:io';
import 'dart:typed_data';
import 'dart:developer';
import 'dart:async';
import 'package:advance_pdf_viewer/advance_pdf_viewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:image/image.dart' as Imag;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ImagePicker _picker = ImagePicker();
  StreamSubscription? _intentDataStreamSubscription;
  List<SharedMediaFile>? _sharedFiles;
  String? _sharedText;
  File? imageFile;
  File? pdfFile;
  String _info = "";
  String _msj = '';
  bool connected = false;
  List<BluetoothInfo> items = [];
  final List<String> _options = [
    "permission bluetooth granted",
    "bluetooth enabled",
    "connection status",
    "update info"
  ];

  String _selectSize = "2";
  final _txtText = TextEditingController(text: "Hello developer");
  bool _connceting = false;

  @override
  void initState() {
    super.initState();
    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      setState(() {
        _sharedFiles?.map((f) {
          var b = f.path;
          setState(() {
            imageFile = File(b);
            log(imageFile.toString());
          });
        });

        print("Shared:" + (_sharedFiles?.map((f) => f.path)?.join(",") ?? ""));
        _sharedFiles = value;
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      setState(() {
        _sharedFiles?.map((f) {
          var c = f.path;
          setState(() {
            imageFile = File(c);
            log(imageFile.toString());
          });
        });
        _sharedFiles = value;
      });
    });

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() {
        _sharedText = value;
      });
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String? value) {
      setState(() {
        _sharedText = value;
      });
    });
    initPlatformState();
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth Thermal Printer'),
          centerTitle: true,
          actions: [
            PopupMenuButton(
              elevation: 3.2,
              //initialValue: _options[1],
              onCanceled: () {
                print('You have not chosed anything');
              },
              tooltip: 'Menu',
              onSelected: (Object select) async {
                String sel = select as String;
                print("selected: $sel");
                if (sel == "permission bluetooth granted") {
                  bool status =
                      await PrintBluetoothThermal.isPermissionBluetoothGranted;
                  setState(() {
                    _info = "permission bluetooth granted: $status";
                  });
                } else if (sel == "bluetooth enabled") {
                  bool state = await PrintBluetoothThermal.bluetoothEnabled;
                  setState(() {
                    _info = "Bluetooth enabled: $state";
                  });
                } else if (sel == "update info") {
                  initPlatformState();
                } else if (sel == "connection status") {
                  final bool result =
                      await PrintBluetoothThermal.connectionStatus;
                  setState(() {
                    _info = "connection status: $result";
                  });
                }
              },
              itemBuilder: (BuildContext context) {
                return _options.map((String option) {
                  return PopupMenuItem(
                    value: option,
                    child: Text(option),
                  );
                }).toList();
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('info: $_info\n '),
                Text(_msj),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        this.getBluetoots();
                      },
                      child: Row(
                        children: [
                          Visibility(
                            visible: _connceting,
                            child: const SizedBox(
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1,
                                  backgroundColor: Colors.white),
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(_connceting ? "Connecting" : "Search"),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: connected ? this.disconnect : null,
                      child: Text("Disconnect"),
                    ),
                    ElevatedButton(
                      onPressed: connected ? this.printTest : null,
                      child: Text("Test"),
                    ),
                  ],
                ),
                Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    child: ListView.builder(
                      itemCount: items.length > 0 ? items.length : 0,
                      itemBuilder: (context, index) {
                        return ListTile(
                          onTap: () {
                            String mac = items[index].macAdress;
                            this.connect(mac);
                          },
                          title: Text('Name: ${items[index].name}'),
                          subtitle:
                              Text("macAdress: ${items[index].macAdress}"),
                        );
                      },
                    )),
                SizedBox(
                  height: 10,
                ),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  child: Column(children: [
                    Text(
                        "Text size without the library without external packets, print images still it should not use a library"),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _txtText,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: "Text",
                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        DropdownButton<String>(
                          hint: Text('Size'),
                          value: _selectSize,
                          items: <String>['1', '2', '3', '4', '5']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? select) {
                            setState(() {
                              _selectSize = select.toString();
                            });
                          },
                        )
                      ],
                    ),
                    ElevatedButton(
                      onPressed: connected ? this.printWithoutPackage : null,
                      child: Text("Print"),
                    ),
                  ]),
                ),
                const SizedBox(
                  height: 10,
                ),
                OutlinedButton(
                  onPressed: connected ? printString : null,
                  child: Text("Print String"),
                ),
                ElevatedButton(
                  onPressed: connected ? printImage : null,
                  child: Text("Print Image"),
                ),
                ElevatedButton(
                  onPressed: connected ? pickImageAndPrint : null,
                  child: Text("Pick Image and Print"),
                ),
                ElevatedButton(
                  onPressed: connected ? pickPdfAndPrint : null,
                  child: Text("Pick Pdf and Print"),
                ),
                Container(
                  child: imageFile == null
                      ? Container(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              ElevatedButton(
                                onPressed: () {
                                  _getFromGallery();
                                },
                                child: const Text("PICK FROM GALLERY"),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          child: Image.file(
                            imageFile!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                Text(_sharedText ?? ""),
                Text(_sharedFiles
                        ?.map((f) =>
                            "{Path: ${f.path}, Type: ${f.type.toString().replaceFirst("SharedMediaType.", "")}}\n")
                        .join(",\n") ??
                    ""),
                /*OutlinedButton(
                  onPressed: conceted ? this.imprimirTextoPersonalizado : null,
                  child: Text("Imprimir texto personalizado"),
                ),
                OutlinedButton(
                  onPressed: conceted ? this.imprimirTesh : null,
                  child: Text("test"),
                ),
                OutlinedButton(
                  onPressed: this.getStatedBluetooth,
                  child: Text("stated bluetooth"),
                ),*/
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get from gallery
  _getFromGallery() async {
    PickedFile? pickedFile = await ImagePicker().getImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    int porcentbatery = 0;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await PrintBluetoothThermal.platformVersion;
      porcentbatery = await PrintBluetoothThermal.batteryLevel;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    final bool result = await PrintBluetoothThermal.bluetoothEnabled;
    //print("bluetooth enabled: $result");
    if (result) {
      _msj = "Bluetooth enabled, please search and connect";
    } else {
      _msj = "Bluetooth not enabled";
    }

    setState(() {
      _info = platformVersion + " ($porcentbatery% battery)";
    });
  }

  Future<void> getBluetoots() async {
    final List<BluetoothInfo> listResult =
        await PrintBluetoothThermal.pairedBluetooths;

    /*await Future.forEach(listResult, (BluetoothInfo bluetooth) {
      String name = bluetooth.name;
      String mac = bluetooth.macAdress;
    });*/

    if (listResult.length == 0) {
      _msj =
          "There are no bluetooth's linked, go to settings and link the printer";
    } else {
      _msj = "Touch an item in the list to connect";
    }

    setState(() {
      items = listResult;
    });
  }

  Future<void> connect(String mac) async {
    setState(() {
      _connceting = true;
    });
    final bool result =
        await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    print("state conected $result");
    if (result) connected = true;
    setState(() {
      _connceting = false;
    });
  }

  Future<void> disconnect() async {
    final bool status = await PrintBluetoothThermal.disconnect;
    setState(() {
      connected = false;
    });
    print("status disconnect $status");
  }

  Future<void> printTest() async {
    bool conexionStatus = await PrintBluetoothThermal.connectionStatus;
    if (conexionStatus) {
      List<int> ticket = await testTicket();
      final result = await PrintBluetoothThermal.writeBytes(ticket);
      print("impresion $result");
    } else {
      //no conectado, reconecte
    }
  }

  Future<void> printString() async {
    bool conexionStatus = await PrintBluetoothThermal.connectionStatus;
    if (conexionStatus) {
      String enter = '\n';
      await PrintBluetoothThermal.writeBytes(enter.codeUnits);
      //size of 1-5
      String text = "Hello";
      await PrintBluetoothThermal.writeString(
          printText: PrintTextSize(size: 1, text: _sharedText ?? text));
      await PrintBluetoothThermal.writeString(
          printText: PrintTextSize(size: 2, text: _sharedText ?? text));
      await PrintBluetoothThermal.writeString(
          printText: PrintTextSize(size: 3, text: _sharedText ?? text));
    } else {
      //desconectado
      print("desconectado bluetooth $conexionStatus");
    }
  }

  Future<void> printImage() async {
    bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      log("Bluetooth connection Status: $connectionStatus");
      List<int> bytes = [];
      // Using default profile
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      //bytes += generator.setGlobalFont(PosFontType.fontA);
      bytes += generator.reset();

      final ByteData data = await rootBundle.load("assets/profile.jfif");
      final Uint8List bytesImg = data.buffer.asUint8List();
      final image = Imag.decodeImage(bytesImg);

      bytes += generator.image(image!);
      await PrintBluetoothThermal.writeBytes(bytes);
    }
    log("Bluetooth connection Status: $connectionStatus");
  }

  Future<void> pickImageAndPrint() async {
    if (_sharedFiles == null) {
      await _getFromGallery();
    }

    bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      log("Bluetooth connection Status: $connectionStatus");
      // final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      List<int> bytes = [];
      // Using default profile
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      //bytes += generator.setGlobalFont(PosFontType.fontA);
      bytes += generator.reset();
// Uint8List bytes = await imageFile.readAsBytes();
//       final ByteData data = await imageFile.readAsBytes();
      // final Uint8List bytesImg = data.buffer.asUint8List();

      final Uint8List bytesImg = await imageFile!.readAsBytes();
      // final Uint8List bytesImg = await imageFile!.readAsBytes();
      final image1 = Imag.decodeImage(bytesImg);

      bytes += generator.image(image1!);
      await PrintBluetoothThermal.writeBytes(bytes);
    }
  }

  Future<void> pickPdfAndPrint() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        pdfFile = File(result.files.first.path!);
        print(pdfFile);
      });
    }
    bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      log("Bluetooth connection Status: $connectionStatus");
      // final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      List<int> bytes = [];
      // Using default profile
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      //bytes += generator.setGlobalFont(PosFontType.fontA);
      bytes += generator.reset();
      final pdfBytes = await pdfFile!.readAsBytes();
      final Uint8List bytesImg = pdfFile!.readAsBytesSync();

      final pdf = Imag.decodeImage(bytesImg);

      bytes += generator.image(pdf!);
      await PrintBluetoothThermal.writeBytes(bytes);
    }

// // Uint8List bytes = await imageFile.readAsBytes();
// //       final ByteData data = await imageFile.readAsBytes();
//       // final Uint8List bytesImg = data.buffer.asUint8List();
//       final Uint8List bytesImg = await pdfFile!.readAsBytes();
//       final pdf = Imag.decodeImage(bytesImg);

//       bytes += generator.image(pdf!);
//       await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<List<int>> testTicket() async {
    List<int> bytes = [];
    // Using default profile
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    //bytes += generator.setGlobalFont(PosFontType.fontA);
    bytes += generator.reset();

    final ByteData data = await rootBundle.load('assets/mylogo.jpg');
    final Uint8List bytesImg = data.buffer.asUint8List();
    final image = Imag.decodeImage(bytesImg);
    // Using `ESC *`
    bytes += generator.image(image!);

    bytes += generator.text(
        'Regular: aA bB cC dD eE fF gG hH iI jJ kK lL mM nN oO pP qQ rR sS tT uU vV wW xX yY zZ',
        styles: PosStyles());
    bytes += generator.text('Special 1: ñÑ àÀ èÈ éÉ üÜ çÇ ôÔ',
        styles: PosStyles(codeTable: 'CP1252'));
    bytes += generator.text(
      'Special 2: blåbærgrød',
      styles: PosStyles(codeTable: 'CP1252'),
    );

    bytes += generator.text('Bold text', styles: PosStyles(bold: true));
    bytes += generator.text('Reverse text', styles: PosStyles(reverse: true));
    bytes += generator.text('Underlined text',
        styles: PosStyles(underline: true), linesAfter: 1);
    bytes +=
        generator.text('Align left', styles: PosStyles(align: PosAlign.left));
    bytes += generator.text('Align center',
        styles: PosStyles(align: PosAlign.center));
    bytes += generator.text('Align right',
        styles: PosStyles(align: PosAlign.right), linesAfter: 1);

    bytes += generator.row([
      PosColumn(
        text: 'col3',
        width: 3,
        styles: PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col6',
        width: 6,
        styles: PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col3',
        width: 3,
        styles: PosStyles(align: PosAlign.center, underline: true),
      ),
    ]);

    //barcode
    final List<int> barData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 4];
    bytes += generator.barcode(Barcode.upcA(barData));

    //QR code
    bytes += generator.qrcode('example.com');

    bytes += generator.text(
      'Text size 50%',
      styles: const PosStyles(
        fontType: PosFontType.fontB,
      ),
    );
    bytes += generator.text(
      'Text size 100%',
      styles: PosStyles(
        fontType: PosFontType.fontA,
      ),
    );
    bytes += generator.text(
      'Text size 200%',
      styles: const PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.feed(2);
    //bytes += generator.cut();
    return bytes;
  }

  Future<void> printWithoutPackage() async {
    //impresion sin paquete solo de PrintBluetoothTermal
    bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      String text = _txtText.text.toString() + "\n";
      bool result = await PrintBluetoothThermal.writeString(
          printText: PrintTextSize(size: int.parse(_selectSize), text: text));
      print("status print result: $result");
      setState(() {
        _msj = "printed status: $result";
      });
    } else {
      //no conectado, reconecte
      setState(() {
        _msj = "no connected device";
      });
      print("no conectado");
    }
  }
}
