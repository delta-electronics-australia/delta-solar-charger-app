import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_charging_app/authenticate.dart';
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/inverter_archive.dart';
import 'package:smart_charging_app/charger_info.dart';

Future<FirebaseApp> main() async {
  final FirebaseApp app = await FirebaseApp.configure(
    name: 'smart-charging-app',
    options: Platform.isIOS
        ? const FirebaseOptions(
            googleAppID: '1:297855924061:ios:c6de2b69b03a5be8',
            gcmSenderID: '297855924061',
            databaseURL: 'https://smart-charging-app.firebaseio.com/',
          )
        : const FirebaseOptions(
            googleAppID: '1:896921007938:android:2be6175bd778747f',
            apiKey: 'AIzaSyCaxTOBofd7qrnbas5gGsZcuvy_zNSi_ik',
            databaseURL: 'https://smart-charging-app.firebaseio.com/',
          ),
  );
  return app;
}

class SolarChargerSettings extends StatefulWidget {
  @override
  _SolarChargerSettingsState createState() => _SolarChargerSettingsState();
}

class _SolarChargerSettingsState extends State<SolarChargerSettings> {
  FirebaseDatabase database;

  /// Initialize the strings that will define our display name and email
  String _displayName = "";
  String _displayEmail = "";

  final _headingFont = const TextStyle(fontSize: 25.0);
  Map<String, String> chargingModeOptions = {
    'Standalone: PV with Battery Backup': 'PV_with_BT',
    'Standalone: Maximise EV Charge Rate': 'MAX_CHARGE_STANDALONE',
    'BETA: PV Standalone without BT': 'PV_no_BT',
    'Grid Connected: Maximise EV Charge Rate': 'MAX_CHARGE_GRID'
  };
  List<String> bufferAggressivenessOptions = [
    'Aggressive',
    'Balanced',
    'Conservative',
    'Ultra Conservative'
  ];
  Map<String, String> authenticationRequiredOptions = {
    'RFID Swipe Required': 'true',
    'RFID Swipe not Required': 'false'
  };

  String singleChargingMode;
  String bufferAggroMode;
  String authenticationRequired;

  StreamSubscription _singleChargingModeSubscription;
  StreamSubscription _bufferAggroModeSubscription;
  StreamSubscription _authenticationRequiredSubscription;
  StreamSubscription _versionSubscription;

  bool checkingForUpdates = false;

  Widget firmwareWidget;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: const Text('Delta Solar Charger Settings')),
      drawer: new Drawer(
          child: ListView(children: <Widget>[
        UserAccountsDrawerHeader(
          accountName: Text(_displayName),
          accountEmail: Text(_displayEmail),
//                currentAccountPicture: const CircleAvatar(),
          decoration: new BoxDecoration(color: Colors.blue),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Dashboard'),
          onTap: () {
            Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
          },
        ),
        ListTile(
          leading: const Icon(Icons.show_chart),
          title: const Text('Live System Data'),
          onTap: () {
            var route = new MaterialPageRoute(
                builder: (BuildContext context) => new DataStreamPage1());
            Navigator.of(context).pop();
            Navigator.of(context).push(route);
          },
        ),
        Divider(),

        ListTile(
          leading: const Icon(Icons.unarchive),
          title: const Text('System Archive'),
          onTap: () {
            var route = new MaterialPageRoute(
                builder: (BuildContext context) => new InverterArchive());
            Navigator.of(context).pop();
            Navigator.of(context).push(route);
          },
        ),
        ListTile(
          leading: const Icon(Icons.offline_bolt),
          title: const Text('Charging Session Archive'),
          onTap: () {
            var route = new MaterialPageRoute(
                builder: (BuildContext context) => new ChargingArchive());
            Navigator.of(context).pop();
            Navigator.of(context).push(route);
          },
        ),
//                  ListTile(
//                    title: Text('Live Data Stream2'),
//                    onTap: () {
//                      var route = new MaterialPageRoute(
//                          builder: (
//                              BuildContext context) => new DataStreamPage());
//                      Navigator.of(context).pop();
//                      Navigator.of(context).push(route);
//                    },
//                  ),
        Divider(),

        ListTile(
          leading: const Icon(Icons.power),
          title: Text('Connected Chargers'),
          onTap: () {
            var route = new MaterialPageRoute(
                builder: (BuildContext context) => new ChargerInfo());
            Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
            Navigator.of(context).push(route);
          },
        ),

        Divider(),

        ListTile(
          leading: const Icon(Icons.settings),
          title: Text('Change Solar Charging Settings'),
          onTap: () {
            var route = new MaterialPageRoute(
                builder: (BuildContext context) => new SolarChargerSettings());
            Navigator.of(context).pop();
            Navigator.of(context).push(route);
          },
        ),
//              ListTile(
//                title: Text('Change Delta Smart Box Settings'),
//                onTap: () {
//                  print('moving to setings');
//                  var route = new MaterialPageRoute(
//                      builder: (BuildContext context) => new ChangeSettings());
//                  Navigator.of(context).pop();
//                  Navigator.of(context).push(route);
//                },
//              ),
        Divider(),
        ListTile(
          title: Text('Sign Out'),
          onTap: _signOut,
        ),
      ])),
      body: new Center(
          child: new ListView(
        children: <Widget>[
//          new Padding(padding: const EdgeInsets.only(top: 15))
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: new Card(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: singleChargingMode != null
                  ? new Column(
                      children: <Widget>[
                        new Text(
                          'Charging Mode',
                          style: _headingFont,
                        ),
                        new DropdownButton(
                          // Need a List<DropdownMenu<String>>
                          items: chargingModeOptions.keys
                              .toList()
                              .map((String chargingMode) {
                            return new DropdownMenuItem<String>(
                                child: Text(chargingMode),
                                value: chargingModeOptions[chargingMode]);
                          }).toList(),
                          onChanged: chargingModeChanged,
                          value: singleChargingMode,
                        )
                      ],
                      mainAxisAlignment: MainAxisAlignment.center,
                    )
                  : new Center(
                      child: const Center(
                          child: const CircularProgressIndicator())),
            )),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: new Card(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: bufferAggroMode != null
                  ? new Column(
                      children: <Widget>[
                        new Text(
                          'Buffer Aggresiveness',
                          style: _headingFont,
                        ),
                        new Text(
                          'How aggressive should we be in using the battery? The more aggressive, the more the battery will be used in standalone mode',
                          textAlign: TextAlign.center,
                        ),
                        new DropdownButton(
                          items: bufferAggressivenessOptions
                              .map((String bufferAggressiveness) {
                            return new DropdownMenuItem<String>(
                                child: Text(bufferAggressiveness),
                                value: bufferAggressiveness);
                          }).toList(),
                          onChanged: bufferAggressivenessChanged,
                          value: bufferAggroMode,
                        ),
                        new Text(
                          'Note: This mode will only work during Standalone: PV with Battery Backup mode',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : new Center(
                      child: const Center(
                          child: const CircularProgressIndicator())),
            )),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: new Card(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: authenticationRequired != null
                  ? new Column(
                      children: <Widget>[
                        new Text(
                          'Authentication Requirements',
                          style: _headingFont,
                        ),
                        new Text(
                          'Will the solar charger require a RFID card authentication?',
                          textAlign: TextAlign.center,
                        ),
                        new DropdownButton(
                          items: authenticationRequiredOptions.keys
                              .toList()
                              .map((String authenticationRequirement) {
                            return new DropdownMenuItem<String>(
                                child: Text(authenticationRequirement),
                                value: authenticationRequiredOptions[
                                    authenticationRequirement]);
                          }).toList(),
                          onChanged: authenticationRequiredChanged,
                          value: authenticationRequired,
                        ),
                      ],
                    )
                  : new Center(
                      child: const Center(
                          child: const CircularProgressIndicator())),
            )),
          ),
          new Divider(color: Colors.black),
          new Padding(
            padding: const EdgeInsets.all(6.0),
            child: new Card(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: new Column(
                children: <Widget>[
                  new Text(
                    'Firmware Updates',
                    style: _headingFont,
                  ),
                  new Padding(
                      padding: const EdgeInsets.all(15),
                      child: !checkingForUpdates
                          ? firmwareWidget
                          : new Padding(
                              child: new Center(
                                  child: const Center(
                                      child:
                                          const CircularProgressIndicator())),
                              padding: const EdgeInsets.all(10),
                            ))
                ],
              ),
            )),
          ),
          new Padding(
            padding: const EdgeInsets.all(6.0),
            child: new Card(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: new Column(
                children: <Widget>[
                  new Text(
                    'Factory Reset',
                    style: _headingFont,
                  ),
                  new Padding(
                      padding: const EdgeInsets.all(15),
                      child: !checkingForUpdates
                          ? new RaisedButton(
                              onPressed: () {
                                showModalBottomSheet(
                                    context: context,
                                    builder: (builder) {
                                      return new FactoryReset();
                                    });
                              },
                              child: const Text("Perform a factory reset"),
                            )
                          : new Padding(
                              child: new Center(
                                  child: const Center(
                                      child:
                                          const CircularProgressIndicator())),
                              padding: const EdgeInsets.all(10),
                            ))
                ],
              ),
            )),
          )
        ],
      )),
    );
  }

  void updateDSCFirmware(uid, currentVersion) {
    // Todo: hasn't been tested yet

    checkingForUpdates = true;
    setState(() {});

    /// 1) First send a Firebase message to do the firmware update
    database
        .reference()
        .child('users/$uid/evc_inputs/')
        .update({'dsc_firmware_update': true});

    /// 2) Then start a listener and listen for ranges in current version
    _versionSubscription = database
        .reference()
        .child('users/$uid/version')
        .onValue
        .listen((Event event) {
      if (event.snapshot.value != currentVersion) {
        /// If the version is now different, we display it on the UI
        firmwareWidget = new Column(
          children: <Widget>[
            new Text('Current version: v${event.snapshot.value}'),
            new Padding(padding: const EdgeInsets.only(top: 10)),
            const Text('No update available')
          ],
        );
        checkingForUpdates = false;
        setState(() {});
      }
    });
  }

  checkForUpdates() async {
    /// This function checks for updates

    checkingForUpdates = true;
    setState(() {});

    /// Get the latest version number
    DataSnapshot latestVersionNumber =
        await database.reference().child('version').once();

    /// Get the version number of the solar charger
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    DataSnapshot versionNumber =
        await database.reference().child('users/${user.uid}/version').once();

    if (latestVersionNumber.value > versionNumber.value) {
      print('Update is available!');

      firmwareWidget = new Column(
        children: <Widget>[
          new Text('Current version: v${versionNumber.value}'),
          new FlatButton(
              onPressed: () {
                updateDSCFirmware(user.uid, versionNumber.value);
              },
              child: new Text(
                  'Update to v${latestVersionNumber.value} available. Click to continue'))
        ],
      );
    } else {
      firmwareWidget = new Column(
        children: <Widget>[
          new Text('Current version: v${versionNumber.value}'),
          new Padding(padding: const EdgeInsets.only(top: 10)),
          const Text('No update available')
        ],
      );
      print('No updates available');
    }

    checkingForUpdates = false;
    setState(() {});
  }

  authenticationRequiredChanged(newAuthenticationRequirement) {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      database
          .reference()
          .child('users/${user.uid}/evc_inputs/charging_modes')
          .update({'authentication_required': newAuthenticationRequirement});
    });

    setState(() {
      authenticationRequired = newAuthenticationRequirement;
    });
  }

  bufferAggressivenessChanged(newBufferAggressiveness) {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      database
          .reference()
          .child('users/${user.uid}/evc_inputs/')
          .update({'buffer_aggro_mode': newBufferAggressiveness});
    });

    setState(() {
      bufferAggroMode = newBufferAggressiveness;
    });
  }

  chargingModeChanged(newChargingMode) {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      database
          .reference()
          .child('users/${user.uid}/evc_inputs/charging_modes/')
          .update({'single_charging_mode': newChargingMode});
    });

    setState(() {
      singleChargingMode = newChargingMode;
    });
  }

  getEVInputs(app) async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    String uid = user.uid;

    _singleChargingModeSubscription = database
        .reference()
        .child('users/$uid/evc_inputs/charging_modes/single_charging_mode')
        .onValue
        .listen((Event event) {
      singleChargingMode = event.snapshot.value;
      setState(() {
        print(singleChargingMode);
      });
    });

    _bufferAggroModeSubscription = database
        .reference()
        .child('users/$uid/evc_inputs/buffer_aggro_mode')
        .onValue
        .listen((Event event) {
      bufferAggroMode = event.snapshot.value;
      setState(() {
        print(bufferAggroMode);
      });
    });

    _authenticationRequiredSubscription = database
        .reference()
        .child('users/$uid/evc_inputs/charging_modes/authentication_required')
        .onValue
        .listen((Event event) {
      authenticationRequired = event.snapshot.value.toString();
      setState(() {
        print(authenticationRequired);
      });
    });

    firmwareWidget = new RaisedButton(
      onPressed: () {
        checkForUpdates();
      },
      child: const Text("Check for Solar Charger firmware updates"),
    );
    setState(() {});
  }

  getUserDetails() {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      setState(() {
        _displayName = user.displayName;
        _displayEmail = user.email;
      });
    });
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  @override
  void initState() {
    super.initState();

    getUserDetails();

    main().then((FirebaseApp app) {
      database = new FirebaseDatabase(app: app);
      getEVInputs(app);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _singleChargingModeSubscription.cancel();
    _bufferAggroModeSubscription.cancel();
    _authenticationRequiredSubscription.cancel();
    _versionSubscription.cancel();

    print('disposed');
  }
}

class FactoryReset extends StatefulWidget {
  @override
  _FactoryResetState createState() => _FactoryResetState();
}

class _FactoryResetState extends State<FactoryReset> {
  bool showLoginPrompt = false;
  bool loggingIn = false;

  final TextEditingController _email = new TextEditingController();
  final TextEditingController _pass = new TextEditingController();

  UserData user = new UserData();
  UserAuth userAuth = new UserAuth();

  String get email => _email.text;

  String get password => _pass.text;

  @override
  Widget build(BuildContext context) {
    return loggingIn
        ? const Center(child: const CircularProgressIndicator())
        : new Container(
            height: MediaQuery.of(context).size.height / 2.5,
            child: showLoginPrompt
                ? new Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                        new Padding(
                          padding: const EdgeInsets.all(15),
                          child: new Text("Please Re-enter Your Credentials",
                              style: const TextStyle(fontSize: 20.0)),
                        ),
                        new ListTile(
                            leading: const Icon(Icons.email),
                            title: new TextField(
                              controller: _email,
                              decoration:
                                  new InputDecoration(hintText: "Email"),
                            )),
                        new ListTile(
                            leading: const Icon(Icons.lock),
                            title: new TextField(
                              controller: _pass,
                              decoration:
                                  new InputDecoration(hintText: "Password"),
                              obscureText: true,
                            )),
                        new Padding(
                          padding: const EdgeInsets.all(15.0),
                        ),
                        new RaisedButton(
                          child: new Text("Login"),
                          onPressed: () {
                            _handleLogin();
                          },
//                    padding: const EdgeInsets.only(top: 1.0),
                        ),
                      ])
                : new Padding(
                    padding: const EdgeInsets.all(15),
                    child: new Column(children: <Widget>[
                      new Text(
                        'Are you sure you want to factory reset your Delta Solar Charger? This will remove ALL data associated with your account',
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      new Expanded(
                          child: new Align(
                        child: new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            new RaisedButton(
//                                                    color: Colors.red,
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'No',
                              ),
                            ),
                            new RaisedButton(
                              color: Colors.red,
                              onPressed: () {
                                setState(() {
                                  showLoginPrompt = true;
                                });
                              },
                              child: const Text(
                                'Yes',
                              ),
                            )
                          ],
                        ),
                        alignment: Alignment.bottomCenter,
                      )),
                    ]),
                  ),
          );
  }

  void _handleLogin() {
    // Set loggingIn to true, so we have a circular progress icon
    setState(() {
      loggingIn = true;
    });

    user.email = email;
    user.password = password;

    userAuth.verifyUser(user).then((onValue) {
      print(onValue);
      if (onValue == "Login Successful") {
        loggingIn = false;
        print('success!');
        setState(() {});
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
                          loggingIn = false;
                        });
                      },
                      child: Text('Try Again'))
                ],
              );
            });
      }
    });
  }
}
