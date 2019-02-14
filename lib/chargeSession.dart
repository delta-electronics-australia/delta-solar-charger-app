import 'package:flutter/material.dart';
import 'dart:collection';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'globals.dart' as globals;

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';

class ChargeSessionPage extends StatefulWidget {
  ChargeSessionPage(
      {Key key,
      @required this.chargerID,
      @required this.latestChargingTimestamp})
      : super(key: key);

  final chargerID;
  final latestChargingTimestamp;

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
          title: new Text("Live Charging Data"),
        ),
        body: new Center(
            child: new ListView(
          children: <Widget>[
            new ChargeSessionLine(
              latestChargingTimestamp: widget.latestChargingTimestamp,
              chargerID: widget.chargerID,
            )
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

class HistoryData {
  final DateTime date;
  final double historyValue;

  HistoryData(this.date, this.historyValue);
}

class ChargeSessionLine extends StatefulWidget {
  ChargeSessionLine(
      {Key key,
      @required this.chargerID,
      @required this.latestChargingTimestamp})
      : super(key: key);

  final chargerID;
  final latestChargingTimestamp;

  @override
  _ChargeSessionLineState createState() => _ChargeSessionLineState();
}

class _ChargeSessionLineState extends State<ChargeSessionLine> {
  TextStyle _headingFont = new TextStyle(fontSize: 20.0);

  DatabaseReference _chargingSessionRef;
  StreamSubscription<Event> _chargingSessionSubscription;

  Widget chartObj;

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
    return chartObj != null
        ? new Center(
            child: new ListView(
            children: <Widget>[
              new Card(
                child: new Column(
                  children: <Widget>[
                    new ListTile(
                        title: new Center(
                            child: new Text(
                      '${widget.chargerID}: Live Charging Graph',
                      style: _headingFont,
                      textAlign: TextAlign.center,
                    ))),
                    chartObj,
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

  /// This function charts listeners for the charging line chart
  startChargeSessionListener() async {
    /// Start a history data stream
    _chargingSessionSubscription = _chargingSessionRef
        .orderByKey()
        .limitToLast(1)
        .onValue
        .listen((Event event) {
      /// Our new history data will be the payload within the key
      var newChargeSessionData = event
          .snapshot.value[event.snapshot.value.keys.toList(growable: false)[0]];

      /// Convert the time string into a DateTime object
      DateTime newPayloadTime =
          DateTime.parse('${newChargeSessionData['Time']}');

      /// First check if the value we have is after our latest value
      List sampleArray = chargeSessionChartDataObject['Solar Power'];
      if (newPayloadTime.isAfter(sampleArray[sampleArray.length - 1].date)) {
        /// Now loop through the data in our charts
        chargeSessionChartDataObject.forEach((dataName, dataArray) {
          if (dataName == 'Solar Power') {
            dataArray.add(new HistoryData(
                newPayloadTime, newChargeSessionData['Solar_Power']));
            chargeSessionChartDataObject['Solar Power'] = dataArray;
          } else if (dataName == "Battery Power") {
            dataArray.add(new HistoryData(
                newPayloadTime, newChargeSessionData['Battery_Power']));
            chargeSessionChartDataObject['Battery Power'] = dataArray;
          } else if (dataName == "Grid Power") {
            dataArray.add(new HistoryData(
                newPayloadTime, newChargeSessionData['Grid_Power']));
            chargeSessionChartDataObject['Grid Power'] = dataArray;
          } else if (dataName == "Load Power") {
            dataArray.add(new HistoryData(newPayloadTime,
                double.parse(newChargeSessionData['Power_Import'])));
            chargeSessionChartDataObject['Load Power'] = dataArray;
          }
        });
      }

      chartObj = conditionChargingSessionChartData();

      setState(() {});
    });
  }

  Future initializeChargingSessionCharts() async {
    /// First grab our raw inverter history data
    Map chargeSessionPayload = await grabInitialChargeSessionData();

    /// This function makes all of the raw data into a single Map
    chargeSessionChartDataObject =
        _getChargingSessionArrays(chargeSessionPayload);

    /// Then we convert the map into a list of Widgets to display
    chartObj = conditionChargingSessionChartData();

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

  /// This function grabs our current charge session data
  Future<Map> grabInitialChargeSessionData() async {
    _chargingSessionRef = globals.database.reference().child(
        'users/${globals.uid}/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}');

    DataSnapshot chargeSessionSnapshot =
        await _chargingSessionRef.orderByKey().once();

    Map chargeSessionPayload =
        new Map<String, dynamic>.from(chargeSessionSnapshot.value);

    return chargeSessionPayload;
  }

  static Map _getChargingSessionArrays(chargeSessionPayload) {
    /// Define our list of data objects
    List<HistoryData> solarGenerationData = new List();
    List<HistoryData> batteryPowerData = new List();
    List<HistoryData> gridPowerData = new List();
    List<HistoryData> loadPowerData = new List();

    if (chargeSessionPayload == null) {
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
      var chargeSessionPayloadMap =
          new Map<String, dynamic>.from(chargeSessionPayload);

      /// Then we sort it to ensure the data is in order
      var sortedKeys = chargeSessionPayloadMap.keys.toList(growable: false)
        ..sort((k1, k2) => chargeSessionPayloadMap[k1]['Time']
            .compareTo(chargeSessionPayloadMap[k2]['Time']));

      /// Then we make a new Map that is sorted
      LinkedHashMap chargeSessionSorted = new LinkedHashMap.fromIterable(
          sortedKeys,
          key: (k) => k,
          value: (k) => chargeSessionPayload[k]);

      /// Loop through our Map and add all of the values into the data list
      chargeSessionSorted.forEach((key, chargeSessionEntry) {
        /// Add data into our data arrays
        solarGenerationData.add(new HistoryData(
            DateTime.parse('${chargeSessionEntry['Time']}'),
            chargeSessionEntry['Solar_Power']));
        batteryPowerData.add(new HistoryData(
            DateTime.parse('${chargeSessionEntry['Time']}'),
            chargeSessionEntry['Battery_Power']));
        gridPowerData.add(new HistoryData(
            DateTime.parse('${chargeSessionEntry['Time']}'),
            chargeSessionEntry['Grid_Power']));
        loadPowerData.add(new HistoryData(
            DateTime.parse('${chargeSessionEntry['Time']}'),
            double.parse(chargeSessionEntry['Power_Import'])));
      });
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
    initializeChargingSessionCharts().then((dynamic _) {
      startChargeSessionListener();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _chargingSessionRef = null;

    if (_chargingSessionSubscription != null) {
      _chargingSessionSubscription.cancel();
      print('Charging session subscription disposed');
    }
  }
}
