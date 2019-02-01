import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_charging_app/archivedChargingSession.dart';
import 'package:smart_charging_app/inverter_archive.dart';
import 'package:smart_charging_app/solarChargerSettings.dart';
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/charger_info.dart';


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

class ChargingArchive extends StatefulWidget {
  @override
  _ChargingArchiveState createState() => new _ChargingArchiveState();
}

class _ChargingArchiveState extends State<ChargingArchive> {
  bool loadingData = false;
  var _headingFont = new TextStyle(fontSize: 20.0);

  /// Initialize the strings that will define our display name and email
  String _displayName = "";
  String _displayEmail = "";

  DatabaseReference _chargingHistoryAnalyticsRef;

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
          title: new Text("Charging Session Archive"),
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
            title: Text('Dashboard'),
            onTap: () {
              Navigator.of(context).popUntil(ModalRoute.withName('/Dashboard'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: Text('Live System Data'),
            onTap: () {
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new DataStreamPage1());
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
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
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              Navigator.of(context).push(route);
            },
          ),
          ListTile(
            leading: const Icon(Icons.offline_bolt),
            title: const Text('Charging Session Archive'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
//          ListTile(
//            title: Text('Live Data Stream2'),
//            onTap: () {
//              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
//              var route = new MaterialPageRoute(
//                  builder: (BuildContext context) => new DataStreamPage());
//              Navigator.of(context).push(route);
//            },
//          ),
          Divider(),

          ListTile(
            leading: const Icon(Icons.power),
            title: Text('Connected Chargers'),
            onTap: () {
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) =>
                  new ChargerInfo());
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
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              Navigator.of(context).push(route);
            },
          ),
//          ListTile(
//            title: Text('Change Delta Smart Box Settings'),
//            onTap: () {
//              print('moving to setings');
//              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
//              var route = new MaterialPageRoute(
//                  builder: (BuildContext context) => new ChangeSettings());
//              Navigator.of(context).push(route);
//            },
//          ),
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
                new Padding(padding: const EdgeInsets.only(top: 5)),
                new RaisedButton(
                  onPressed: () {
                    _selectDate(context, validDatesPayload);
                  },
                  child: const Text('Select a date'),
                ),
                pickedDate != null
                    ? new ListTile(
                        title: Text(
                        '${new DateFormat('LLLL d yyyy').format(pickedDate)}',
                        style: _headingFont,
                        textAlign: TextAlign.center,
                      ))
                    : null,
                new Divider(),
                pickedDate != null
                    ? new ChargeSessionCards(
                        pickedDate: pickedDate, database: database, uid: uid)
                    : null
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
    _chargingHistoryAnalyticsRef = database
        .reference()
        .child('users/$uid/analytics/charging_history_analytics');

    var chargingHistoryKeysObject;
    DataSnapshot snapshot = await _chargingHistoryAnalyticsRef.once();
    chargingHistoryKeysObject = snapshot.value;
    print(chargingHistoryKeysObject);

    DateTime earliestDate = DateTime(2050, 01, 01);

    List validDates = [];

    chargingHistoryKeysObject.forEach((chargerID, analytics) {
      List tempDates = analytics.keys.toList();

      for (String date in tempDates) {
        DateTime tempDate = DateTime.parse(date);
        if (tempDate.isBefore(earliestDate)) {
          earliestDate = tempDate;
        }

        if (!validDates.contains(tempDate)) {
          validDates.add(tempDate);
        }
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

  getUserDetails() {
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
    main().then((FirebaseApp app) async {
      getUserDetails();
      database = new FirebaseDatabase(app: app);
      FirebaseUser user = await FirebaseAuth.instance.currentUser();
      uid = user.uid;

      validDatesPayload = await getValidChargingDates();
      setState(() {});
    });
  }
}

class ChargeSessionCards extends StatefulWidget {
  ChargeSessionCards(
      {Key key,
      @required this.pickedDate,
      @required this.database,
      @required this.uid})
      : super(key: key);

  final pickedDate;
  final database;
  final uid;

  @override
  _ChargeSessionCardsState createState() => _ChargeSessionCardsState();
}

class _ChargeSessionCardsState extends State<ChargeSessionCards> {
  String uid;
  FirebaseDatabase database;

  var _headingFont = new TextStyle(fontSize: 20.0);

  List<Widget> cardWidgetList = [];

  @override
  Widget build(BuildContext context) {
    return cardWidgetList.length != 0
        ? new Expanded(
            child: new ListView(
            children: cardWidgetList,
          ))
        : new Center(
            child: const Center(child: const CircularProgressIndicator()));
  }

  createChargeSessionCards() async {
    DateFormat dateFormatter = new DateFormat('yyyy-MM-dd');
    DateFormat startTimeFormatter = new DateFormat('h:mm aa');

    List evChargers = await getEVChargerList();

    /// Format our date picked into YYYY-MM-DD
    String datePickedFormatted = dateFormatter.format(widget.pickedDate);

    for (String chargerID in evChargers) {
      DataSnapshot chargingHistoryAnalyticsObject = await database
          .reference()
          .child(
              'users/$uid/analytics/charging_history_analytics/$chargerID/$datePickedFormatted')
          .once();

      Map tempChargingAnalytics = chargingHistoryAnalyticsObject.value;

      /// If there are analytics for this charger on this day
      if (tempChargingAnalytics != null) {
        /// First sort the dates
        var chargingTimeList =
            tempChargingAnalytics.keys.toList(growable: false);
        var sortedChargingTimeList = chargingTimeList
          ..sort((time1, time2) => time1.compareTo(time2));

        /// Loop through all of the sorted charging times
        for (String chargingTime in sortedChargingTimeList) {
          /// First get the duration string
          String durationString = convertSecondsToDurationString(
              tempChargingAnalytics[chargingTime]['duration_seconds']);

          /// Now get the string for the start time
          String startTime = startTimeFormatter
              .format(DateTime.parse('${datePickedFormatted}T$chargingTime'));

          String chargeEnergy =
              tempChargingAnalytics[chargingTime]['energy'].toStringAsFixed(2);
          cardWidgetList.add(GestureDetector(
            child: new Card(
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new ListTile(
                      title: new Center(
                          child: new Text(
                    "Started: $startTime",
                    style: _headingFont,
                  ))),
                  new ListTile(
                      title: const Text(
                        'Charger ID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: new Text('$chargerID')),
                  new ListTile(
                      title: const Text(
                        'Charge Duration',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: new Text('$durationString')),
                  new ListTile(
                      title: const Text(
                        'Charge Energy',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: new Text('$chargeEnergy kWh')),
                ],
              ),
            ),
            onTap: () {
              print('$startTime $chargeEnergy $chargerID');
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new ChargeSessionPage(
                        chargerID: chargerID,
                        startDate: datePickedFormatted,
                        startTime: chargingTime,
                        database: database,
                      ));
              Navigator.of(context).push(route);
//              getChargingSession(chargerID, datePickedFormatted, chargingTime);
            },
          ));
        }
      }
    }
    setState(() {});
  }

  String convertSecondsToDurationString(secondsInput) {
    /// This function will convert an integer seconds input into a English string
    String localChargingDuration = '';

    /// Need to convert secondsInput from double to int
    int totalSeconds = secondsInput.round();
    int hours = totalSeconds ~/ 3600;
    totalSeconds %= 3600;
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds %= 60;

    if (hours > 0) {
      if (hours == 1) {
        localChargingDuration = '${hours}hr ';
      } else {
        localChargingDuration = '${hours}hrs ';
      }
    }
    if (minutes > 0) {
      localChargingDuration += '${minutes}min ';
    }
    if (seconds > 0) {
      localChargingDuration += '${seconds}sec';
    }

    if (localChargingDuration == '') {
      return 'loading...';
    } else {
      return localChargingDuration;
    }
  }

  Future<List> getEVChargerList() async {
    /// This function gets a list of the current registered EV Chargers
    DataSnapshot evChargersObject = await widget.database
        .reference()
        .child('users/$uid/ev_chargers')
        .once();
    return evChargersObject.value.keys.toList();
  }

  @override
  void initState() {
    super.initState();
    print('Charging archive initialized');
    uid = widget.uid;
    database = widget.database;
    createChargeSessionCards();
  }

  @override
  void dispose() {
    super.dispose();
    print('disposed');
  }

  @override
  void didUpdateWidget(ChargeSessionCards oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pickedDate != widget.pickedDate) {
      /// We override this to ensure that the charge session cards will update every time
      if (cardWidgetList.length != 0) {
        cardWidgetList.clear();
      }
      createChargeSessionCards();
    }
  }
}

class HistoryData {
  final DateTime date;
  final double historyValue;

  HistoryData(this.date, this.historyValue);
}
