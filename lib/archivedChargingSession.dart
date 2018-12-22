import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class ChargeSessionPage extends StatefulWidget {
  ChargeSessionPage(
      {Key key,
      @required this.chargerID,
      @required this.startDate,
      @required this.startTime,
      @required this.database})
      : super(key: key);

  final chargerID;
  final startDate;
  final startTime;
  final database;

  @override
  _ChargeSessionPageState createState() => new _ChargeSessionPageState();
}

class _ChargeSessionPageState extends State<ChargeSessionPage> {
  bool loadingData = false;
  TextStyle _headingFont = new TextStyle(fontSize: 20.0);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("Previous Charging Session"),
        ),
        body: new Center(
            child: new ListView(
          children: <Widget>[
            new ChargeSessionLine(
                chargerID: widget.chargerID,
                startDate: widget.startDate,
                startTime: widget.startTime)
          ],
        )));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();

    loadingData = true;
  }
}

class ChargeSessionLine extends StatefulWidget {
  ChargeSessionLine(
      {Key key,
      @required this.chargerID,
      @required this.startDate,
      @required this.startTime})
      : super(key: key);

  final chargerID;
  final startDate;
  final startTime;

  @override
  _ChargeSessionLineState createState() => _ChargeSessionLineState();
}

class _ChargeSessionLineState extends State<ChargeSessionLine> {
  TextStyle _headingFont = new TextStyle(fontSize: 20.0);

  Widget chartWidget;

  Map chargeSessionChartDataObject;

  Map<String, double> selectedPoint = {};

  /// seletedDate will be a string that includes the time that is selected on
  /// the graph
  String selectedDate = '';

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
        ? new Center(
            child: new ListView(
            children: <Widget>[
              new Card(
                child: new Column(
                  children: <Widget>[
                    new ListTile(
                        title: new Center(
                            child: new Text(
                      '${widget.chargerID}: ${widget.startDate} ${widget.startTime}',
                      style: _headingFont,
                      textAlign: TextAlign.center,
                    ))),
                    chartWidget,
                    new ListTile(
                        title: new Text(
                          selectedDate != ''
                              ? 'Time'
                              : 'Click the chart to view the data',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: new Text(selectedDate)),
                    ListView.builder(
                        shrinkWrap: true,
                        itemCount:
                            selectedPoint.keys.toList(growable: false).length,
                        itemBuilder: (context, index) {
                          /// First get the field name (solar power, grid power etc...)
                          String fieldName =
                              selectedPoint.keys.toList(growable: false)[index];

                          /// Now we can return a ListTile with the field name and the value
                          /// of that field name
                          return ListTile(
                            title: new Text(
                              '$fieldName',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: new Text(
                                '${selectedPoint[fieldName].toStringAsFixed(2)} kW'),
                          );
                        })
                  ],
                ),
              )
            ],
            shrinkWrap: true,
          ))
        : new SizedBox(
            child: new Center(
                child: const Center(child: const CircularProgressIndicator())),
            height: MediaQuery.of(context).size.height / 4,
          );
  }

  /// This function is a callback for when a point is selected on the chart
  _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;

    DateTime time;

    /// If the selected point is not empty
    if (selectedDatum.isNotEmpty) {
      /// Define time as the DateTime object of our selected point
      time = selectedDatum.first.datum.date;

      /// Now loop through all of the values
      selectedDatum.forEach((charts.SeriesDatum datumPair) {
        /// Put data into a Map: {seriesName: seriesValue}
        selectedPoint[datumPair.series.displayName] =
            datumPair.datum.historyValue;
      });
    }

    /// Now create our final selectedDate string
    var formatter = new DateFormat('yyyy-MM-dd HH:mm:ss');
    selectedDate = '${formatter.format(time)}';

    setState(() {});
  }

  Future initializeChargingSessionCharts(app) async {
    /// This function makes all of the raw data into a single Map
    chargeSessionChartDataObject = await _getChargingSessionArrays();

    /// Then we convert the map into a list of Widgets to display
    chartWidget = conditionChargingSessionChartData();

    setState(() {});
  }

  Widget conditionChargingSessionChartData() {
    List<charts.Series<HistoryData, DateTime>> dataSeriesList = [];

    /// Now we loop through our history Object to access all of the data arrays
    chargeSessionChartDataObject.forEach((dataArrayName, dataArray) {
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
          new charts.ChartTitle('Power (kW)',
              behaviorPosition: charts.BehaviorPosition.start,
              titleOutsideJustification:
                  charts.OutsideJustification.middleDrawArea),
        ],
        selectionModels: [
          new charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
            changedListener: _onSelectionChanged,
          )
        ],
      ),
    );
  }

  Future<Map> _getChargingSessionArrays() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    var idToken = await user.getIdToken();

    Map requestPayload = {
      "chargerID": widget.chargerID,
      "start_date": widget.startDate,
      "start_time": widget.startTime,
      "idToken": idToken
    };

    List timestamps;
    Map decodedReply;
    try {
      var url =
          "http://203.32.104.46/delta_dashboard/charging_history_request2";
      HttpClient httpClient = new HttpClient();
      HttpClientRequest request = await httpClient.postUrl(Uri.parse(url));
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(json.encode(requestPayload)));
      HttpClientResponse response = await request.close();
      String tempReply = await response.transform(utf8.decoder).join();
      httpClient.close();

      decodedReply = json.decode(tempReply);
      timestamps = decodedReply['data_obj']['labels']
          .map((dateString) => DateTime.parse(dateString))
          .toList();
    } catch (e) {
      print(e);
      var url =
          "http://203.32.104.46/delta_dashboard/charging_history_request2";
      HttpClient httpClient = new HttpClient();
      HttpClientRequest request = await httpClient.postUrl(Uri.parse(url));
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(json.encode(requestPayload)));
      HttpClientResponse response = await request.close();
      String tempReply = await response.transform(utf8.decoder).join();
      httpClient.close();

      decodedReply = json.decode(tempReply);
      timestamps = decodedReply['data_obj']['labels']
          .map((dateString) => DateTime.parse(dateString))
          .toList();
    }
    /// Initialize lists
    List<HistoryData> solarGenerationData = [];
    List<HistoryData> batteryPowerData = [];
    List<HistoryData> gridPowerData = [];
    List<HistoryData> loadPowerData = [];
    List solarGenerationArray;
    List batteryPowerArray;
    List gridPowerArray;
    List loadPowerArray;

    /// Go through the whole chartJS data object structure and extract the data arrays
    for (Map dataset in decodedReply['data_obj']['datasets']) {
      if (dataset['label'] == 'Solar Power') {
        solarGenerationArray = dataset['data'];
      } else if (dataset['label'] == 'Battery Power') {
        batteryPowerArray = dataset['data'];
      } else if (dataset['label'] == 'Utility Power') {
        gridPowerArray = dataset['data'];
      } else if (dataset['label'] == 'Charging Power') {
        loadPowerArray = dataset['data'];
      }
    }

    /// Now create our Lists of <HistoryData>
    for (int i = 0; i < timestamps.length; i++) {
      DateTime timestamp = timestamps[i];
      solarGenerationData.add(
          new HistoryData(timestamp, double.parse(solarGenerationArray[i])));
      batteryPowerData
          .add(new HistoryData(timestamp, double.parse(batteryPowerArray[i])));
      gridPowerData
          .add(new HistoryData(timestamp, double.parse(gridPowerArray[i])));
      loadPowerData
          .add(new HistoryData(timestamp, double.parse(loadPowerArray[i])));
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
    main().then((FirebaseApp app) {
      initializeChargingSessionCharts(app);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class HistoryData {
  final DateTime date;
  final double historyValue;

  HistoryData(this.date, this.historyValue);
}
