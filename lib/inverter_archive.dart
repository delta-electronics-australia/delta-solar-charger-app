import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_charging_app/change_settings.dart';
import 'package:smart_charging_app/firebase_transfer.dart';
import 'package:smart_charging_app/archivedChargingSession.dart';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';

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

class InverterArchive extends StatefulWidget {
  @override
  _InverterArchiveState createState() => new _InverterArchiveState();
}

class _InverterArchiveState extends State<InverterArchive> {
  bool loadingData = false;
  var _headingFont = new TextStyle(fontSize: 20.0);

  DatabaseReference _inverterHistoryKeysRef;

  Map validDatesPayload;

  DateTime pickedDate;

  FirebaseDatabase database;
  String uid;

  /// Define the colour array for our live charts
  Map<String, charts.Color> colourArray = {
    'Solar Power': charts.MaterialPalette.yellow.shadeDefault,
    'Battery Power': charts.MaterialPalette.green.shadeDefault,
    'Grid Power': charts.MaterialPalette.blue.shadeDefault,
    'Load Power': charts.MaterialPalette.red.shadeDefault
  };

  bool notNull(Object o) => o != null;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("Solar Charger System Archive"),
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
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            title: Text('Live Data Stream2'),
            onTap: () {
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new DataStreamPage());
              Navigator.of(context).push(route);
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
        body: validDatesPayload != null
            ? new Center(
                child: new Column(
                    children: [
                new Padding(
                  padding: const EdgeInsets.only(top: 5),
                ),
                new RaisedButton(
                  onPressed: () {
                    _selectDate(context, validDatesPayload);
                  },
                  child: const Text('Select a date'),
                ),
                new Divider(),
              ].where(notNull).toList()))
            : new Center(
                child: const Center(child: const CircularProgressIndicator())));
  }

  Future<Null> _selectDate(BuildContext context, Map validDatesPayload) async {
    List validDates = validDatesPayload['validDates'];
    DateTime earliestDate = validDatesPayload['earliestDate'];

    List sortedValidDate = validDates
      ..sort((date1, date2) => date1.compareTo(date2));

    pickedDate = await showDatePicker(
        context: context,
        initialDate: sortedValidDate.last,
        firstDate: earliestDate,
        lastDate: sortedValidDate.last,
        selectableDayPredicate: (DateTime val) =>
            sortedValidDate.contains(val));

    if (pickedDate != null) {
      print('We picked $pickedDate');
      setState(() {});
    }
  }

  Future<Map> getValidChargingDates() async {
    _inverterHistoryKeysRef =
        database.reference().child('users/$uid/history_keys/');

    var inverterHistoryKeysObject;
    DataSnapshot snapshot = await _inverterHistoryKeysRef.once();
    inverterHistoryKeysObject = snapshot.value;
    print(inverterHistoryKeysObject);

    DateTime earliestDate = DateTime(2050, 01, 01);

    List validDates = [];

    inverterHistoryKeysObject.forEach((date, _) {
      DateTime tempDate = DateTime.parse(date);
      if (tempDate.isBefore(earliestDate)) {
        earliestDate = tempDate;
      }

      if (!validDates.contains(tempDate)) {
        validDates.add(tempDate);
      }
    });

    return {'validDates': validDates, 'earliestDate': earliestDate};
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
    main().then((FirebaseApp app) async {
      database = new FirebaseDatabase(app: app);
      FirebaseUser user = await FirebaseAuth.instance.currentUser();
      uid = user.uid;

      validDatesPayload = await getValidChargingDates();
      setState(() {});
    });
  }
}

class HistoryData {
  final DateTime date;
  final double historyValue;

  HistoryData(this.date, this.historyValue);
}
