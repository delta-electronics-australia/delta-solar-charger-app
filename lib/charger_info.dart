import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/solarChargerSettings.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/inverter_archive.dart';


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

class ChargerInfo extends StatefulWidget {
  @override
  _ChargerInfoState createState() => _ChargerInfoState();
}

class _ChargerInfoState extends State<ChargerInfo> {
  FirebaseApp app;
  List evChargerList = [];

  /// Initialize the strings that will define our display name and email
  String _displayName = "";
  String _displayEmail = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
          title: const Text('Connected Chargers'),
        ),
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
              Navigator.of(context).popUntil(ModalRoute.withName('/Dashboard'));
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
              Navigator.of(context).pop();
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
        body: new OrientationBuilder(builder: (context, orientation) {
          return GridView.count(
            crossAxisCount: 2,
            children: getChargerCards(),
            childAspectRatio: orientation == Orientation.portrait ? 2 / 3 : 1,
          );
        })
//        ListView.builder(
//            shrinkWrap: true,
//            itemCount: evChargerList.length,
//            itemBuilder: (context, index) {
//              return new ChargerCard(
//                chargerID: evChargerList[index],
//                app: app,
//              );
//            })
        );
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  List<Widget> getChargerCards() {
    List<Widget> chargerCardList = [];

    for (String chargerID in evChargerList) {
      chargerCardList.add(new ChargerCard(chargerID: chargerID, app: app));
    }

    return chargerCardList;
  }

  void grabConnectedChargers() async {
    /// This function will grab all of our registered chargers
    ///
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;

    /// Get all registered chargers and put them into a list
    database
        .reference()
        .child('users/$uid/ev_chargers')
        .once()
        .then((DataSnapshot snapshot) {
      evChargerList = snapshot.value.keys.toList();

      setState(() {});
    });
  }

  void getUserDetails() {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      setState(() {
        _displayName = user.displayName;
        _displayEmail = user.email;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    getUserDetails();

    main().then((FirebaseApp firebaseApp) {
      app = firebaseApp;
      grabConnectedChargers();
    });
  }
}

class ChargerCard extends StatefulWidget {
  ChargerCard({
    Key key,
    @required this.chargerID,
    @required this.app,
  }) : super(key: key);

  final chargerID;
  final FirebaseApp app;

  @override
  _ChargerCardState createState() => _ChargerCardState();
}

class _ChargerCardState extends State<ChargerCard> {
  bool loadingData = true;

  String chargerModel = '';

  bool chargerOnline = false;

  @override
  Widget build(BuildContext context) {
    return loadingData
        ? const Center(
            child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: const CircularProgressIndicator(),
          ))
        : new GestureDetector(
            child: new Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: new Column(children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: new Row(
                      children: <Widget>[
                        new Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: new Container(
                            child: new Material(
                              color: chargerOnline ? Colors.green : Colors.red,
                              type: MaterialType.circle,
                              child: new Container(
                                width: 12,
                                height: 12,
                                child: InkWell(),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${widget.chargerID}',
//                    textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        )
                      ],
                      mainAxisAlignment: MainAxisAlignment.center,
                    ),
                  ),

                  /// Now get the image of the relevant charger
                  getChargerImage(),
                ]),
              ),
            ),
            onTap: () {
              print(widget.chargerID);
              showModalBottomSheet(
                  context: context,
                  builder: (builder) {
                    return new ChargerInfoModal(
                        chargerID: widget.chargerID, app: widget.app);
                  });
            },
          );
  }

  Widget getChargerImage() {
    if (chargerModel.startsWith('EVPE')) {
      chargerModel = 'acminiplus';
    }

    if (chargerOnline) {
      return new Flexible(
        child: new Image.asset('assets/img/ACMP/$chargerModel.png'),
        fit: FlexFit.tight,
      );
    } else {
      return new Flexible(
        child: new Image.asset('assets/img/ACMP/${chargerModel}_faded.png'),
        fit: FlexFit.tight,
      );
    }
  }

  void startChargerInfoListener() async {
    /// For each charger, we need to listen to any changes in status

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: widget.app);
    String uid = user.uid;

    /// Start an onValue listener and update UI every time information changes
    database
        .reference()
        .child('users/$uid/evc_inputs/${widget.chargerID}')
        .onValue
        .listen((Event event) {
      chargerModel = event.snapshot.value['charger_info']['chargePointModel'];
      chargerOnline = event.snapshot.value['alive'];

      loadingData = false;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    startChargerInfoListener();
  }
}

class ChargerInfoModal extends StatefulWidget {
  ChargerInfoModal({Key key, @required this.chargerID, @required this.app})
      : super(key: key);

  final String chargerID;
  final FirebaseApp app;

  @override
  _ChargerInfoModalState createState() => _ChargerInfoModalState();
}

class _ChargerInfoModalState extends State<ChargerInfoModal> {
  bool loadingData = true;

  Map chargerInfo = {};

  bool chargerOnline = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: loadingData
          ? new Center(
              child: const Center(child: const CircularProgressIndicator()))
          : new ListView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[
                new Padding(
                  padding: const EdgeInsets.all(8),
                  child: new Row(
                    children: <Widget>[
                      new Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: new Container(
                          child: new Material(
                            color: chargerOnline ? Colors.green : Colors.red,
                            type: MaterialType.circle,
                            child: new Container(
                              width: 16,
                              height: 16,
                              child: InkWell(),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '${widget.chargerID}',
//                    textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      )
                    ],
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                ),
                new ListTile(
                  title: const Text('Charger Vendor'),
                  trailing: new Text(chargerInfo['chargePointVendor']),
                ),
                new ListTile(
                  title: const Text('Charger Model'),
                  trailing: new Text(chargerInfo['chargePointModel']),
                ),
                new ListTile(
                  title: const Text('Charger Serial'),
                  trailing: new Text(chargerInfo['chargePointSerialNumber']),
                ),
                new ListTile(
                  title: const Text('Charger FW Version'),
                  trailing: new Text(chargerInfo['firmwareVersion']),
                ),
              ],
            ),
    );
  }

  void startChargerInfoListener() async {
    /// For each charger, we need to listen to any changes in status

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: widget.app);
    String uid = user.uid;

    /// Start an onValue listener and update UI every time information changes
    database
        .reference()
        .child('users/$uid/evc_inputs/${widget.chargerID}')
        .onValue
        .listen((Event event) {
      chargerInfo = event.snapshot.value['charger_info'];
      chargerOnline = event.snapshot.value['alive'];

      loadingData = false;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    startChargerInfoListener();
  }
}
