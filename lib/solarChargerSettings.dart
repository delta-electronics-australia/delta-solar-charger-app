import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  bool checkingForUpdates = false;

  Widget firmwareWidget;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: const Text('Delta Solar Charger Settings')),
      body: new Center(
          child: new ListView(
        children: <Widget>[
//          new Padding(padding: const EdgeInsets.only(top: 15))
          new Card(
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
                          child: const CircularProgressIndicator()))),
          new Card(
              child: bufferAggroMode != null
                  ? new Column(
                      children: <Widget>[
                        new Text(
                          'Buffer Aggresiveness',
                          style: _headingFont,
                        ),
                        new Text(
                          'How aggressive should we be in using the battery? The more aggressive, the more the battery will be used in standalone mode',
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
                            'Note: This mode will only work during Standalone: PV with Battery Backup mode'),
                      ],
                    )
                  : new Center(
                      child: const Center(
                          child: const CircularProgressIndicator()))),
          new Card(
              child: authenticationRequired != null
                  ? new Column(
                      children: <Widget>[
                        new Text(
                          'Authentication Requirements',
                          style: _headingFont,
                        ),
                        new Text(
                            'Will the solar charger require a RFID card authentication?'),
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
                          child: const CircularProgressIndicator()))),
          new Card(
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
                      : new Center(
                          child: const Center(
                              child: const CircularProgressIndicator())))
            ],
          ))
        ],
      )),
    );
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
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) => new UpdateFirmware());
                Navigator.of(context).push(route);
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

  @override
  void initState() {
    super.initState();
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
    print('disposed');
  }
}

class UpdateFirmware extends StatefulWidget {
  @override
  _UpdateFirmwareState createState() => _UpdateFirmwareState();
}

class _UpdateFirmwareState extends State<UpdateFirmware> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: new Text('This is the update firmware page'),
    );
  }
}
