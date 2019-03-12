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

class SolarChargerSettings extends StatelessWidget {
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
                  builder: (BuildContext context) =>
                      new SolarChargerSettings());
              Navigator.of(context).pop();
              Navigator.of(context).push(route);
            },
          ),
          Divider(),
          ListTile(
            title: Text('Sign Out'),
            onTap: () {
              _signOut(context);
            },
          ),
        ])),
        body: new ListView(
          children: <Widget>[
            new ListTile(
              title: const Text('Charging Mode'),
              leading: const Icon(Icons.battery_charging_full),
              subtitle: const Text('Adjust EV Charging behaviour'),
              onTap: () {
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) => new ChargingModePage());
                Navigator.of(context).push(route);
              },
            ),
            new ListTile(
              title: const Text('Buffer Aggressiveness'),
              leading: const Icon(Icons.battery_unknown),
              subtitle: const Text('Control stationary battery usage'),
              onTap: () {
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) =>
                        new BufferAggressivenessPage());
                Navigator.of(context).push(route);
              },
            ),
            new ListTile(
              title: const Text('Charging Authentication'),
              leading: const Icon(Icons.lock),
              subtitle:
                  const Text('Change charging authentication requirements'),
              onTap: () {
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) =>
                        new ChargingAuthenticationPage());
                Navigator.of(context).push(route);
              },
            ),
            new Divider(),
            new ListTile(
              title: const Text('User Settings'),
              leading: const Icon(Icons.person),
              subtitle: const Text('Change your password, display name'),
              onTap: () {
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) => new UserSettingsPage());
                Navigator.of(context).push(route);
              },
            ),
            new ListTile(
              title: const Text('System Name'),
              leading: const Icon(Icons.contacts),
              subtitle: const Text('Change the system name'),
              onTap: () {
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) => new SystemNamePage());
                Navigator.of(context).push(route);
              },
            ),
            new Divider(),
            new ListTile(
              title: const Text('Connection Settings'),
              leading: const Icon(Icons.settings_ethernet),
              subtitle: const Text(
                  'Change how the Delta Solar Charger connects to the Internet'),
              isThreeLine: true,
              onTap: () {
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) =>
                        new ConnectionSettingsPage());
                Navigator.of(context).push(route);
              },
            ),
            new Divider(),
            new ListTile(
              title: const Text('Firmware Updates'),
              leading: const Icon(Icons.system_update),
              subtitle: const Text('Search for firmware updates'),
              onTap: () {
                var route = new MaterialPageRoute(
                    builder: (BuildContext context) =>
                        new UpdateFirmwarePage());
                Navigator.of(context).push(route);
              },
            ),
            new ListTile(
              title: const Text('Factory Reset'),
              leading: const Icon(Icons.restore),
              subtitle: const Text('Reset your Delta Solar Charger'),
            ),
          ],
        ));
  }

  Future<Null> _signOut(context) async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
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

class ChargingModePage extends StatefulWidget {
  @override
  _ChargingModePageState createState() => _ChargingModePageState();
}

class _ChargingModePageState extends State<ChargingModePage> {
  String singleChargingMode;

  StreamSubscription _singleChargingModeSubscription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charging Mode'),
      ),
      body: new ListView(
        children: <Widget>[
          new ListTile(
            leading: new Radio(
              groupValue: singleChargingMode,
              value: 'PV_with_BT',
              onChanged: _handleChargingModeChange,
            ),
            title: const Text('Solar Tracking Mode'),
            subtitle: const Text(
                'Intelligently adjust the charge rate based on the solar available'),
            isThreeLine: true,
            onTap: () {
              _handleChargingModeChange('PV_with_BT');
            },
          ),
          new ListTile(
            leading: new Radio(
              groupValue: singleChargingMode,
              value: 'MAX_CHARGE_STANDALONE',
              onChanged: _handleChargingModeChange,
            ),
            title: const Text('Maximise Standalone Power Mode'),
            subtitle: const Text(
                'Use as much solar and battery power as possible to charge the car'),
            isThreeLine: true,
            onTap: () {
              _handleChargingModeChange('MAX_CHARGE_STANDALONE');
            },
          ),
          new ListTile(
            leading: new Radio(
              groupValue: singleChargingMode,
              value: 'MAX_CHARGE_GRID',
              onChanged: _handleChargingModeChange,
            ),
            title: const Text('Quick Charge Mode'),
            subtitle: const Text(
                'Charge at the maximum rate possible no matter the cost'),
            isThreeLine: true,
            onTap: () {
              _handleChargingModeChange('MAX_CHARGE_GRID');
            },
          ),
        ],
      ),
    );
  }

  _handleChargingModeChange(String newChargingMode) {
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging_modes/')
        .update({'single_charging_mode': newChargingMode});

    setState(() {});
  }

  startChargeModeListener() async {
    _singleChargingModeSubscription = globals.database
        .reference()
        .child(
            'users/${globals.uid}/evc_inputs/charging_modes/single_charging_mode')
        .onValue
        .listen((Event event) {
      singleChargingMode = event.snapshot.value;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    startChargeModeListener();
  }

  @override
  void dispose() {
    super.dispose();
    _singleChargingModeSubscription.cancel();
  }
}

class BufferAggressivenessPage extends StatefulWidget {
  @override
  _BufferAggressivenessPageState createState() =>
      _BufferAggressivenessPageState();
}

class _BufferAggressivenessPageState extends State<BufferAggressivenessPage> {
  String bufferAggroMode;

  StreamSubscription _bufferAggroModeSubscription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charging Authentication'),
      ),
      body: new ListView(
        children: <Widget>[
          new ListTile(
            leading: new Radio(
              groupValue: bufferAggroMode,
              value: 'Aggressive',
              onChanged: _handleBufferAggressivenessChange,
            ),
            title: const Text('Aggressive Battery Use'),
            subtitle: const Text('Use an aggressive battery profile'),
            onTap: () {
              _handleBufferAggressivenessChange('Aggressive');
            },
          ),
          new ListTile(
            leading: new Radio(
              groupValue: bufferAggroMode,
              value: 'Balanced',
              onChanged: _handleBufferAggressivenessChange,
            ),
            title: const Text('Balanced Battery Use'),
            subtitle: const Text('Use a balanced battery profile'),
            onTap: () {
              _handleBufferAggressivenessChange('Balanced');
            },
          ),
          new ListTile(
            leading: new Radio(
              groupValue: bufferAggroMode,
              value: 'Conservative',
              onChanged: _handleBufferAggressivenessChange,
            ),
            title: const Text('Conservative Battery Use'),
            subtitle: const Text('Use a conservative battery profile'),
            onTap: () {
              _handleBufferAggressivenessChange('Conservative');
            },
          ),
        ],
      ),
    );
  }

  _handleBufferAggressivenessChange(newBufferAggressiveness) {
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/')
        .update({'buffer_aggro_mode': newBufferAggressiveness});

    setState(() {});
  }

  startBufferAggressivenessListener() {
    _bufferAggroModeSubscription = globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/buffer_aggro_mode')
        .onValue
        .listen((Event event) {
      bufferAggroMode = event.snapshot.value;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    startBufferAggressivenessListener();
  }

  @override
  void dispose() {
    super.dispose();
    _bufferAggroModeSubscription.cancel();
  }
}

class ChargingAuthenticationPage extends StatefulWidget {
  @override
  _ChargingAuthenticationPageState createState() =>
      _ChargingAuthenticationPageState();
}

class _ChargingAuthenticationPageState
    extends State<ChargingAuthenticationPage> {
  String authenticationRequired;

  StreamSubscription _authenticationRequiredSubscription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charging Authentication'),
      ),
      body: new ListView(
        children: <Widget>[
          new ListTile(
            leading: new Radio(
              groupValue: authenticationRequired,
              value: 'true',
              onChanged: _handleAuthenticationRequiredChange,
            ),
            title: const Text('RFID Swipe Required'),
            subtitle: const Text(
                'Users need to swipe an RFID card to start a charge session'),
            isThreeLine: true,
            onTap: () {
              _handleAuthenticationRequiredChange('true');
            },
          ),
          new ListTile(
            leading: new Radio(
              groupValue: authenticationRequired,
              value: 'false',
              onChanged: _handleAuthenticationRequiredChange,
            ),
            title: const Text('RFID Swipe Not Required'),
            subtitle: const Text(
                'The Delta Solar Charger will start charging as soon as a car is plugged in'),
            isThreeLine: true,
            onTap: () {
              _handleAuthenticationRequiredChange('false');
            },
          ),
        ],
      ),
    );
  }

  _handleAuthenticationRequiredChange(newAuthenticationRequirement) {
    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging_modes')
        .update({'authentication_required': newAuthenticationRequirement});

    setState(() {});
  }

  startAuthenticationRequiredListener() {
    _authenticationRequiredSubscription = globals.database
        .reference()
        .child(
            'users/${globals.uid}/evc_inputs/charging_modes/authentication_required')
        .onValue
        .listen((Event event) {
      authenticationRequired = event.snapshot.value.toString();
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    startAuthenticationRequiredListener();
  }

  @override
  void dispose() {
    super.dispose();
    _authenticationRequiredSubscription.cancel();
  }
}

class UserSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('User Settings'),
      ),
      body: new ListView(
        children: <Widget>[
          new ListTile(
            title: const Text('Change Display Name'),
            onTap: () {
              showDialog(
                  context: context,
                  builder: (builder) {
                    return new ChangeDisplayNameDialog();
                  });
            },
          ),
          new ListTile(
            title: const Text('Change Password'),
            onTap: () {
              showDialog(
                  context: context,
                  builder: (builder) {
                    return new ChangePasswordDialog();
                  });
            },
          )
        ],
      ),
    );
  }
}

class ChangeDisplayNameDialog extends StatefulWidget {
  @override
  _ChangeDisplayNameDialogState createState() =>
      _ChangeDisplayNameDialogState();
}

class _ChangeDisplayNameDialogState extends State<ChangeDisplayNameDialog> {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Change Display Name'),
      children: <Widget>[
        const Text(
          'Functionality currently not available',
          textAlign: TextAlign.center,
        )
      ],
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  @override
  _ChangePasswordDialogState createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _oldPass = new TextEditingController();
  final TextEditingController _newPass = new TextEditingController();
  final TextEditingController _confirmNewPass = new TextEditingController();

  UserAuth userAuth = new UserAuth();

  String get oldPassword => _oldPass.text;

  String get newPassword => _newPass.text;

  String get confirmNewPassword => _confirmNewPass.text;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Change Password'),
      children: <Widget>[
        const Text(
          'Functionality currently not available',
          textAlign: TextAlign.center,
        )
//        new ListTile(
//          leading: const Text('Old Password:'),
//            title: new TextField(
//          controller: _oldPass,
//          decoration: new InputDecoration(),
//          obscureText: true,
//        )),
//        new ListTile(
//            leading: const Text('New Password:'),
//            title: new TextField(
//          controller: _newPass,
//          decoration: new InputDecoration(hintText: "New Password"),
//          obscureText: true,
//        )),
//        new ListTile(
//            leading: const Text('Confirm Password:'),
//            title: new TextField(
//          controller: _confirmNewPass,
//          decoration: new InputDecoration(hintText: "Confirm New Password"),
//          obscureText: true,
//        )),
//        new Padding(
//          padding: const EdgeInsets.all(15.0),
//          child: new RaisedButton(
//            child: new Text("Change Password"),
//            onPressed: changePasswordButtonPressed,
//          ),
//        ),
      ],
    );
  }

  void changePasswordButtonPressed() {
    /// First we need to check if our original password is correct
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      /// First get the
      String email = user.email;
    });
  }

  void checkIfPWChangeAllowed() async {
    /// This function will check if we are allowed to change the password
  }

  @override
  void initState() {
    super.initState();
    checkIfPWChangeAllowed();
  }
}

class SystemNamePage extends StatefulWidget {
  @override
  _SystemNamePageState createState() => _SystemNamePageState();
}

class _SystemNamePageState extends State<SystemNamePage> {
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
      appBar: new AppBar(
        title: const Text('System Name'),
      ),
      body: new Column(
        children: <Widget>[
          Padding(
            key: new ObjectKey('systemName'),
            padding: const EdgeInsets.only(top: 10.0),
            child: new Text(
              'The current system name is: $currentSystemName',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          new ListTile(
              title: new TextField(
            controller: _nameController,
            decoration:
                new InputDecoration(hintText: "Enter a new system name"),
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
    );
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

  @override
  void initState() {
    super.initState();
    getCurrentSystemName();
  }
}

class ConnectionSettingsPage extends StatefulWidget {
  @override
  _ConnectionSettingsPageState createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  String connectionMethod;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Connection Settings'),
      ),
      body: new Column(
        children: <Widget>[
          new ListTile(
            leading: new Radio(
              groupValue: connectionMethod,
              value: 'none',
              onChanged: _handleConnectionMethodChange,
            ),
            title: const Text('Run Solar Charger Offline'),
            subtitle: const Text(
                'The Delta Solar Charger will run completely offline. Users will no longer have access to the app and web interface'),
            isThreeLine: true,
            onTap: () {
              _handleConnectionMethodChange('none');
            },
          ),
          new ListTile(
            leading: new Radio(
              groupValue: connectionMethod,
              value: 'ethernet',
              onChanged: _handleConnectionMethodChange,
            ),
            title: const Text('Ethernet Connection'),
            subtitle: const Text(
                'The Delta Solar Charger will use an ethernet connection to connect to the internet'),
            isThreeLine: true,
            onTap: () {
              _handleConnectionMethodChange('ethernet');
            },
          ),
          new ListTile(
            leading: new Radio(
              groupValue: connectionMethod,
              value: '3G',
              onChanged: _handleConnectionMethodChange,
            ),
            title: const Text('3G/4G Connection'),
            subtitle: const Text(
                'The Delta Solar Charger will use a 3G connection to connect to the internet'),
            isThreeLine: true,
            onTap: () {
              _handleConnectionMethodChange('3G');
            },
          ),
          new Expanded(
              child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: new Align(
              alignment: Alignment.bottomRight,
              child: new RaisedButton(
                onPressed: null,
                child: const Text('Confirm new connection method'),
              ),
            ),
          ))
        ],
      ),
    );
  }

  _handleConnectionMethodChange(String newConnectionMethod) {
    print(newConnectionMethod);
    connectionMethod = newConnectionMethod;
    setState(() {});
  }
}

class UpdateFirmwarePage extends StatefulWidget {
  @override
  _UpdateFirmwarePageState createState() => _UpdateFirmwarePageState();
}

class _UpdateFirmwarePageState extends State<UpdateFirmwarePage> {
  bool checkingForUpdates = true;

  num currentVersion;

  Widget firmwareStatusTitle = const Text('Checking for updates');
  Widget firmwareStatusList;
  Widget multiPurposeFirmwareButton;

  StreamSubscription _versionSubscription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: new AppBar(
        title: const Text('Firmware Updates'),
      ),
      body: new Column(
        children: <Widget>[
          /// First show a system update logo
          Center(
            child: new SizedBox(
                height: MediaQuery.of(context).size.height / 7,
                child: new Icon(
                  Icons.system_update,
                  size: MediaQuery.of(context).size.width / 6,
                )),
          ),

          /// firmwareStatusTitle will be the text at the top that tells us the
          /// status of the current firmware
          firmwareStatusTitle,

          /// Now either show a progress indicator or a list of firmware info
          checkingForUpdates
              ? new Expanded(
                  child: new Center(
                      child: const Center(
                          child: const CircularProgressIndicator())),
                )
              : new Expanded(child: firmwareStatusList),

          /// At the bottom of the page, we show nothing if we are checking for
          /// updates but show a customized button if we are not checking
          new Expanded(
              child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Align(
                child: checkingForUpdates
                    ? new Container()
                    : multiPurposeFirmwareButton,
                alignment: Alignment.bottomRight),
          ))
        ],
      ),
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

        checkForUpdates();
      }
    });
  }

  void checkForUpdates() async {
    checkingForUpdates = true;
    firmwareStatusTitle = const Text(
      'Checking for updates',
      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
    );
    setState(() {});

    /// Get the latest version number
    DataSnapshot latestVersionNumber =
        await globals.database.reference().child('version').once();

    /// Get the version number of the solar charger
    DataSnapshot versionNumber = await globals.database
        .reference()
        .child('users/${globals.uid}/version')
        .once();

    print(latestVersionNumber.value);
    print(versionNumber.value);
    if (latestVersionNumber.value > versionNumber.value) {
      /// Update our firmwareStatusTitle
      firmwareStatusTitle = const Text(
        'Firmware Update Available',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      );

      /// Update the firmware button
      multiPurposeFirmwareButton = new RaisedButton(
        onPressed: () {
          updateDSCFirmware(globals.uid, versionNumber.value);
        },
        child: const Text('Perform Firmware Update'),
      );

      firmwareStatusList = new ListView(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: <Widget>[
          new ListTile(
            title: new Text(
                'Current Delta Solar Charger version: ${versionNumber.value}'),
          ),
          new ListTile(
            title: new Text(
                'Latest Delta Solar Charger version: ${latestVersionNumber.value}'),
          )
        ],
      );

      setState(() {});
    } else {
      print('No updates available');

      /// Assign our firmwareStatusTitle
      firmwareStatusTitle = new Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: const Text(
          'Your system is up to date',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      );

      /// Assign our firmwareStatusList
      firmwareStatusList = new ListTile(
          title:
              new Text('Delta Solar Charger version: ${versionNumber.value}'));

      multiPurposeFirmwareButton = new RaisedButton(
        onPressed: () {
          checkForUpdates();
        },
        child: const Text('Check for updates'),
      );
    }

    checkingForUpdates = false;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    checkForUpdates();
  }

  @override
  void dispose() {
    super.dispose();

    if (_versionSubscription != null) {
      _versionSubscription.cancel();
    }
  }
}
