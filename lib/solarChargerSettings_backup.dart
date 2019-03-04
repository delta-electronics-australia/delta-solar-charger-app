import 'package:flutter/material.dart';
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'globals.dart' as globals;

import 'package:smart_charging_app/authenticate.dart';
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/inverter_archive.dart';
import 'package:smart_charging_app/charger_info.dart';

import 'package:fluttertoast/fluttertoast.dart';

class SolarChargerSettings extends StatefulWidget {
  @override
  _SolarChargerSettingsState createState() => _SolarChargerSettingsState();
}

class _SolarChargerSettingsState extends State<SolarChargerSettings> {
  final _headingFont = const TextStyle(fontSize: 22.0);
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

  /// firmwareWidget is the widget that will show up in the firmware updates card
  Widget firmwareWidget;

  /// _nameController is the TextEditingController for setting the nickname of the system
  final TextEditingController _nameController = new TextEditingController();

  /// _nameButtonDisabled is the boolean to see if the submit name button
  /// should be enabled
  bool _nameButtonDisabled = true;

  String currentSystemName;

  String get name => _nameController.text;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: const Text('Delta Solar Charger Settings')),
      drawer: new Drawer(
          child: ListView(children: <Widget>[
            globals.isAdmin
                ? UserAccountsDrawerHeader(
              accountName:
              Text('Currently logged in as ${globals.systemName}'),
              decoration: new BoxDecoration(color: Colors.blue),
            )
                : UserAccountsDrawerHeader(
              accountName: Text(globals.displayName),
              accountEmail: Text(globals.displayEmail),
              decoration: new BoxDecoration(color: Colors.blue),
            ),
            globals.isAdmin
                ? ListView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.supervisor_account),
                  title: const Text('Admin Dashboard'),
                  onTap: () {
                    Navigator.popUntil(
                        context, ModalRoute.withName('/AdminDashboard'));
                  },
                ),
                new Divider()
              ],
            )
                : new Container(),
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
            Divider(),
            ListTile(
              title: Text('Sign Out'),
              onTap: _signOut,
            ),
          ])),
      body: new Center(
          child: new ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(3.0),
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
                padding: const EdgeInsets.all(3.0),
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
                padding: const EdgeInsets.all(3.0),
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
              new Padding(
                padding: const EdgeInsets.all(3.0),
                child: new Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: new Column(
                        children: <Widget>[
                          new Text(
                            'System Name',
                            style: _headingFont,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: new Text(
                              'This name will be used to identify the system',
                              style: null,
                            ),
                          ),
                          Padding(
                            key: new ObjectKey('systemName'),
                            padding: const EdgeInsets.only(top: 5.0),
                            child: new Text(
                              'The current system name is: $currentSystemName',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          new ListTile(
                              title: new TextField(
                                controller: _nameController,
                                decoration: new InputDecoration(
                                    hintText: "Enter a new system name"),
                                onChanged: (text) {
                                  if (text == "") {
                                    _nameButtonDisabled = true;
                                  } else {
                                    _nameButtonDisabled = false;
                                  }
                                  setState(() {});
                                },
                              )),
                          new RaisedButton(
                            onPressed: _nameButtonDisabled
                                ? null
                                : () {
                              _submitNameButtonPressed();
                            },
                            child: const Text('Submit new name'),
                          )
                        ],
                      ),
                    )),
              ),
              new Divider(color: Colors.black),
              new Padding(
                padding: const EdgeInsets.all(3.0),
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
                padding: const EdgeInsets.all(3.0),
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
                                  showDialog(
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
    checkingForUpdates = true;
    setState(() {});

    /// 1) First send a Firebase message to do the firmware update
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/')
        .update({'dsc_firmware_update': true});

    /// 2) Then start a listener and listen for ranges in current version
    _versionSubscription = globals.database
        .reference()
        .child('users/${globals.uid}/version')
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

  void checkForUpdates() async {
    /// This function checks for updates

    checkingForUpdates = true;
    setState(() {});

    /// Get the latest version number
    DataSnapshot latestVersionNumber =
    await globals.database.reference().child('version').once();

    /// Get the version number of the solar charger
    DataSnapshot versionNumber = await globals.database
        .reference()
        .child('users/${globals.uid}/version')
        .once();

    if (latestVersionNumber.value > versionNumber.value) {
      print('Update is available!');

      firmwareWidget = new Column(
        children: <Widget>[
          new Text('Current version: v${versionNumber.value}'),
          new FlatButton(
              onPressed: () {
                updateDSCFirmware(globals.uid, versionNumber.value);
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

  void _submitNameButtonPressed() async {
    FocusScope.of(context).requestFocus(new FocusNode());

    globals.database
        .reference()
        .child('users')
        .child(globals.uid)
        .child('user_info')
        .update({'nickname': name});

    _nameController.clear();
    Fluttertoast.showToast(msg: 'System name changed!');
  }

  void getCurrentSystemName() async {
    globals.database
        .reference()
        .child('users')
        .child(globals.uid)
        .child('user_info')
        .child('nickname')
        .onValue
        .listen((Event event) {
      /// Todo: needs work
      DataSnapshot currentSystemNameSnapshot = event.snapshot;
      if (currentSystemNameSnapshot.value == null) {
        currentSystemName = 'No name currently set!';
      } else {
        print(currentSystemNameSnapshot.value);
        currentSystemName = currentSystemNameSnapshot.value;
      }

      setState(() {});
    });
  }

  void authenticationRequiredChanged(newAuthenticationRequirement) {
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging_modes')
        .update({'authentication_required': newAuthenticationRequirement});

    setState(() {
      authenticationRequired = newAuthenticationRequirement;
    });
  }

  void bufferAggressivenessChanged(newBufferAggressiveness) {
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/')
        .update({'buffer_aggro_mode': newBufferAggressiveness});

    setState(() {
      bufferAggroMode = newBufferAggressiveness;
    });
  }

  void chargingModeChanged(newChargingMode) {
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging_modes/')
        .update({'single_charging_mode': newChargingMode});

    setState(() {
      singleChargingMode = newChargingMode;
    });
  }

  void getEVInputs() async {
    _singleChargingModeSubscription = globals.database
        .reference()
        .child(
        'users/${globals.uid}/evc_inputs/charging_modes/single_charging_mode')
        .onValue
        .listen((Event event) {
      singleChargingMode = event.snapshot.value;
      setState(() {
        print(singleChargingMode);
      });
    });

    _bufferAggroModeSubscription = globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/buffer_aggro_mode')
        .onValue
        .listen((Event event) {
      bufferAggroMode = event.snapshot.value;
      setState(() {
        print(bufferAggroMode);
      });
    });

    _authenticationRequiredSubscription = globals.database
        .reference()
        .child(
        'users/${globals.uid}/evc_inputs/charging_modes/authentication_required')
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

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  @override
  void initState() {
    super.initState();

    getEVInputs();
    getCurrentSystemName();
  }

  @override
  void dispose() {
    super.dispose();
    _singleChargingModeSubscription.cancel();
    _bufferAggroModeSubscription.cancel();
    _authenticationRequiredSubscription.cancel();

    if (_versionSubscription != null) {
      _versionSubscription.cancel();
    }

    print('disposed');
  }
}

class FactoryReset extends StatefulWidget {
  @override
  _FactoryResetState createState() => _FactoryResetState();
}

class _FactoryResetState extends State<FactoryReset> {
  bool verifying = false;

  final TextEditingController _email = new TextEditingController();
  final TextEditingController _pass = new TextEditingController();

  UserData user = new UserData();
  UserAuth userAuth = new UserAuth();

  String get email => _email.text;

  String get password => _pass.text;

  @override
  Widget build(BuildContext context) {
    return new SimpleDialog(
      children: verifying
          ? <Widget>[
        new Center(
            child: const Center(child: const CircularProgressIndicator()))
      ]
          : <Widget>[
        new Padding(
          padding: const EdgeInsets.all(15),
          child: new Text("Please Re-enter Your Credentials",
              style: const TextStyle(fontSize: 20.0)),
        ),
        new ListTile(
            leading: const Icon(Icons.email),
            title: new TextField(
              controller: _email,
              decoration: new InputDecoration(hintText: "Email"),
            )),
        new ListTile(
            leading: const Icon(Icons.lock),
            title: new TextField(
              controller: _pass,
              decoration: new InputDecoration(hintText: "Password"),
              obscureText: true,
            )),
        new Padding(
          child: const Text(
            'Note that you will lose ALL of your information if you proceed. Are you sure you want to do this?',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          padding: const EdgeInsets.all(10),
        ),
        new Padding(
          padding: const EdgeInsets.all(15.0),
          child: new RaisedButton(
            child: new Text("Verify"),
            onPressed: () {
              _handleVerify();
            },
          ),
        ),
      ],
    );
  }

  void _handleVerify() {
    // Set loggingIn to true, so we have a circular progress icon
    setState(() {
      verifying = true;
    });

    user.email = email;
    user.password = password;

    userAuth.verifyUser(user).then((onValue) {
      print(onValue);
      if (onValue == "Login Successful") {
        verifying = false;
        print('success!');

        _performFactoryReset();
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
                          verifying = false;
                        });
                      },
                      child: Text('Try Again'))
                ],
              );
            });
      }
    });
  }

  void _performFactoryReset() async {
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/')
        .update({'factory_reset': true});

    _signOut();
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }
}
