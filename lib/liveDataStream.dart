import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_charging_app/solarChargerSettings.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/inverter_archive.dart';
import 'package:smart_charging_app/charger_info.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'dart:collection';

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

class DataStreamPage1 extends StatefulWidget {
  @override
  _DataStreamPage1State createState() => new _DataStreamPage1State();
}

class _DataStreamPage1State extends State<DataStreamPage1> {
  bool loadingData = true;
  var _headingFont = new TextStyle(fontSize: 20.0);

  /// Initialize the strings that will define our display name and email
  String _displayName = "";
  String _displayEmail = "";

  DatabaseReference _historyRef;
  StreamSubscription<Event> _historyDataSubscription;

  Widget liveSystemDataWidget;
  Map historyChartsDataObject;

  String lastUpdatedDatetime;

  /// Define the colour array for our live charts
  Map<String, charts.Color> colourArray = {
    'Solar Power': charts.MaterialPalette.yellow.shadeDefault,
    'Battery Power': charts.MaterialPalette.green.shadeDefault,
    'Grid Power': charts.MaterialPalette.blue.shadeDefault,
    'Load Power': charts.MaterialPalette.red.shadeDefault
  };

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("Live System Data"),
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
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: Text('Live System Data'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          Divider(),

          ListTile(
            leading: const Icon(Icons.unarchive),
            title: const Text('System Archive'),
            onTap: () {
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new InverterArchive());
              Navigator.of(context).push(route);
            },
          ),
          ListTile(
            leading: const Icon(Icons.offline_bolt),
            title: const Text('Charging Session Archive'),
            onTap: () {
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new ChargingArchive());
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              Navigator.of(context).push(route);
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
                  builder: (BuildContext context) => new ChargerInfo());
              Navigator.of(context).pop();
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
        body: liveSystemDataWidget == null
            ? new Center(
                child: const Center(child: const CircularProgressIndicator()))
            : liveSystemDataWidget);
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  startInverterChartsListeners(app) async {
    int maxArrayLength = 60;

    /// Initialize our date formatter
    var dateFormatter = new DateFormat('yyyy-MM-dd');

    /// Initialize our last updated date time format
    DateFormat lastUpdatedDatetimeFormat = new DateFormat('yyyy-MM-dd H:mm:ss');

    /// Start a history data stream
    _historyDataSubscription =
        _historyRef.orderByKey().limitToLast(1).onValue.listen((Event event) {
      /// Get the current date
      String currentDate = dateFormatter.format(new DateTime.now());

      /// Our new history data will be the payload within the key
      var newHistoryData = event
          .snapshot.value[event.snapshot.value.keys.toList(growable: false)[0]];

      /// Convert the time string into a DateTime object
      DateTime newPayloadTime =
          DateTime.parse('${currentDate}T${newHistoryData['time']}');

      /// First check if the value we have is after our latest value
      List sampleArray = historyChartsDataObject['Solar Power'];
      if (newPayloadTime.isAfter(sampleArray[sampleArray.length - 1].date)) {
        /// Then we check if we are over the length limit of our arrays
        if (sampleArray.length >= maxArrayLength) {
          /// Now loop through the data in our charts
          historyChartsDataObject.forEach((dataName, dataArray) {
            /// Remove the oldest value and adding the newest value
            if (dataName == 'Solar Power') {
              dataArray.removeAt(0);
              dataArray
                  .add(new HistoryData(newPayloadTime, newHistoryData['dctp']));
              historyChartsDataObject['Solar Power'] = dataArray;
            } else if (dataName == "Battery Power") {
              dataArray.removeAt(0);
              dataArray
                  .add(new HistoryData(newPayloadTime, newHistoryData['btp']));
              historyChartsDataObject['Battery Power'] = dataArray;
            } else if (dataName == "Grid Power") {
              dataArray.removeAt(0);
              dataArray.add(
                  new HistoryData(newPayloadTime, newHistoryData['utility_p']));
              historyChartsDataObject['Grid Power'] = dataArray;
            } else if (dataName == "Load Power") {
              dataArray.removeAt(0);
              dataArray
                  .add(new HistoryData(newPayloadTime, newHistoryData['ac2p']));
              historyChartsDataObject['Load Power'] = dataArray;
            }
          });
          lastUpdatedDatetime = lastUpdatedDatetimeFormat.format(
              DateTime.parse('${currentDate}T${newHistoryData['time']}'));
        }
      }

      liveSystemDataWidget = conditionHistoryChartsData();
      setState(() {});
    });
  }

  Future initializeInverterCharts(app) async {
    /// First grab our raw inverter history data
    Map historyPayload = await grabInitialHistoryData(app);

    /// This function makes all of the raw data into a single Map
    historyChartsDataObject = _getHistoryChartsArrays(historyPayload);

    /// Then we convert the map into a list of Widgets to display
    liveSystemDataWidget = conditionHistoryChartsData();

    setState(() {});
  }

  Widget conditionHistoryChartsData() {
    List<Widget> tempChartObjList = [];

    // Now we loop through our history Object to access all of the data arrays
    historyChartsDataObject.forEach((dataArrayName, dataArray) {
      tempChartObjList.add(new Card(
          child: new Column(
        children: <Widget>[
          new ListTile(
              title: new Center(
                  child: new Text(
            dataArrayName,
            style: _headingFont,
            textAlign: TextAlign.center,
          ))),
          new SizedBox(
            height: MediaQuery.of(context).size.height / 4,
            child: new charts.TimeSeriesChart(
              [
                new charts.Series<HistoryData, DateTime>(
                    id: dataArrayName,
                    colorFn: (_, __) => colourArray[dataArrayName],
                    data: dataArray,
                    domainFn: (HistoryData sales, _) => sales.date,
                    measureFn: (HistoryData sales, _) => sales.historyValue)
              ],
              animate: true,
              dateTimeFactory: const charts.LocalDateTimeFactory(),
              behaviors: [new charts.PanAndZoomBehavior()],
            ),
          )
        ],
      )));
    });

    /// Now add the last updated datetime string at the bottom
    tempChartObjList.add(new Text(
      'Last updated: $lastUpdatedDatetime',
      style: TextStyle(fontSize: 10),
      textAlign: TextAlign.center,
    ));

    liveSystemDataWidget =
        new Center(child: new ListView(children: tempChartObjList));

    return liveSystemDataWidget;
  }

  Future<Map> grabInitialHistoryData(app) async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;

    var dateFormatter = new DateFormat('yyyy-MM-dd');
    String currentDate = dateFormatter.format(new DateTime.now());

    _historyRef = database.reference().child('users/$uid/history/$currentDate');

    var historySnapshot = await _historyRef.orderByKey().limitToLast(60).once();

    var historyPayload = new Map<String, dynamic>.from(historySnapshot.value);

    return historyPayload;
  }

  Map _getHistoryChartsArrays(historyPayload) {
    /// Define our list of data objects
    List<HistoryData> solarGenerationData = new List();
    List<HistoryData> batteryPowerData = new List();
    List<HistoryData> gridPowerData = new List();
    List<HistoryData> loadPowerData = new List();

    if (historyPayload == null) {
      solarGenerationData = [
        new HistoryData(new DateTime(2017, 9, 1), 0.0),
      ];
      batteryPowerData = [
        new HistoryData(new DateTime(2017, 9, 1), 0.0),
      ];
      gridPowerData = [
        new HistoryData(new DateTime(2017, 9, 1), 0.0),
      ];
      loadPowerData = [
        new HistoryData(new DateTime(2017, 9, 1), 0.0),
      ];
    } else {
      /// First we need to cast the data object to a Map<String, dynamic>
      var historyPayloadMap = new Map<String, dynamic>.from(historyPayload);

      /// Then we sort it to ensure the data is in order
      var sortedKeys = historyPayloadMap.keys.toList(growable: false)
        ..sort((k1, k2) => historyPayloadMap[k1]['time']
            .compareTo(historyPayloadMap[k2]['time']));

      /// Then we make a new Map that is sorted
      LinkedHashMap historyPayloadSorted = new LinkedHashMap.fromIterable(
          sortedKeys,
          key: (k) => k,
          value: (k) => historyPayload[k]);

      DateFormat dateFormatter = new DateFormat('yyyy-MM-dd');
      String currentDate = dateFormatter.format(new DateTime.now());

      DateFormat lastUpdatedDatetimeFormat =
          new DateFormat('yyyy-MM-dd H:mm:ss');

      /// Loop through our Map and add all of the values into the data list
      historyPayloadSorted.forEach((key, historyPayloadEntry) {
//        print('${historyPayloadEntry['time']} ${historyPayloadEntry['dctp']}');

        /// Add data into our data arrays
        solarGenerationData.add(new HistoryData(
            DateTime.parse('${currentDate}T${historyPayloadEntry['time']}'),
            historyPayloadEntry['dctp']));
        batteryPowerData.add(new HistoryData(
            DateTime.parse('${currentDate}T${historyPayloadEntry['time']}'),
            historyPayloadEntry['btp']));
        gridPowerData.add(new HistoryData(
            DateTime.parse('${currentDate}T${historyPayloadEntry['time']}'),
            historyPayloadEntry['utility_p']));
        loadPowerData.add(new HistoryData(
            DateTime.parse('${currentDate}T${historyPayloadEntry['time']}'),
            historyPayloadEntry['ac2p']));

        lastUpdatedDatetime = lastUpdatedDatetimeFormat.format(
            DateTime.parse('${currentDate}T${historyPayloadEntry['time']}'));
      });
    }

    return {
      'Solar Power': solarGenerationData,
      "Battery Power": batteryPowerData,
      'Grid Power': gridPowerData,
      'Load Power': loadPowerData
    };
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
    main().then((FirebaseApp app) {
      /// This gets values for our Nav email/name
      getUserDetails();

      initializeInverterCharts(app).then((dynamic _) {
        startInverterChartsListeners(app);
      });
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
    _historyRef = null;
    _historyDataSubscription.cancel();
    loadingData = true;
  }
}

class HistoryData {
  final DateTime date;
  final double historyValue;

  HistoryData(this.date, this.historyValue);
}
