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
  bool processCompleted = false;
  String progressString = "";
  IconData progressIcon;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Connect Wi-Fi'),
      ),
      body: new Center(
          child: processCompleted
              ? new Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Icon(
                      Icons.check_circle_outline,
                      size: MediaQuery.of(context).size.width / 1.5,
                    ),
                    new Text(
                      'Solar Charger Initialisation Complete. You may now login to your Delta Solar Charger Account',
                      style: TextStyle(fontSize: 20.0),
                      textAlign: TextAlign.center,
                    ),
                    new Padding(padding: const EdgeInsets.all(25)),
                    new RaisedButton(
                      onPressed: () {
                        Navigator.popUntil(context, ModalRoute.withName('/'));
                      },
                      child: new Text('Return to login page'),
                    ),
                    new Padding(
                        padding: new EdgeInsets.only(
                            top: MediaQuery.of(context).size.height / 3.2))
                  ],
                )
              : new Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Icon(
                      progressIcon,
                      size: MediaQuery.of(context).size.width / 1.5,
                    ),
                    new Text(
                      progressString,
                      style: TextStyle(fontSize: 20.0),
                      textAlign: TextAlign.center,
                    ),
                    new Padding(padding: const EdgeInsets.all(25)),
                    const Center(child: const CircularProgressIndicator()),
                    new Padding(
                        padding: new EdgeInsets.only(
                            top: MediaQuery.of(context).size.height / 3.2))
                  ],
                )),
    );
  }

  transmitWifiData() async {
    /// Now that we are connected, we can now send the payload to the controller

    print('Connected to the Solar Charger. Transmitting data now...');
    bool transmissionSuccess = false;

    for (int i = 0; i < 10; i++) {
      print('Attempt $i in transmitting payload to Solar Charger');

      transmissionSuccess = await sendInitialSetupPostRequest();

      if (transmissionSuccess == true) {
        print('Initialization complete!');
        setState(() {
          processCompleted = true;
        });
        break;
      }

      /// Sleep for one second before trying to transmit again
      sleep(Duration(seconds: 1));
    }

    if (!transmissionSuccess) {
      print('Transmission failed 10 times...');
      progressIcon = Icons.sync_problem;
      progressString =
      'Transmission unsuccessful. Please go back and try again';
    }
  }

  connectToWifi(String ssid) async {
    /// This functions connects the app to a Solar Charger with a SSID

    print('Found a Delta Solar Charger! Trying to connect to $ssid');

    setState(() {
      progressIcon = Icons.signal_wifi_4_bar;
      progressString = 'Solar Charger found. Attemping to connect...';
    });
    bool wifiConnectionResult = false;

    for (int i = 0; i < 10; i++) {
      print('Attempt $i at connecting to Solar Charger');

      /// Try to connect to the discovered Solar Charger Wi-Fi AP
      wifiConnectionResult = await WiFiForIoTPlugin.connect(ssid,
          password: '1234567890', security: NetworkSecurity.WPA);

      if (wifiConnectionResult == true) {
        setState(() {
          progressIcon = Icons.sync;
          progressString =
              'Connection successful. Initializing Solar Charger...';
        });
        break;
      }

      sleep(Duration(seconds: 1));
    }

    print('Wifi connection result: $wifiConnectionResult');

    if (wifiConnectionResult) {
      transmitWifiData();
    } else {
      setState(() {
        progressIcon = Icons.signal_wifi_off;
        progressString =
            'Connection unsuccessful. Please go back and try again';
      });
    }
  }

  handleInitialSetup() async {
    setState(() {
      progressIcon = Icons.signal_wifi_off;
      progressString = 'Finding a Delta Solar Charger...';
    });

    bool wifiNetworkFound = false;
    String ssid;

    /// Try three times to find the Solar Charger Wi-Fi network
    for (int i = 0; i < 3; i++) {
      print('Attempt $i at finding a Solar Charger');

      List<WifiNetwork> htResultNetwork;
      try {
        htResultNetwork = await WiFiForIoTPlugin.loadWifiList();
      } on PlatformException {
        htResultNetwork = new List<WifiNetwork>();
      }

      /// Loop through Wi-Fi networks to see if we can find a Delta Solar Charger
      for (WifiNetwork network in htResultNetwork) {
        print(network.ssid);

        // Todo: change the SSID to Delta_Solar_Charger_xx
        if (network.ssid.contains('Delta_Solar_Charger')) {
          wifiNetworkFound = true;
          ssid = network.ssid;

          /// Break out of the SSID search process
          break;
        }
      }

      /// If we have found a network then we can break out of our loop
      if (wifiNetworkFound) {
        break;
      }
    }

    if (wifiNetworkFound) {
      connectToWifi(ssid);
    } else {
      setState(() {
        progressIcon = Icons.signal_wifi_off;
        progressString =
            'Solar Charger not found. Please press back and try again.';
      });
    }
  }

  @override
  void initState() {
    super.initState();

    handleInitialSetup();
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
    "firebase_email": "jgv115@gmail.com",
    'firebase_password': 'test123',
  };

  // Todo: this URL needs to change: will be all the same
  String url = "http://192.168.10.1:5000/delta_solar_charger_initial_setup";
  HttpClient httpClient = new HttpClient();

  /// Set our client timeout to 10 seconds.
  httpClient.connectionTimeout = const Duration(seconds: 5);
  String tempReply;

  try {
    HttpClientRequest request = await httpClient.postUrl(Uri.parse(url));

    request.headers.set('content-type', 'application/json');
    request.add(utf8.encode(json.encode(requestPayload)));
    HttpClientResponse response = await request.close();
    tempReply = await response.transform(utf8.decoder).join();
    httpClient.close();
  } catch (e) {
    print('Got an error!');
    print(e);
    return false;
  }

  // Todo: have some test here to see if it's all good
  bool success;

  /// Check if we got any reply from the solar charger
  if (tempReply != null) {
    /// If we got a reply then decode it and make sure the POST was successful
    Map parsedReply = json.decode(tempReply);

    if (parsedReply['success'] == true) {
      success = true;
    }
  } else {
    success = false;
  }

  return success;
}
