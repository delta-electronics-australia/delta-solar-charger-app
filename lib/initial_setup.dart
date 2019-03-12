import 'package:flutter/material.dart';
import 'package:smart_charging_app/authenticate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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

  String radioSelection = 'register';

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
                            new Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  new Radio(
                                    value: 'register',
                                    groupValue: radioSelection,
                                    onChanged: radioSelected,
                                  ),
                                  new Text(
                                    'Make a new account',
                                    style: new TextStyle(fontSize: 16.0),
                                  ),
                                  new Radio(
                                    value: 'login',
                                    groupValue: radioSelection,
                                    onChanged: radioSelected,
                                  ),
                                  new Text(
                                    'I have an account',
                                    style: new TextStyle(
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            radioSelection == "register"
                                ? new Text(
                                    "Create a Delta Solar Charger Account",
                                    style: _headingFont,
                                    textAlign: TextAlign.center,
                                  )
                                : new Text(
                                    "Login to your Delta Solar Charger Account",
                                    style: _headingFont,
                                    textAlign: TextAlign.center,
                                  ),
                            new Padding(
                                padding: const EdgeInsets.only(top: 15.0)),
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
                            radioSelection == "register"
                                ? new RaisedButton(
                                    child: const Text('Register'),
                                    onPressed: _handleRegister,
                                    padding: const EdgeInsets.only(top: 1.0))
                                : new RaisedButton(
                                    child: const Text('Login'),
                                    onPressed: _handleLogin,
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
                                          firebaseEmail: 'jgv115@gmail.com',
                                          firebasePassword: 'test123',
                                        ));
                                Navigator.of(context).push(route);
                              },
                            ),
                          ])
                    ],
                  )));
  }

  void radioSelected(text) {
    radioSelection = text;
    setState(() {});
  }

  void _handleLogin() {
    setState(() {
      registering = true;
    });

    // This function handles the login.
    user.email = _email.text;
    user.password = _password.text;

    userAuth.verifyUser(user).then((onValue) {
      print(onValue);
      if (onValue == "Login Successful") {
        registering = false;

        /// Now let's send the charger ID and the user/pass to OCPP backend
        var route = new MaterialPageRoute(
          builder: (BuildContext context) => new SelectConnectionPage(
                firebaseEmail: user.email,
                firebasePassword: user.password,
              ),
        );
        Navigator.of(context).push(route);
      } else {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (buildContext) {
              return new AlertDialog(
                title: Text('Sign in Error'),
                content: Text(onValue),
                actions: <Widget>[
                  new FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          registering = false;
                        });
                      },
                      child: Text('Try Again'))
                ],
              );
            });
      }
    });
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
        /// Now let's send the charger ID and the user/pass to OCPP backend
        var route = new MaterialPageRoute(
          builder: (BuildContext context) => new SelectConnectionPage(
                firebaseEmail: user.email,
                firebasePassword: user.password,
              ),
        );
        Navigator.of(context).push(route);
      } else {
        /// If there is an error, we show a dialog with the error
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

  String selectedConnectionMethod;

  /// _nameController is the TextEditingController for setting the nickname of the system
  final TextEditingController _nameController = new TextEditingController();

  /// _nameButtonDisabled is the boolean to see if the submit name button
  /// should be enabled
  bool _nextButtonDisabled = true;

  String get name => _nameController.text;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(title: const Text('Connection Selection')),
        body: new ListView(
          children: <Widget>[
            new Padding(
              padding: const EdgeInsets.all(15),
              child: new Text(
                  "Select how your Delta Solar Charger Controller will connect to the Internet",
                  textAlign: TextAlign.center,
                  style: _headingFont),
            ),
            new Card(
                shape: new RoundedRectangleBorder(
                    side: new BorderSide(
                        color: selectedConnectionMethod == 'none'
                            ? Colors.blue
                            : Colors.white,
                        width: 2.0),
                    borderRadius: BorderRadius.circular(4.0)),
                child: new ListTile(
                  title: new Text('None - Run in offline mode'),
                  onTap: () {
                    selectedConnectionMethod = 'none';
                    _nextButtonDisabled = false;
                    setState(() {});
                  },
                )),
            new Card(
                shape: new RoundedRectangleBorder(
                    side: new BorderSide(
                        color: selectedConnectionMethod == 'ethernet'
                            ? Colors.blue
                            : Colors.white,
                        width: 2.0),
                    borderRadius: BorderRadius.circular(4.0)),
                child: new ListTile(
                  title: new Text('Ethernet'),
                  onTap: () {
                    selectedConnectionMethod = 'ethernet';
                    _nextButtonDisabled = false;
                    setState(() {});
                  },
                )),
            new Card(
                shape: new RoundedRectangleBorder(
                    side: new BorderSide(
                        color: selectedConnectionMethod == 'wifi'
                            ? Colors.blue
                            : Colors.white,
                        width: 2.0),
                    borderRadius: BorderRadius.circular(4.0)),
                child: new ListTile(
                    title: new Text('Wi-Fi'),
                    onTap: () {
                      selectedConnectionMethod = 'wifi';
                      _nextButtonDisabled = false;
                      setState(() {});
                    })),
            new Card(
                shape: new RoundedRectangleBorder(
                    side: new BorderSide(
                        color: selectedConnectionMethod == '3G'
                            ? Colors.blue
                            : Colors.white,
                        width: 2.0),
                    borderRadius: BorderRadius.circular(4.0)),
                child: new ListTile(
                    title: new Text('3G/4G'),
                    onTap: () {
                      selectedConnectionMethod = '3G';
                      _nextButtonDisabled = false;
                      setState(() {});
                    })),
            new Divider(),
            new Text(
              'System Name',
              style: _headingFont,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: new Text(
                'Please enter name that will be used to identify the system',
                style: null,
                textAlign: TextAlign.center,
              ),
            ),
            new ListTile(
                title: new TextField(
              controller: _nameController,
              decoration:
                  new InputDecoration(hintText: "Enter a new system name"),
              onChanged: (text) {
                if (text == "") {
                  _nextButtonDisabled = true;
                } else {
                  _nextButtonDisabled = false;
                }
                setState(() {});
              },
            )),
            new RaisedButton(
              onPressed: _nextButtonDisabled ? null : connectionSelected,
              child: const Text('Next'),
            )
          ],
        ));
  }

  void connectionSelected() {
    Navigator.of(context).push(new MaterialPageRoute(
      builder: (BuildContext context) => new ScanWifiNetworks(
          connectionMethod: selectedConnectionMethod,
          firebaseEmail: widget.firebaseEmail,
          firebasePassword: widget.firebasePassword),
    ));
  }

  @override
  void initState() {
    super.initState();
    print(widget.firebaseEmail);
    print(widget.firebasePassword);
  }
}

class ScanWifiNetworks extends StatefulWidget {
  final String connectionMethod;
  final String firebaseEmail;
  final String firebasePassword;

  ScanWifiNetworks({
    Key key,
    this.connectionMethod,
    this.firebaseEmail,
    this.firebasePassword,
  }) : super(key: key);

  @override
  _ScanWifiNetworksState createState() => _ScanWifiNetworksState();
}

class _ScanWifiNetworksState extends State<ScanWifiNetworks> {
  /// Boolean value that tells us whether or not we have discovered any solar chargers
  bool displayScanResults = false;

  /// Boolean value that tells us whether or not the scan has failed
  bool wifiScanFailed = false;

  /// Boolean variable that tells us whether we're still on the scan page
  bool disposed = false;

  String progressString = "";
  IconData progressIcon;

  /// Initialize the list of solar charger SSIDs
  Map<String, bool> solarChargerMap = {};

  /// Intialize the currently selected solar charger
  String currentSelectedSolarCharger;

  /// Initialize the user selected SSID
  String selectedSSID;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: const Text('Scan for Delta Solar Chargers'),
        ),
        body: displayScanResults
            ? new Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Padding(
                      padding: const EdgeInsets.only(top: 15, bottom: 15),
                      child: new Text(
                        'Please Select the Correct Solar Charger:',
                        style: TextStyle(fontSize: 20.0),
                        textAlign: TextAlign.center,
                      )),
                  ListView.builder(
                      shrinkWrap: true,
                      itemCount: solarChargerMap.keys.toList().length,
                      itemBuilder: (context, index) {
                        List solarChargerList = solarChargerMap.keys.toList();

                        /// Use a GestureDetector to wrap the card to detect a tap
                        return new GestureDetector(
                          child: new Card(
                            shape: new RoundedRectangleBorder(
                                side: new BorderSide(

                                    /// The colour of the border will depend on if the solar charger is the
                                    /// currently selected solar charger
                                    color: solarChargerList[index] ==
                                            currentSelectedSolarCharger
                                        ? Colors.blue
                                        : Colors.white,
                                    width: 2.0),
                                borderRadius: BorderRadius.circular(4.0)),
                            child: ListTile(
                              title: new Text(
                                '${solarChargerList[index]}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          onTap: () {
                            print('${solarChargerList[index]} tapped');

                            /// First check if there is the currently selected charger is assigned
                            if (currentSelectedSolarCharger != null) {
                              /// If it is assigned, then make that solar charger false in solarChargerMap
                              solarChargerMap[currentSelectedSolarCharger] =
                                  false;
                            }

                            /// Update our currently selected charger
                            currentSelectedSolarCharger =
                                solarChargerList[index];

                            /// Then update our solarChargerMap to be true
                            solarChargerMap[currentSelectedSolarCharger] = true;

                            /// Set the state so that the selected solar charger will have a blue border
                            setState(() {});
                          },
                        );
                      }),
                  new Expanded(
                      child: new Padding(
                    padding: const EdgeInsets.only(top: 15, bottom: 15),
                    child: new Align(
                      child: new RaisedButton(
                        onPressed: () {
                          disposed = true;

                          Platform.isAndroid
                              ? Navigator.of(context)
                                  .push(new MaterialPageRoute(
                                  builder: (BuildContext context) =>
                                      new SendWiFiPayloadAndroid(
                                        connectionMethod:
                                            widget.connectionMethod,
                                        solarChargerSSID:
                                            currentSelectedSolarCharger,
                                        firebaseEmail: widget.firebaseEmail,
                                        firebasePassword:
                                            widget.firebasePassword,
                                      ),
                                ))
                              : Navigator.of(context)
                                  .push(new MaterialPageRoute(
                                  builder: (BuildContext context) =>
                                      new SendWiFiPayloadiOS(
                                        connectionMethod:
                                            widget.connectionMethod,
                                        solarChargerSSID:
                                            currentSelectedSolarCharger,
                                        firebaseEmail: widget.firebaseEmail,
                                        firebasePassword:
                                            widget.firebasePassword,
                                      ),
                                ));
                        },
                        child: const Text('Select Solar Charger'),
                      ),
                      alignment: Alignment.bottomCenter,
                    ),
                  ))
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

                  /// Depending on whether or not the scan failed we show the
                  /// progress indicator or a back button
                  wifiScanFailed
                      ? new Center(
                          child: new RaisedButton(
                            onPressed: () {
                              startWifiScan();
                            },
                            child: const Text('Scan again'),
                          ),
                        )
                      : const Center(child: const CircularProgressIndicator()),
                  new Padding(
                      padding: new EdgeInsets.only(
                          top: MediaQuery.of(context).size.height / 3.2))
                ],
              ));
  }

  startWifiScan() async {
    print('hello');
    setState(() {
      wifiScanFailed = false;
      progressIcon = Icons.signal_wifi_off;
      progressString = 'Finding a Delta Solar Charger...';
    });

    bool wifiNetworkFound = false;
    String ssid;

    /// Try three times to find the Solar Charger Wi-Fi network
    for (int i = 0; i < 2000; i++) {
      if (!disposed) {
        print('Attempt $i at finding a Solar Charger');

        List<WifiNetwork> htResultNetwork;
        try {
          htResultNetwork = await WiFiForIoTPlugin.loadWifiList();
        } on PlatformException {
          htResultNetwork = new List<WifiNetwork>();
        }

        /// Loop through Wi-Fi networks to see if we can find a Delta Solar Charger
        for (WifiNetwork network in htResultNetwork) {
          /// If we have found a solar charger and this solar charger isn't already in the list
          if (network.ssid.contains('Delta_Solar_Charger') &
              !solarChargerMap.containsKey(network.ssid)) {
            wifiNetworkFound = true;
            ssid = network.ssid;
            selectedSSID = ssid;

            /// Then we add it to the list and update our state
            solarChargerMap[ssid] = false;
            displayScanResults = true;
            setState(() {
              print(solarChargerMap);
            });
          }
        }
      }
    }

    if (!wifiNetworkFound) {
      setState(() {
        wifiScanFailed = true;
        progressIcon = Icons.signal_wifi_off;
        progressString = 'Solar Charger not found. Please try again.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startWifiScan());
  }

  @override
  void dispose() {
    super.dispose();
    disposed = true;
  }
}

class SendWiFiPayloadAndroid extends StatefulWidget {
  final String connectionMethod;
  final String solarChargerSSID;
  final String firebaseEmail;
  final String firebasePassword;

  SendWiFiPayloadAndroid({
    Key key,
    @required this.connectionMethod,
    @required this.solarChargerSSID,
    @required this.firebaseEmail,
    @required this.firebasePassword,
  }) : super(key: key);

  @override
  _SendWiFiPayloadAndroidState createState() => _SendWiFiPayloadAndroidState();
}

class _SendWiFiPayloadAndroidState extends State<SendWiFiPayloadAndroid> {
  /// Boolean that tells us if the initialization process is complete
  bool processCompleted = false;

  /// Boolean that tells us to show the return home button or the circular indicator
  bool showReturnHome = false;

  /// String that tells the user what stage they are up to
  String progressString = "";

  /// Initialize the progress icon
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
                    showReturnHome
                        ? new RaisedButton(
                            onPressed: () {
                              Navigator.popUntil(
                                  context, ModalRoute.withName('/'));
                            },
                            child: new Text('Return to login page'),
                          )
                        : const Center(
                            child: const CircularProgressIndicator()),
                    new Padding(
                        padding: new EdgeInsets.only(
                            top: MediaQuery.of(context).size.height / 3.2))
                  ],
                )),
    );
  }

  transmitWifiData(String ssid) async {
    /// Now that we are connected, we can now send the payload to the controller

    print('Connected to the Solar Charger. Transmitting data now...');
    dynamic transmissionSuccess = false;

    for (int i = 0; i < 100; i++) {
      print('Attempt $i in transmitting payload to Solar Charger');

      transmissionSuccess = await sendInitialSetupPostRequest(
          widget.connectionMethod,
          widget.firebaseEmail,
          widget.firebasePassword);

      if (transmissionSuccess == true) {
        print('Initialization complete!');

        // Todo: ALL OF THIS NEEDS TESTING!
        /// Now that initialization is complete, let's forget the Wi-Fi network
        await WiFiForIoTPlugin.removeWifiNetwork(ssid);

        /// We also have to initialize a node in Firebase with the uid if we chose offline mode
        final FirebaseAuth _auth = FirebaseAuth.instance;
        try {
          /// First sign in to our new account
          FirebaseUser user = await _auth.signInWithEmailAndPassword(
              email: widget.firebaseEmail, password: widget.firebasePassword);

          /// Then update our connectivity node inside the uid
          FirebaseDatabase db = new FirebaseDatabase();
          await db
              .reference()
              .child('users/${user.uid}/')
              .update({'connectivity': widget.connectionMethod});

          /// Then log out of the account
          await _auth.signOut();
        } catch (e) {
          return e.message;
        }

        setState(() {
          processCompleted = true;
        });
        break;
      } else if (transmissionSuccess == "config exists") {
        print('Configuration already exists - failed');

        progressIcon = Icons.error_outline;
        progressString =
            "This Delta Solar Charger has already been assigned to another account. "
            "Please login to factory reset this Solar Charger and try again";
        showReturnHome = true;
        setState(() {});
      }
    }

    if (transmissionSuccess == false) {
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
      progressString = 'Attemping to connect to selected Solar Charger...';
    });
    bool wifiConnectionResult = false;

    String password;
    if (ssid == "Delta_Solar_Charger") {
      password = '1234567890';
    } else {
      password = 'DELTA${ssid.split('_')[3]}';
    }

    for (int i = 0; i < 10; i++) {
      print('Attempt $i at connecting to Solar Charger');

      /// Try to connect to the discovered Solar Charger Wi-Fi AP
      wifiConnectionResult = await WiFiForIoTPlugin.connect(ssid,
          password: password, security: NetworkSecurity.WPA);

      if (wifiConnectionResult == true) {
        setState(() {
          progressIcon = Icons.sync;
          progressString =
              'Connection successful. Initializing Solar Charger...';
        });
        break;
      }
    }

    print('Wifi connection result: $wifiConnectionResult');

    if (wifiConnectionResult) {
      await new Future.delayed(const Duration(seconds: 5));
      transmitWifiData(ssid);
    } else {
      setState(() {
        progressIcon = Icons.signal_wifi_off;
        progressString =
            'Connection unsuccessful. Please go back and try again';
        showReturnHome = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    print(widget.firebaseEmail);
    connectToWifi(widget.solarChargerSSID);
  }
}

class SendWiFiPayloadiOS extends StatefulWidget {
  final String connectionMethod;
  final String solarChargerSSID;
  final String firebaseEmail;
  final String firebasePassword;

  SendWiFiPayloadiOS({
    Key key,
    this.connectionMethod,
    @required this.solarChargerSSID,
    @required this.firebaseEmail,
    @required this.firebasePassword,
  }) : super(key: key);

  @override
  _SendWiFiPayloadiOSState createState() => _SendWiFiPayloadiOSState();
}

class _SendWiFiPayloadiOSState extends State<SendWiFiPayloadiOS> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

Future sendInitialSetupPostRequest(
    connectionMethod, firebaseEmail, firebasePassword) async {
  Map requestPayload = {
    "connectionMethod": connectionMethod,
    "firebase_email": firebaseEmail,
    'firebase_password': firebasePassword,
  };

  print('Request payload is :');
  print(requestPayload);

  String url = "http://192.168.10.1:5000/delta_solar_charger_initial_setup";
  HttpClient httpClient = new HttpClient();

  /// Set our client timeout to 10 seconds.
  httpClient.connectionTimeout = const Duration(seconds: 5);

  /// tempReply is the reply from the solar charger unit
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

  /// Check if we got any reply from the solar charger
  if (tempReply != null) {
    /// If we got a reply then decode it and make sure the POST was successful
    Map parsedReply = json.decode(tempReply);
    print(parsedReply['success']);
    return parsedReply['success'];
  }
}
