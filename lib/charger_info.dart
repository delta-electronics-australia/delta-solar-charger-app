import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:vibration/vibration.dart';

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
  List evChargerList = [];

  /// Initialize the strings that will define our display name and email
  String _displayName = "";
  String _displayEmail = "";

  List<Widget> chargerCardList = [];

  StreamSubscription _evChargersSubscription;

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
          Divider(),
          ListTile(
            title: Text('Sign Out'),
            onTap: _signOut,
          ),
        ])),
        body: new OrientationBuilder(builder: (context, orientation) {
          return GridView.count(
            crossAxisCount: 2,
            children: chargerCardList,
            childAspectRatio: orientation == Orientation.portrait ? 2 / 3 : 1,
          );
        }));
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  List<Widget> getChargerCards() {
    /// This function will get the cards that will contain the charger ID and an image
    List<Widget> chargerCardList = [];

    print('Im in getChargerCards!');

    /// Loop through the class list evChargerList
    for (String chargerID in evChargerList) {
      print('charger id coming: $chargerID');

      /// Now add the our custom ChargerCard widget into the chargerCardList
      /// Note that we are using an ObjectKey so Flutter knows which charger ID
      /// has been added or removed.
      chargerCardList.add(
          new ChargerCard(key: new ObjectKey(chargerID), chargerID: chargerID));
    }

    return chargerCardList;
  }

  void grabConnectedChargers() async {
    /// This function will be called as soon as the connected charger page is loaded
    /// It will start a listener on the ev_chargers node and callback when that node
    /// has changed

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    /// We listen for any changes in the ev chargers node
    _evChargersSubscription = database
        .reference()
        .child('users/$uid/ev_chargers')
        .onValue
        .listen((Event event) {
      DataSnapshot snapshot = event.snapshot;
      evChargerList = snapshot.value.keys.toList();

      print('New EV Charget node: $evChargerList');

      /// Only get our charger cards if there are no cards (first run)
      /// If the ev charger node changes, getChargerCards will be run in
      /// didUpdateWidget
      chargerCardList = getChargerCards();

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
    grabConnectedChargers();
  }

  @override
  void dispose() {
    super.dispose();
    _evChargersSubscription.cancel();
  }
}

class ChargerCard extends StatefulWidget {
  ChargerCard({
    Key key,
    @required this.chargerID,
  }) : super(key: key);

  final chargerID;

  @override
  _ChargerCardState createState() => _ChargerCardState();
}

class _ChargerCardState extends State<ChargerCard> {
  /// Initialize the boolean that tells us if we're loading data
  bool loadingData = true;

  /// Initialize the boolean that tells us if this charger is online or not
  bool chargerOnline = false;

  /// Initialize the string that holds the charger model
  String chargerModel = '';

  /// Initialize our charger info listener
  StreamSubscription _chargerInfoSubscription;

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
                    return new ChargerInfoModal(chargerID: widget.chargerID);
                  });
            },
            onLongPress: () {
              /// Vibrate the phone for 15ms
              Vibration.vibrate(duration: 15);

              showModalBottomSheet(
                  context: context,
                  builder: (builder) {
                    if (!chargerOnline) {
                      return DeleteChargerModal(
                        chargerID: widget.chargerID,
                      );
                    } else {
                      return new Padding(
                        child: const Text(
                          'Cannot delete charger, charger is still alive',
                          textAlign: TextAlign.center,
                        ),
                        padding: const EdgeInsets.all(10),
                      );
                    }
                  });
            },
          );
  }

  Widget getChargerImage() {
    String chargerModelName = '';

    print(
        'Getting charger image for $chargerModel with an online status of $chargerOnline');

    if (chargerModel != null) {
      if (chargerModel.startsWith('EVPE')) {
        chargerModelName = 'acminiplus';
      }
      if (chargerOnline) {
        return new Flexible(
          child: new Image.asset(
            'assets/img/ACMP/$chargerModelName.png',
            gaplessPlayback: true,
          ),
          fit: FlexFit.tight,
        );
      } else {
        return new Flexible(
          child: new Image.asset(
            'assets/img/ACMP/${chargerModelName}_faded.png',
            gaplessPlayback: true,
          ),
          fit: FlexFit.tight,
        );
      }
    } else {
      return new Flexible(
        child: new Image.asset(
          'assets/img/unknowncharger.png',
          gaplessPlayback: true,
        ),
        fit: FlexFit.tight,
      );
    }
  }

  void startChargerInfoListener() async {
    /// This is called as soon as the charger card is created.
    /// This function will to listen to any changes in status of the charger

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    /// Start an onValue listener for the charger's information and
    /// update the UI every time information changes
    _chargerInfoSubscription = database
        .reference()
        .child('users/$uid/evc_inputs/${widget.chargerID}')
        .onValue
        .listen((Event event) {
      /// First check if the charger ID node exists for the charger ID
      if (event.snapshot.value != null) {
        /// Now check if there is charger info for the charger ID
        if (event.snapshot.value['charger_info'] == null) {
          /// If there isn't any info, then set the chargerModel variable to null
          chargerModel = null;
        }

        /// If there IS charger info for this charger ID
        else {
          /// Then we assign the chargerModel variable to be the model listed
          /// in the info
          chargerModel =
              event.snapshot.value['charger_info']['chargePointModel'];
        }

        /// Also take the alive status in Firebase as the chargerOnline variable
        chargerOnline = event.snapshot.value['alive'];
      }

      /// If no node exists for the charger ID
      else {
        /// Set our model to null and our online status as false
        chargerModel = null;
        chargerOnline = false;
      }

      /// Now that we are done loading info, we can rebuild our card
      loadingData = false;

      if (mounted) {
        setState(() {
          print('${widget.chargerID} online status is: $chargerOnline');
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    print('Reached card initState for ${widget.chargerID}');
    startChargerInfoListener();
  }

  @override
  void dispose() {
    super.dispose();
    print('${widget.chargerID} card disposed');
    _chargerInfoSubscription.cancel();
  }
}

class ChargerInfoModal extends StatefulWidget {
  ChargerInfoModal({Key key, @required this.chargerID}) : super(key: key);

  final String chargerID;

  @override
  _ChargerInfoModalState createState() => _ChargerInfoModalState();
}

class _ChargerInfoModalState extends State<ChargerInfoModal> {
  bool loadingData = true;
  bool chargerOnline = false;

  /// Initialize the map that will hold all of the charger's information
  Map chargerInfo = {};

  StreamSubscription _chargingInfoSubscription;

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
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    /// Start an onValue listener and update UI every time information changes
    _chargingInfoSubscription = database
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

  @override
  void dispose() {
    super.dispose();
    _chargingInfoSubscription.cancel();
  }
}

class DeleteChargerModal extends StatefulWidget {
  DeleteChargerModal({Key key, @required this.chargerID})
      : super(key: key);

  final String chargerID;

  @override
  _DeleteChargerModalState createState() => _DeleteChargerModalState();
}

class _DeleteChargerModalState extends State<DeleteChargerModal> {
  bool deletingCharger = false;

  StreamSubscription _deleteChargerSubscription;

  @override
  Widget build(BuildContext context) {
    return deletingCharger
        ? new Center(
            child: const Center(child: const CircularProgressIndicator()))
        : ListView(
            shrinkWrap: true,
            children: <Widget>[
              new RaisedButton(
                  onPressed: () {
                    deleteCharger();
                  },
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.delete),
                      const Text('Delete charger'),
                    ],
                  ))
            ],
          );
  }

  void deleteCharger() async {
    /// This function is called when the delete charger button is pressed

    deletingCharger = true;
    setState(() {});

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    database
        .reference()
        .child('users/$uid/evc_inputs/')
        .update({"delete_charger": widget.chargerID}).then((onValue) {
      /// Now listen to see if the charger is gone
      _deleteChargerSubscription = database
          .reference()
          .child('users/$uid/evc_inputs/delete_charger')
          .onValue
          .listen((Event event) {
        DataSnapshot snapshot = event.snapshot;

        print(snapshot.value);
        if (snapshot.value == null) {
          /// If the value of delete_charger is null, then the node does not
          /// exist anymore. So we can finish with this modal

          deletingCharger = false;

          /// Now we dismiss the delete charger modal
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (_deleteChargerSubscription != null) {
      _deleteChargerSubscription.cancel();
    }
  }
}
