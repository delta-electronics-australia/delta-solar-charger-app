import 'package:flutter/material.dart';
import 'package:smart_charging_app/authenticate.dart';
import 'dart:io' show Platform;

import 'dart:io';
import 'dart:convert';

import 'package:wifi_iot/wifi_iot.dart';
import 'package:flutter/services.dart';

class InitialSetup extends StatefulWidget {
  @override
  State createState() => new _InitialSetup();
}

class _InitialSetup extends State<InitialSetup> {
  final _headingFont = const TextStyle(fontSize: 20.0);

  bool registering = false;

  UserData user = new UserData();
  UserAuth userAuth = new UserAuth();

  final TextEditingController _email = new TextEditingController();
  final TextEditingController _password = new TextEditingController();

  final FocusNode _passwordFocus = new FocusNode();
  final FocusNode _ssidFocus = new FocusNode();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: Text("Delta Smart Charging Initial Setup"),
        ),
        body: new Center(
            child: registering
                ? const Center(child: const CircularProgressIndicator())
                : new Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      new Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              "Create a Delta Solar Charger Account",
                              style: _headingFont,
                              textAlign: TextAlign.center,
                            ),
                            new Padding(
                                padding: const EdgeInsets.only(top: 30.0)),
                            new ListTile(
                                leading: const Icon(Icons.email),
                                title: new TextField(
                                  controller: _email,
                                  decoration:
                                      new InputDecoration(hintText: "Email"),
                                  onSubmitted: (String value) {
                                    FocusScope.of(context)
                                        .requestFocus(_passwordFocus);
                                  },
                                )),
                            new ListTile(
                                leading: const Icon(Icons.lock),
                                title: new TextField(
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  decoration:
                                      new InputDecoration(hintText: "Password"),
                                  onSubmitted: (String value) {
                                    FocusScope.of(context)
                                        .requestFocus(_ssidFocus);
                                  },
                                  obscureText: true,
                                )),
                            new Padding(
                                padding: const EdgeInsets.only(bottom: 15)),
                            new RaisedButton(
                                child: Text('Register'),
                                onPressed: _handleRegister,
                                padding: const EdgeInsets.only(top: 1.0)),
                            new Padding(
                              padding: const EdgeInsets.all(15.0),
                            ),
                            new RaisedButton(
                              child: Text('Bypass'),
                              onPressed: () {
                                var route = new MaterialPageRoute(
                                    builder: (BuildContext context) =>
                                        new SelectConnectionPage(
                                          firebaseEmail: 'test123@gmail.com',
                                          firebasePassword: 'test123',
                                        ));
                                Navigator.of(context).push(route);
                              },
                            ),
                          ])
                    ],
                  )));
  }

  void _handleRegister() {
    setState(() {
      registering = true;
    });
    // This function handles the registration.
    user.email = _email.text;
    user.password = _password.text;
    userAuth.createUser(user).then((returnValue) {
      if (returnValue == "Account Created Successfully!") {
        // Now let's send the charger ID and the user/pass to OCPP backend
        var route = new MaterialPageRoute(
          builder: (BuildContext context) => new SelectConnectionPage(
                firebaseEmail: user.email,
                firebasePassword: user.password,
              ),
        );
        Navigator.of(context).push(route);
      } else {
        // If there is an error, we show a dialog with the error
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return new AlertDialog(
                title: new Text("Registration Error"),
                content: new Text(returnValue),
                actions: <Widget>[
                  new FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          registering = false;
                        });
                      },
                      child: new Text('Try Again'))
                ],
              );
            });
      }
    });
  }
}

class SelectConnectionPage extends StatefulWidget {
  final String firebaseEmail;
  final String firebasePassword;

  SelectConnectionPage({
    Key key,
    this.firebaseEmail,
    this.firebasePassword,
  }) : super(key: key);

  @override
  _SelectConnectionPageState createState() => _SelectConnectionPageState();
}

class _SelectConnectionPageState extends State<SelectConnectionPage> {
  final _headingFont = const TextStyle(fontSize: 20.0);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(title: const Text('Connection Selection')),
        body: new ListView(
          children: <Widget>[
            new Text(
                "Select how your Delta Solar Charger Controller will connect to the Internet",
                textAlign: TextAlign.center,
                style: _headingFont),
            new Card(
                child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[new Text('Ethernet')],
            )),
            new Card(
                child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[new Text('3G')],
            )),
            new Card(
                shape: new RoundedRectangleBorder(
                    side: new BorderSide(color: Colors.blue, width: 2.0),
                    borderRadius: BorderRadius.circular(4.0)),
                child: new Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[new Text('Wi-Fi')],
                )),
            new RaisedButton(
              onPressed: connectionSelected,
              child: const Text('Next'),
            )
          ],
        ));
  }

  void connectionSelected() {
    Platform.isAndroid
        ? Navigator.of(context).push(new MaterialPageRoute(
            builder: (BuildContext context) => new SendWiFiPayloadAndroid(
                  connectionMethod: '3G',
                  connectionPayload: {},
                ),
          ))
        : Navigator.of(context).push(new MaterialPageRoute(
            builder: (BuildContext context) => new SendWifiPayloadiOS(
                  connectionMethod: '3G',
                  connectionPayload: {},
                ),
          ));
  }
}

class SendWiFiPayloadAndroid extends StatefulWidget {
  final String connectionMethod;
  final Map connectionPayload;

  SendWiFiPayloadAndroid({
    Key key,
    this.connectionMethod,
    this.connectionPayload,
  }) : super(key: key);

  @override
  _SendWiFiPayloadAndroidState createState() => _SendWiFiPayloadAndroidState();
}

class _SendWiFiPayloadAndroidState extends State<SendWiFiPayloadAndroid> {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Connect Wi-Fi'),
      ),
      body: new Column(
        children: <Widget>[],
      ),
    );
  }

  loadWifiList() async {
    List<WifiNetwork> htResultNetwork;
    try {
      htResultNetwork = await WiFiForIoTPlugin.loadWifiList();
    } on PlatformException {
      htResultNetwork = new List<WifiNetwork>();
    }

    /// Loop through all of the discovered networks to see if we can find a
    /// Delta Solar Charger
    for (WifiNetwork network in htResultNetwork) {
      print(network.ssid);
      print(network.password);
      if (network.ssid.contains('177h7f')) {
        // Todo: put a confirmation message here
        print('Found a Delta Solar Charger! Trying to connect...');
        bool result = await WiFiForIoTPlugin.connect(network.ssid,
            password: '6050751829', security: NetworkSecurity.WPA);
        print(result);
        break;
      }
    }

    /// Now that we are connected, we can now send the payload to the controller
    print('Connected to the Solar Charger. Transmitting data now...');
    bool result = await sendInitialSetupPostRequest();
    print(result);
  }

  @override
  void initState() {
    super.initState();

    loadWifiList();
  }
}

class SendWifiPayloadiOS extends StatefulWidget {
  final String connectionMethod;
  final Map connectionPayload;

  SendWifiPayloadiOS({
    Key key,
    this.connectionMethod,
    this.connectionPayload,
  }) : super(key: key);

  @override
  _SendWifiPayloadiOSState createState() => _SendWifiPayloadiOSState();
}

class _SendWifiPayloadiOSState extends State<SendWifiPayloadiOS> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

Future<bool> sendInitialSetupPostRequest() async {
  Map requestPayload = {
    "flutter": "hello world",
    'wififlutter': 'gitgit',
    'hooha!': 'test2'
  };

  // Todo: this URL needs to change: will be all the same
  String url = "http://192.168.0.14:5000/delta_solar_charger_initial_setup";
  HttpClient httpClient = new HttpClient();
  HttpClientRequest request = await httpClient.postUrl(Uri.parse(url));

  request.headers.set('content-type', 'application/json');
  request.add(utf8.encode(json.encode(requestPayload)));
  HttpClientResponse response = await request.close();
  String tempReply = await response.transform(utf8.decoder).join();
  httpClient.close();

  // Todo: have some test here to see if it's all good
  print(tempReply);
  return true;
}
