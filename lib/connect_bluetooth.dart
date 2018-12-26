import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:async';
import 'dart:convert';

class ConnectBluetooth extends StatefulWidget {
  final String email;
  final String password;
  final String ssid;
  final String wifipw;

  ConnectBluetooth({
    Key key,
    this.email,
    this.password,
    this.ssid,
    this.wifipw,
  }) : super(key: key);

  @override
  State createState() => new _ConnectBluetooth();
}

class _ConnectBluetooth extends State<ConnectBluetooth> {
  final _headingFont = const TextStyle(fontSize: 35.0);

  // Define the encoders/decoders for our data
  var decoder = new Utf8Codec();
  var jsonEncoder = new JsonEncoder();

  FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription _scanSubscription;

  BluetoothDevice rpiDevice;
  StreamSubscription deviceConnection;
  BluetoothService deviceService;

  StreamSubscription deviceStateSubscription;

  // Define the uuids that the app will look for for the wifi details
  String serviceUUID = 'ff51b30e-d7e2-4d93-8842-a7c4a57dfb07';
  String charUUID = 'ff51b30e-d7e2-4d93-8842-a7c4a57dfb09';

  @override
  Widget build(BuildContext context) {
    print(widget.email);
    print(widget.password);
    print(widget.ssid);
    print(widget.wifipw);
    return new Scaffold(
        appBar: new AppBar(
          title: const Text("Welcome to the Initial Setup"),
        ),
        body: new Center(
            child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Text(
                "Please stand in front of your Delta Smart Box and click the button below to scan for it",
                textAlign: TextAlign.center,
                style: _headingFont),
            new Padding(padding: const EdgeInsets.all(50)),
            new RaisedButton(
              onPressed: startScan,
              child: Text('Start Bluetooth Scan'),
            )
          ],
        )));
  }

  void startScan() async {
    print('Looking for a Delta Smart Charging Box...');

    if (rpiDevice == null) {
      /// Start scanning
      _scanSubscription = flutterBlue
          .scan(timeout: const Duration(seconds: 10))
          .listen((scanResult) {
        print(scanResult.device);
        print('localName: ${scanResult.advertisementData.localName}');
        print(
            'manufacturerData: ${scanResult.advertisementData.manufacturerData}');
        print('serviceData: ${scanResult.advertisementData.serviceData}');
        // If we find the raspberry pi device, then we can stop scanning
        if (scanResult.advertisementData.localName == 'Delta Solar Charger') {
          print('Found the Delta Smart Box!');
          rpiDevice = scanResult.device;
          _scanSubscription.cancel();
          connectToDevice();
        }
      }, onDone: () {
        _scanSubscription.cancel();
        print('hmm');
      });
    } else {
      print('rpidevice already exists!');
      // Todo: put code here to deal with the scenario where the device exists
    }
  }

  void connectToDevice() async {
    print('Connecting to Delta Smart Box...');
    print(rpiDevice);

    deviceConnection = flutterBlue.connect(rpiDevice).listen((s) {
      if (s == BluetoothDeviceState.connected) {
        print('Connected to Delta Smart Box');
        getServices();
      }
    });
  }

  void getServices() async {
    print('Looking for the relevant service...');
    List<BluetoothService> services = await rpiDevice.discoverServices();
    services.forEach((service) {
      print('service found: ' + service.uuid.toString());
      if (service.uuid.toString() == serviceUUID) {
        print('discovered the relevant service!');
        deviceService = service;
        writeCharacteristic();
      }
    });
  }

  void readCharacteristic() async {
    var characteristics = deviceService.characteristics;
    print('Read characteristics...');
    print(characteristics);
    for (BluetoothCharacteristic c in characteristics) {
      List<int> value = await rpiDevice.readCharacteristic(c);
      print(decoder.decode(value));
    }
  }

  void writeCharacteristic() async {
    print('We are now writing characteristic...');
    Object package = {
      'function': 'create account',
      'wifiSSID': widget.ssid,
      'wifiPW': widget.wifipw,
      'firebase_email': widget.email,
      'firebase_password': widget.password,
    };
    var jsonString = jsonEncoder.convert(package);
    var encodedJSONString = decoder.encode(jsonString);
    print(encodedJSONString);

    var characteristics = deviceService.characteristics;
    for (BluetoothCharacteristic c in characteristics) {
      if (c.uuid.toString() == charUUID) {
        print('We found the right characteristic, writing now...');
        await rpiDevice.writeCharacteristic(c, encodedJSONString,
            type: CharacteristicWriteType.withResponse);

        deviceStateSubscription = rpiDevice.onStateChanged().listen((s) {
          if (s == BluetoothDeviceState.disconnected) {
            var route = new MaterialPageRoute(
                builder: (BuildContext context) => new RegistrationComplete());
            dispose();
            Navigator.of(context).push(route);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();

    print('Killing everything!');
    if (_scanSubscription != null) {
      _scanSubscription.cancel();
    }
    if (deviceConnection != null) {
      deviceConnection.cancel();
    }
    if (deviceStateSubscription != null) {
      deviceStateSubscription.cancel();
    }

    rpiDevice = null;
    deviceService = null;
    _scanSubscription = null;
    deviceConnection = null;
    deviceStateSubscription = null;

    print('Cancelled device connection');
  }
}

class RegistrationComplete extends StatelessWidget {
  final _headingFont = const TextStyle(fontSize: 20.0);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: Text('Initial Setup Complete!'),
          leading: new Container(),
          centerTitle: true,
        ),
        body: new Center(
            child: new Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
              new Container(
                  padding: const EdgeInsets.only(left: 30.0, right: 30.0),
                  child: new Column(
                    children: <Widget>[
                      Text(
                        'You have successfully registered for a Delta Smart Charging account and your Wi-Fi details have now been passed on to the Delta Smart Box',
                        style: _headingFont,
                      ),
                      new Padding(padding: const EdgeInsets.all(30.0)),
                      new RaisedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                                '/', (Route<dynamic> route) => false);
                          },
                          child: Row(
                            children: <Widget>[
                              Text('Continue to Login'),
                              Icon(Icons.arrow_forward),
                            ],
                            mainAxisAlignment: MainAxisAlignment.center,
                          )),
                    ],
                  )),
            ])));
  }
}
