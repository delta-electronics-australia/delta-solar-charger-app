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
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/solarChargerSettings.dart';

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
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new DataStreamPage1());
              Navigator.popUntil(context, ModalRoute.withName('/Dashboard'));
              Navigator.of(context).push(route);
            },
          ),
          ListTile(
            title: const Text('System Archive'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            title: const Text('Charging Session Archive'),
            onTap: () {
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) => new ChargingArchive());
              Navigator.of(context).pop();
              Navigator.of(context).push(route);
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
            title: Text('Change Solar Charging Settings'),
            onTap: () {
              print('moving to setings');
              var route = new MaterialPageRoute(
                  builder: (BuildContext context) =>
                      new SolarChargerSettings());
              Navigator.of(context).pop();
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
                pickedDate != null
                    ? new ListTile(
                        title: Text(
                        '${new DateFormat('LLLL d yyyy').format(pickedDate)} selected',
                        style: _headingFont,
                        textAlign: TextAlign.center,
                      ))
                    : null,
//                pickedDate != null
//                    ? new RaisedButton(
//                        onPressed: () {
//                          print('beep!');
//                        },
//                        child: new Row(children: <Widget>[
//                          Text("Grab historical data"),
//                          Icon(Icons.arrow_right),
//                        ]))
//                    : null,
                new Divider(),
                pickedDate != null
                    ? new SystemArchiveInformationWidgets(
                        database: database, uid: uid, pickedDate: pickedDate)
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
    _inverterHistoryKeysRef =
        database.reference().child('users/$uid/history_keys/');

    var inverterHistoryKeysObject;
    DataSnapshot snapshot = await _inverterHistoryKeysRef.once();
    inverterHistoryKeysObject = snapshot.value;

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

class SystemArchiveInformationWidgets extends StatefulWidget {
  SystemArchiveInformationWidgets(
      {Key key,
      @required this.pickedDate,
      @required this.database,
      @required this.uid})
      : super(key: key);

  final pickedDate;
  final database;
  final uid;

  @override
  _SystemArchiveInformationWidgetsState createState() =>
      _SystemArchiveInformationWidgetsState();
}

class _SystemArchiveInformationWidgetsState
    extends State<SystemArchiveInformationWidgets> {
  String uid;
  FirebaseDatabase database;

  Map inverterHistoryChartDataObject;
  Widget chartWidget;

  /// Define the colour array for our live charts
  Map<String, charts.Color> colourArray = {
    'Solar Power': charts.MaterialPalette.yellow.shadeDefault,
    'Battery Power': charts.MaterialPalette.green.shadeDefault,
    'Grid Power': charts.MaterialPalette.blue.shadeDefault,
    'Load Power': charts.MaterialPalette.red.shadeDefault
  };

  @override
  Widget build(BuildContext context) {
    return chartWidget != null
        ? chartWidget
        : new SizedBox(
            child: new Center(
                child: const Center(child: const CircularProgressIndicator())),
            height: MediaQuery.of(context).size.height / 4,
          );
  }

  createSystemArchiveWidgets() async {
    inverterHistoryChartDataObject = await _getInverterHistoryArrays();

    chartWidget = conditionInverterHistoryChartData();

    setState(() {});
  }

  Widget conditionInverterHistoryChartData() {
    List<charts.Series<HistoryData, DateTime>> dataSeriesList = [];

    /// Now we loop through our history Object to access all of the data arrays
    inverterHistoryChartDataObject.forEach((dataArrayName, dataArray) {
      dataSeriesList.add(new charts.Series<HistoryData, DateTime>(
          id: dataArrayName,
          colorFn: (_, __) => colourArray[dataArrayName],
          data: dataArray,
          domainFn: (HistoryData sales, _) => sales.date,
          measureFn: (HistoryData sales, _) => sales.historyValue));
    });

    /// Finally, add all of the widgets we want into a list
    return new SizedBox(
      height: MediaQuery.of(context).size.height / 2.5,
      child: new charts.TimeSeriesChart(
        dataSeriesList,
        animate: true,
        dateTimeFactory: const charts.LocalDateTimeFactory(),
        behaviors: [
          new charts.SeriesLegend(
            horizontalFirst: true,
            desiredMaxColumns: 2,
            position: charts.BehaviorPosition.top,
          ),
          new charts.PanAndZoomBehavior(),
        ],
        selectionModels: [
          new charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
//            changedListener: _onSelectionChanged,
          )
        ],
      ),
    );
  }

  Future<Map> _getInverterHistoryArrays() async {
    DateFormat dateFormatter = new DateFormat('yyyy-MM-dd');

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    var idToken = await user.getIdToken();
    Map requestPayload = {
      "date": dateFormatter.format(widget.pickedDate),
      "idToken": idToken
    };
    var url = "http://203.32.104.46/delta_dashboard/archive_request";
    HttpClient httpClient = new HttpClient();
    HttpClientRequest request = await httpClient.postUrl(Uri.parse(url));
    request.headers.set('content-type', 'application/json');
    request.add(utf8.encode(json.encode(requestPayload)));
    HttpClientResponse response = await request.close();
    String tempReply = await response.transform(utf8.decoder).join();
    httpClient.close();

    Map decodedReply = json.decode(tempReply);

    List timestamps = decodedReply['data_obj']['time']
        .map((dateString) => DateTime.parse(dateString))
        .toList();

    List<HistoryData> solarGenerationData = [];
    List<HistoryData> batteryPowerData = [];
    List<HistoryData> gridPowerData = [];
    List<HistoryData> loadPowerData = [];

    for (int i = 0; i < timestamps.length; i++) {
      if (i % 70 == 0) {
        DateTime timestamp = timestamps[i];
        solarGenerationData.add(new HistoryData(
            timestamp,
            double.parse(
                decodedReply['data_obj']['dcp'][i].toStringAsFixed(2))));
        batteryPowerData.add(new HistoryData(
            timestamp,
            double.parse(
                decodedReply['data_obj']['btp'][i].toStringAsFixed(2))));
        gridPowerData.add(new HistoryData(
            timestamp,
            double.parse(
                decodedReply['data_obj']['utility_p'][i].toStringAsFixed(2))));
        loadPowerData.add(new HistoryData(
            timestamp,
            double.parse(
                decodedReply['data_obj']['ac2p'][i].toStringAsFixed(2))));
      }
    }
    return {
      'Solar Power': solarGenerationData,
      'Battery Power': batteryPowerData,
      'Grid Power': gridPowerData,
      'Load Power': loadPowerData
    };
  }

  @override
  void initState() {
    super.initState();

    print('System archive initialized');
    uid = widget.uid;
    database = widget.database;
    createSystemArchiveWidgets();
  }
}

class HistoryData {
  final DateTime date;
  final double historyValue;

  HistoryData(this.date, this.historyValue);
}