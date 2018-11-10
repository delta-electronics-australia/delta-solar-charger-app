import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/change_settings.dart';

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

class DataStreamPage extends StatefulWidget {
  @override
  _DataStreamPageState createState() => new _DataStreamPageState();
}

class _DataStreamPageState extends State<DataStreamPage> {
  bool loadingData = true;

  DatabaseReference _liveDatabaseRef;

  StreamSubscription<Event> _inverterDataSubscription;

// The entire multilevel list displayed by this app.
  List<Entry> dataStructure = <Entry>[
    new Entry('AC1 Data', <Entry>[]),
    new Entry('AC2 Data', <Entry>[]),
    new Entry('DC1 Data', <Entry>[]),
    new Entry('DC2 Data', <Entry>[])
  ];

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("Data Stream"),
        ),
        drawer: new Drawer(
            child: ListView(children: <Widget>[
          DrawerHeader(
            child: Text('Header'),
            decoration: new BoxDecoration(color: Colors.blue),
          ),
          ListTile(
            title: Text('Dashboard'),
            onTap: () {
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
            },
          ),
          ListTile(
            title: Text('Live System Data'),
            onTap: () {
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new DataStreamPage1());
              Navigator.of(context).push(route);
            },
          ),
          ListTile(
            title: Text('Live Data Stream2'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            title: Text('Change Delta Smart Box Settings'),
            onTap: () {
              print('moving to setings');
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new ChangeSettings());
              Navigator.of(context).push(route);
            },
          ),
          Divider(),
          ListTile(
            title: Text('Sign Out'),
            onTap: _signOut,
          ),
        ])),
        body: loadingData
            ? new Center(
                child: const Center(child: const CircularProgressIndicator()))
            : new ListView.builder(
                itemBuilder: (context, index) =>
                    new EntryItem(dataStructure[index]),
                itemCount: dataStructure.length,
              ));
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  Future<Null> grabData() async {
    FirebaseApp app = await main();
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;
    List<Entry> tempDataStructure;
    _liveDatabaseRef =
        database.reference().child('users/' + uid + '/live_database');

    _inverterDataSubscription = _liveDatabaseRef.onValue.listen((Event event) {
      var snapshot = event.snapshot;

      Map inverterData = snapshot.value['inverter_data'];
      Map btData = snapshot.value['bt_data'];

      tempDataStructure = <Entry>[
        new Entry('AC1 Data', <Entry>[
          new Entry(
              '${inverterData['AC1 Power']['name']}: ${inverterData['AC1 Power']['value']}${inverterData['AC1 Power']['unit']}'),
          new Entry(
              '${inverterData['AC1 Voltage']['name']}: ${inverterData['AC1 Voltage']['value']}${inverterData['AC1 Voltage']['unit']}'),
          new Entry(
              '${inverterData['AC1 Current']['name']}: ${inverterData['AC1 Current']['value']}${inverterData['AC1 Current']['unit']}'),
        ]),
        new Entry('AC2 Data', <Entry>[
          new Entry(
              '${inverterData['AC2 Power']['name']}: ${inverterData['AC2 Power']['value']}${inverterData['AC2 Power']['unit']}'),
          new Entry(
              '${inverterData['AC2 Voltage']['name']}: ${inverterData['AC2 Voltage']['value']}${inverterData['AC2 Voltage']['unit']}'),
          new Entry(
              '${inverterData['AC2 Current']['name']}: ${inverterData['AC2 Current']['value']}${inverterData['AC2 Current']['unit']}'),
        ]),
        new Entry('DC1 Data', <Entry>[
          new Entry(
              '${inverterData['DC1 Power']['name']}: ${inverterData['DC1 Power']['value']}${inverterData['DC1 Power']['unit']}'),
          new Entry(
              '${inverterData['DC1 Voltage']['name']}: ${inverterData['DC1 Voltage']['value']}${inverterData['DC1 Voltage']['unit']}'),
          new Entry(
              '${inverterData['DC1 Current']['name']}: ${inverterData['DC1 Current']['value']}${inverterData['DC1 Current']['unit']}'),
        ]),
        new Entry('DC2 Data', <Entry>[
          new Entry(
              '${inverterData['DC2 Power']['name']}: ${inverterData['DC2 Power']['value']}${inverterData['DC2 Power']['unit']}'),
          new Entry(
              '${inverterData['DC2 Voltage']['name']}: ${inverterData['DC2 Voltage']['value']}${inverterData['DC2 Voltage']['unit']}'),
          new Entry(
              '${inverterData['DC2 Current']['name']}: ${inverterData['DC2 Current']['value']}${inverterData['DC2 Current']['unit']}'),
        ]),
        new Entry('Battery Data', <Entry>[
          new Entry(
              '${btData['Battery Wattage']['name']}: ${btData['Battery Wattage']['value']}${btData['Battery Wattage']['unit']}'),
          new Entry(
              '${btData['Battery Voltage']['name']}: ${btData['Battery Voltage']['value']}${btData['Battery Voltage']['unit']}'),
          new Entry(
              '${btData['Battery Current']['name']}: ${btData['Battery Current']['value']}${btData['Battery Current']['unit']}'),
        ])
      ];

      this.setState(() {
        print('punk2');
        loadingData = false;
        dataStructure = tempDataStructure;
      });
    });
  }

  Future<Null> testStream() async {
    FirebaseApp app = await main();
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;
    _liveDatabaseRef =
        database.reference().child('users/' + uid + '/live_database');
    _inverterDataSubscription = _liveDatabaseRef.onValue.listen((Event event) {
      print('new data!');
      var data = event.snapshot.value;

      print(data['inverter_data']);
    });
  }

  @override
  void initState() {
    super.initState();
    grabData();
//    testStream();
    print('ALL DONE!!!!');
  }

  @override
  void deactivate() {
    super.deactivate();
    // When we leave the page we want to cancel our data subscription
    _inverterDataSubscription.cancel();
  }

  @override
  void dispose() {
    super.dispose();
    _inverterDataSubscription.cancel();
    _liveDatabaseRef = null;
    loadingData = true;
    print('disposed');
  }
}

class EntryItem extends StatelessWidget {
  const EntryItem(this.entry);

  final Entry entry;

  Widget _buildTiles(Entry root) {
//    print(root.title);
    if (root.children.isEmpty) {
      return new ListTile(title: new Text(root.title));
    }
    return new ExpansionTile(
        key: new PageStorageKey<String>(root.title),
//        key: new PageStorageKey<Entry>(root),
        title: new Text(root.title),
        children: root.children.map(_buildTiles).toList());
  }

  @override
  Widget build(BuildContext context) {
    return _buildTiles(entry);
  }
}

class Entry {
  Entry(this.title, [this.children = const <Entry>[]]);

  final String title;
  final List<Entry> children;
}
