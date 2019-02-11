//import 'package:flutter/material.dart';
//import 'package:flutter_blue/flutter_blue.dart';
//import 'dart:async';
//import 'dart:convert';
//import 'package:smart_charging_app/authenticate.dart';
//
//class ChangeSettings extends StatefulWidget {
//  @override
//  _ChangeSettingsState createState() => new _ChangeSettingsState();
//}
//
//class _ChangeSettingsState extends State<ChangeSettings> {
//  //////////////////////////////////////////////////////////////////////////////
//  bool _pending = false;
//
//  bool _wifiSelected = true;
//  bool _passwordSelected = false;
//  bool _chargerIDSelected = false;
//
//  final TextEditingController _existingEmail = new TextEditingController();
//  final TextEditingController _existingPW = new TextEditingController();
//  final TextEditingController _wifiSSID = new TextEditingController();
//  final TextEditingController _wifiPW = new TextEditingController();
//  final TextEditingController _newPW = new TextEditingController();
//  final TextEditingController _newChargerID = new TextEditingController();
//
//  final _headingFont = const TextStyle(fontSize: 20.0);
//
//  //////////////////////////////////////////////////////////////////////////////
//  // Define the encoders/decoders for our data
//  var decoder = new Utf8Codec();
//  var jsonEncoder = new JsonEncoder();
//
//  //////////////////////////////////////////////////////////////////////////////
//  // Define our Bluetooth components
//  FlutterBlue flutterBlue = FlutterBlue.instance;
//  StreamSubscription _scanSubscription;
//
//  BluetoothDevice rpiDevice;
//  StreamSubscription deviceConnection;
//  BluetoothService deviceService;
//
//  StreamSubscription deviceStateSubscription;
//
//  // Define the uuids that the app will look for for the wifi details
//  String serviceUUID = 'ff51b30e-d7e2-4d93-8842-a7c4a57dfb07';
//  String charUUID = 'ff51b30e-d7e2-4d93-8842-a7c4a57dfb09';
//
//  //////////////////////////////////////////////////////////////////////////////
//  // Define a map for our payload
//  Map bluetoothPayload;
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//        appBar: new AppBar(
//          title: Text('Delta Smart Box Settings'),
//        ),
//        body: new Center(
//            child: _pending
//                ? const Center(child: const CircularProgressIndicator())
//                : new ListView(children: <Widget>[
//              new Column(
//                mainAxisAlignment: MainAxisAlignment.center,
//                children: <Widget>[
//                  new Padding(padding: const EdgeInsets.all(10.0)),
//                  new Text(
//                    "Enter your existing email and password",
//                    style: _headingFont,
//                  ),
//                  new Padding(padding: const EdgeInsets.all(10.0)),
//                  new ListTile(
//                      leading: const Icon(Icons.email),
//                      title: TextField(
//                        decoration:
//                        InputDecoration(hintText: "Existing Email"),
//                        controller: _existingEmail,
//                      )),
//                  new ListTile(
//                      leading: const Icon(Icons.lock),
//                      title: TextField(
//                        decoration: InputDecoration(
//                            hintText: "Existing Password"),
//                        controller: _existingPW,
//                      )),
//                  new Divider(
//                    color: Colors.black,
//                    height: 30.0,
//                  ),
//                  new Container(
//                    child: new Text(
//                      "Fill in the fields to adjust settings",
//                      style: _headingFont,
//                    ),
//                    padding: const EdgeInsets.all(5.0),
//                  ),
//                  new CheckboxListTile(
//                    title: const Text('Use an Ethernet Connection'),
//                    value: !_wifiSelected,
//                    onChanged: (bool value) {
//                      setState(() {
//                        _wifiSelected = !value;
//                      });
//                    },
//                    secondary: const Icon(Icons.settings_ethernet),
//                  ),
//                  new CheckboxListTile(
//                    title: const Text('I have a Wi-Fi connection'),
//                    value: _wifiSelected,
//                    onChanged: (bool value) {
//                      setState(() {
//                        _wifiSelected = value;
//                      });
//                    },
//                    secondary: const Icon(Icons.wifi),
//                  ),
//                  new ListTile(
//                      title: TextField(
//                        enabled: _wifiSelected,
//                        decoration: InputDecoration(hintText: "Wi-Fi SSID"),
//                        controller: _wifiSSID,
//                      )),
//                  new ListTile(
//                      title: TextField(
//                        enabled: _wifiSelected,
//                        decoration:
//                        InputDecoration(hintText: "Wi-Fi Password"),
//                        controller: _wifiPW,
//                      )),
//                  new CheckboxListTile(
//                    title: const Text('I want to change my password'),
//                    value: _passwordSelected,
//                    onChanged: (bool value) {
//                      setState(() {
//                        _passwordSelected = value;
//                      });
//                    },
//                    secondary: const Icon(Icons.lock),
//                  ),
//                  new ListTile(
//                      title: TextField(
//                        enabled: _passwordSelected,
//                        decoration: InputDecoration(hintText: "Password"),
//                        controller: _newPW,
//                      )),
//                  new CheckboxListTile(
//                    title: const Text('I want to change my charger ID'),
//                    value: _chargerIDSelected,
//                    onChanged: (bool value) {
//                      setState(() {
//                        _chargerIDSelected = value;
//                      });
//                    },
//                    secondary: const Icon(Icons.verified_user),
//                  ),
//                  new ListTile(
//                      title: TextField(
//                        enabled: _chargerIDSelected,
//                        decoration:
//                        InputDecoration(hintText: "New Charger ID"),
//                        controller: _newChargerID,
//                      )),
//                  new RaisedButton(
//                    onPressed: verifyUser,
//                    child: Text('Change Settings'),
//                  )
//                ],
//              )
//            ])));
//  }
//
//  void verifyUser() {
//    /// Once the user has submitted their changes, we first
//    /// verify their email and password
//
//    UserData user = new UserData();
//    UserAuth userAuth = new UserAuth();
//
////    user.email = _existingEmail.text;
////    user.password = _existingPW.text;
//    user.email = 'jgv11@gmail.com';
//    user.password = 'test123';
//
//    int wifiSelected;
//    if (_wifiSelected) wifiSelected = 1; else wifiSelected = 0;
//    int passwordSelected;
//    if (_passwordSelected) passwordSelected = 1; else passwordSelected = 0;
//    int chargerIDSelected;
//    if (_chargerIDSelected) chargerIDSelected = 1; else chargerIDSelected = 0;
//
//
//
//    userAuth.verifyUser(user).then((onValue) {
//      if (onValue == "Login Successful") {
//        bluetoothPayload = {
//          'function': 'change settings',
//          'myemail': _existingEmail.text,
//          '_wifiSelected': wifiSelected,
//          'wifiSSID': _wifiSSID.text,
//          'wifiPW': _wifiPW.text,
//          '_passwordSelected': passwordSelected,
//          'mypassword': _newPW.text,
//          '_chargerIDSelected': chargerIDSelected,
//          'newChargerID': _newChargerID.text
//        };
//        print('bluetooth payload incoming:');
//        print(bluetoothPayload);
//
//        connectBluetooth();
//      } else {
//        showDialog(
//            context: context,
//            barrierDismissible: false,
//            builder: (buildContext) {
//              return new AlertDialog(
//                title: Text('Sign in Error'),
//                content: Text(onValue),
//                actions: <Widget>[
//                  new FlatButton(
//                      onPressed: () {
//                        Navigator.of(context).pop();
//                        setState(() {
//                          _pending = false;
//                        });
//                      },
//                      child: Text('Try Again'))
//                ],
//              );
//            });
//      }
//    });
//  }
//
//  void connectBluetooth() {
//    /// Step 1: Scan for Bluetooth Devices
//    if (rpiDevice == null) {
//      _scanSubscription = flutterBlue
//          .scan(timeout: const Duration(seconds: 10))
//          .listen((scanResult) {
//        if (scanResult.advertisementData.localName == 'raspberrytest1') {
//          print('Found the Delta Smart Box!');
//          rpiDevice = scanResult.device;
//          _scanSubscription.cancel();
//
//          // Now that we foudn the Smart Box, we need to connect to it
//          connectToDevice();
//        }
//      }, onDone: () {
//        _scanSubscription.cancel();
//      });
//    } else {
//      print('rpiDevice always exists');
//      // Todo: put code here to deal with the scenario where the device exists
//    }
//  }
//
//  void connectToDevice() async {
//    /// Step 2: Connect to the Smart Box
//
//    print('Connecting to Delta Smart Box...');
//
//    deviceConnection = flutterBlue.connect(rpiDevice).listen((s) {
//      if (s == BluetoothDeviceState.connected) {
//        print('Connected to Delta Smart Box');
//        getServices();
//      }
//    });
//  }
//
//  void getServices() async {
//    /// Step 3: Find the correct service to write data to
//    print('Looking for the relevant service...');
//    List<BluetoothService> services = await rpiDevice.discoverServices();
//    services.forEach((service) {
//      print('service found: ' + service.uuid.toString());
//      if (service.uuid.toString() == serviceUUID) {
//        print('discovered the relevant service!');
//        deviceService = service;
//        writeCharacteristic();
//      }
//    });
//  }
//
//  void writeCharacteristic() async {
//    /// Step 4: Write the new settings to the Smart Box
//    print('We are now writing characteristic...');
////    Map package = {
////      'function': 'change settings',
////    };
////
////    if (bluetoothPayload['_wifiSelected']) {
////      package['_wifiSelected'] = bluetoothPayload['_wifiSelected'];
////      package['ssid'] = bluetoothPayload['wifiSSID'];
////      package['password'] = bluetoothPayload['wifiPW'];
////    }
////
////    if (bluetoothPayload['_passwordSelected']) {
////      package['_passwordSelected'] =
////          bluetoothPayload['_passwordSelected'];
////      package['email'] = bluetoothPayload['existingEmail'];
////      package['newPW'] = bluetoothPayload['newPW'];
////    }
//
//    var jsonString = jsonEncoder.convert(bluetoothPayload);
//    print(jsonString);
//    var encodedJSONString = decoder.encode(jsonString);
//    print(encodedJSONString);
//
//    var characteristics = deviceService.characteristics;
//    for (BluetoothCharacteristic c in characteristics) {
//      print(c.serviceUuid.toString());
//      if (c.uuid.toString() == charUUID) {
//        print('We found the right characteristic, writing now...');
//        await rpiDevice.writeCharacteristic(c, encodedJSONString,
//            type: CharacteristicWriteType.withResponse);
//
//        deviceStateSubscription = rpiDevice.onStateChanged().listen((s) {
//          if (s == BluetoothDeviceState.disconnected) {
////            var route = new MaterialPageRoute(
////                builder: (BuildContext context) => new SettingsChanged());
////            dispose();
////            Navigator.of(context).push(route);
//            print('Settings change success!');
//            Navigator.of(context).popUntil(ModalRoute.withName('/'));
//          }
//        });
//      }
//    }
//  }
//
//  @override
//  void dispose() {
//    print('Disposing from write characteristic!');
//    if (_scanSubscription != null) {
//      _scanSubscription.cancel();
//    }
//    if (deviceConnection != null) {
//      deviceConnection.cancel();
//    }
//    if (deviceStateSubscription != null) {
//      deviceStateSubscription.cancel();
//    }
//
//    rpiDevice = null;
//    deviceService = null;
//    _scanSubscription = null;
//    deviceConnection = null;
//    deviceStateSubscription = null;
//
//    print('Cancelled device connection');
//    super.dispose();
//  }
//}
