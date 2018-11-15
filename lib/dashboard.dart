import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_charging_app/firebase_transfer.dart';
import 'package:smart_charging_app/change_settings.dart';
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/solarChargerSettings.dart';
import 'package:smart_charging_app/chargeSession.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/inverter_archive.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';

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

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool loadingData = true;
  var _headingFont = new TextStyle(fontSize: 20.0);
  var _valueFont = new TextStyle(fontSize: 30.0);

  DatabaseReference _analyticsRef;
  StreamSubscription _analyticsSubscription;

  DatabaseReference _evChargerRef;

  DatabaseReference _chargingRef;
  StreamSubscription _chargingSubscription;

  DatabaseReference _inverterHistoryAnalyticsRef;

  var listOfChargingSessionSubscriptions = <StreamSubscription>[];

  String _displayName = "";
  String _displayEmail = "";

  var numChargingSessionsActive = new Text('No Charging Sessions Active');
  var listOfChargingChargers = <Widget>[
    new ListTile(
      title: Text('MEL-ACMP'),
    ),
  ];
  var chargingSessionIcon = new Icon(Icons.battery_std);

  var liveAnalytics = {
    'btp_charged_t': '0.0',
    'btp_consumed_t': '0.0',
    'dcp_t': '0.0',
    'utility_p_export_t': '0.0',
    'utility_p_import_t': '0.0'
  };

  var chargingEnergyUsedMap = <String, String>{};

  Map inverterHistoryAnalytics;

  List<charts.Series<AnalyticsData, DateTime>> dailyChargerBreakdownSeriesList;

  List listOfTrailingEnergy = [];

//  var solarGenerationData = new List();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: const Text("Delta Solar Charger Dashboard"),
        ),
        drawer: new Drawer(
            child: ListView(children: <Widget>[
              UserAccountsDrawerHeader(
                accountName: Text(_displayName),
                accountEmail: Text(_displayEmail),
                currentAccountPicture: const CircleAvatar(),
                decoration: new BoxDecoration(color: Colors.blue),
              ),
              ListTile(
                title: const Text('Dashboard'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('Live System Data'),
                onTap: () {
                  var route = new MaterialPageRoute(
                      builder: (BuildContext context) => new DataStreamPage1());
                  Navigator.of(context).pop();
                  Navigator.of(context).push(route);
                },
              ),
              ListTile(
                title: const Text('System Archive'),
                onTap: () {
                  var route = new MaterialPageRoute(
                      builder: (BuildContext context) => new InverterArchive());
                  Navigator.of(context).pop();
                  Navigator.of(context).push(route);
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
                  var route = new MaterialPageRoute(
                      builder: (BuildContext context) => new DataStreamPage());
                  Navigator.of(context).pop();
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
                  var route = new MaterialPageRoute(
                      builder: (BuildContext context) => new ChangeSettings());
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
        body: loadingData
            ? new Center(
            child: const Center(child: const CircularProgressIndicator()))
            : new Center(
            child: new ListView(
              children: <Widget>[
                new Card(
                  child: new Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      new ListTile(
                          title: new Center(
                              child: new Text(
                                "Solar Generated Today",
                                style: _headingFont,
                              ))),
                      new ListTile(
                          title: new Center(
                              child: new Text(
                                "${liveAnalytics['dcp_t']}",
                                style: _valueFont,
                              ))),
                    ],
                  ),
                ),
                new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    new Expanded(
                        child: new Card(
                            child: new Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "Power Exported Today",
                                          style: _headingFont,
                                          textAlign: TextAlign.center,
                                        ))),
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "${liveAnalytics['utility_p_export_t']}",
                                          style: _valueFont,
                                        ))),
                              ],
                            ))),
                    new Expanded(
                        child: new Card(
                            child: new Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "Power Imported Today",
                                          style: _headingFont,
                                          textAlign: TextAlign.center,
                                        ))),
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "${liveAnalytics['utility_p_import_t']}",
                                          style: _valueFont,
                                        ))),
                              ],
                            ))),
                  ],
                ),
                new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    new Expanded(
                        child: new Card(
                            child: new Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "Battery Consumed Today",
                                          style: _headingFont,
                                          textAlign: TextAlign.center,
                                        ))),
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "${liveAnalytics['btp_consumed_t']}",
                                          style: _valueFont,
                                        ))),
                              ],
                            ))),
                    new Expanded(
                        child: new Card(
                            child: new Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "Battery Charged Today",
                                          style: _headingFont,
                                          textAlign: TextAlign.center,
                                        ))),
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                          "${liveAnalytics['btp_charged_t']}",
                                          style: _valueFont,
                                        ))),
                              ],
                            ))),
                  ],
                ),
                new Card(
                  child: new ExpansionTile(
                      leading: chargingSessionIcon,
                      title: numChargingSessionsActive,
                      children: listOfChargingChargers),
                ),
                new Card(
                    child: new Column(
                      children: <Widget>[
                        new ListTile(
                            title: new Center(
                                child: new Text(
                                  "Solar Generation History",
                                  style: _headingFont,
                                  textAlign: TextAlign.center,
                                ))),
                        new SizedBox(
                          height: 200.0,
                          child: new charts.TimeSeriesChart(
                            _getSolarGenerationData(inverterHistoryAnalytics),
                            animate: true,
//                          primaryMeasureAxis: new charts.NumericAxisSpec(
//                            renderSpec: new charts.GridlineRendererSpec(
//                              labelAnchor: charts.TickLabelAnchor.before
//                            )
//                          ),
                            defaultRenderer:
                            new charts.BarRendererConfig<DateTime>(),
                            domainAxis: new charts.DateTimeAxisSpec(
                                usingBarRenderer: true),
                            defaultInteractions: false,
                            behaviors: [
                              new charts.SelectNearest(),
                              new charts.DomainHighlighter()
                            ],
                          ),
                        ),
                      ],
                    )),
                new Card(
                    child: new Column(
                      children: <Widget>[
                        new ListTile(
                            title: new Center(
                                child: new Text(
                                  "Daily Charger Breakdown",
                                  style: _headingFont,
                                  textAlign: TextAlign.center,
                                ))),
                        new SizedBox(
                          height: 200.0,
                          child: dailyChargerBreakdownSeriesList == null
                              ? new Center(
                              child: const Center(
                                  child: const CircularProgressIndicator()))
                              : new charts.TimeSeriesChart(

                            /// If our series list is empty then just display random data
                            /// If it isn't empty then we can display that data
                            dailyChargerBreakdownSeriesList,
                            animate: true,
                            defaultRenderer:
                            new charts.BarRendererConfig<DateTime>(
                                groupingType:
                                charts.BarGroupingType.stacked),
                            domainAxis: new charts.DateTimeAxisSpec(
                                usingBarRenderer: true),
                            defaultInteractions: false,
                            behaviors: [new charts.SeriesLegend()],
                          ),
                        ),
                      ],
                    )),
              ],
            )));
  }

  getUserDetails() {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      setState(() {
        _displayName = user.displayName;
        _displayEmail = user.email;
      });
    });
  }

  /// Create series list with multiple series
  static List<charts.Series<TestData, DateTime>> _createSampleData2() {
    final desktopSalesData = [
      new TestData(new DateTime(2017, 9, 1), 0),
    ];

    final tableSalesData = [
      new TestData(new DateTime(2017, 9, 1), 0),
    ];

    return [
      new charts.Series<TestData, DateTime>(
        id: 'Desktop',
        domainFn: (TestData sales, _) => sales.time,
        measureFn: (TestData sales, _) => sales.sales,
        data: desktopSalesData,
      ),
      new charts.Series<TestData, DateTime>(
        id: 'Tablet',
        domainFn: (TestData sales, _) => sales.time,
        measureFn: (TestData sales, _) => sales.sales,
        data: tableSalesData,
      ),
    ];
  }

  Future grabChargerAnalyticsValues(user, database, evChargers, numDays) async {
    String uid = user.uid;

    /// Initialize a dateFormatter
    var dateFormatter = new DateFormat('yyyy-MM-dd');

    /// Initialize our mapOfDataArrays
    Map<String, List<AnalyticsData>> mapOfDataArrays = {};

    /// Loop through all of our EV Chargers
    for (String chargerID in evChargers) {
      mapOfDataArrays[chargerID] = [];

      /// Download charging history analytics for this EV Charger
      DataSnapshot tempSnapshot = await database
          .reference()
          .child('users/$uid/analytics/charging_history_analytics/$chargerID/')
          .limitToLast(numDays)
          .once();
      var tempData = tempSnapshot.value;

      for (var i = numDays; i >= 0; i--) {
        DateTime dateObject =
        new DateTime.now().subtract(new Duration(days: i));
        String dateString = dateFormatter.format(dateObject);

        /// Check if for this day we have data for this chargerID
        if (tempData != null && tempData.containsKey(dateString)) {
          /// If we do, then we should loop through the object
          /// and add up the energy
          num tempChargeEnergy = 0;
          tempData[dateString].forEach((chargeTime, value) {
            tempChargeEnergy += value['energy'];
          });
          mapOfDataArrays[chargerID]
              .add(new AnalyticsData(dateObject, tempChargeEnergy));
        }

        /// If we don't have data for this chargerID on this day, we add null
        else {
          mapOfDataArrays[chargerID].add(new AnalyticsData(dateObject, null));
        }
      }
    }

    /// Once we have our map of data arrays, we can turn them into chart series
    List<charts.Series<AnalyticsData, DateTime>> seriesArray = [];

    mapOfDataArrays.forEach((chargerID, dataArray) {
      seriesArray.add(new charts.Series<AnalyticsData, DateTime>(
        id: chargerID,
        domainFn: (AnalyticsData sales, _) => sales.date,
        measureFn: (AnalyticsData sales, _) => sales.analyticValue,
        data: dataArray,
      ));
    });

    return seriesArray;
  }

  Future<Null> grabDailyChargerBreakdown(app) async {
    /// This function grabs all of the data needed to draw the daily charger
    /// breakdown bar chart

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;

    /// Define our list of ev chargers
    List evChargers = [];

    /// Now grab our ev chargers from Firebase, populate them in a list
    _evChargerRef =
        database.reference().child('users/$uid/evc_inputs/charging');
    DataSnapshot snapshot = await _evChargerRef.once();
    evChargers = snapshot.value.keys.toList(growable: false);

    /// seriesArray will the final array of series to go into build
    var seriesArray =
    await grabChargerAnalyticsValues(user, database, evChargers, 15);

    if (this.mounted) {
      setState(() {
        dailyChargerBreakdownSeriesList = seriesArray;
      });
    }
  }

  Future<Null> grabSolarGenerationHistory(app) async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;

    _analyticsRef =
        database.reference().child('users/$uid/analytics/live_analytics');

    _analyticsSubscription = _analyticsRef.onValue.listen((Event event) {
      var snapshot = event.snapshot.value;
      liveAnalytics['btp_charged_t'] =
          (snapshot['btp_charged_t'] * -1).toStringAsFixed(2) + 'kWh';
      liveAnalytics['btp_consumed_t'] =
          snapshot['btp_consumed_t'].toStringAsFixed(2) + 'kWh';
      liveAnalytics['dcp_t'] = snapshot['dcp_t'].toStringAsFixed(2) + 'kWh';
      liveAnalytics['utility_p_export_t'] =
          snapshot['utility_p_export_t'].toStringAsFixed(2) + 'kWh';
      liveAnalytics['utility_p_import_t'] =
          (snapshot['utility_p_import_t'] * -1).toStringAsFixed(2) + 'kWh';
      setState(() {});
    });

    _inverterHistoryAnalyticsRef = database
        .reference()
        .child('users/$uid/analytics/inverter_history_analytics');

    _inverterHistoryAnalyticsRef
        .limitToLast(15)
        .once()
        .then((DataSnapshot snapshot) {
      setState(() {
        loadingData = false;
        inverterHistoryAnalytics = snapshot.value;
      });
    });
  }

  static List<charts.Series<AnalyticsData, DateTime>> _getSolarGenerationData(
      inverterHistoryAnalytics) {
    // Define our list of data objects
    List<AnalyticsData> solarGenerationData = new List();

    if (inverterHistoryAnalytics == null) {
      solarGenerationData = [
        new AnalyticsData(new DateTime(2017, 9, 1), 0.0),
        new AnalyticsData(new DateTime(2017, 9, 4), 0.0),
      ];
    } else {
      // Loop through our Map and add all of the values into the data list
      inverterHistoryAnalytics.forEach((date, analyticsObj) =>
          solarGenerationData.add(new AnalyticsData(
              DateTime.parse(date), double.parse(analyticsObj['dctp']))));
    }

    // Now return the series object
    return [
      new charts.Series(
          id: 'Solar Generation History',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault,
          data: solarGenerationData,
          domainFn: (AnalyticsData sales, _) => sales.date,
          measureFn: (AnalyticsData sales, _) => sales.analyticValue)
    ];
  }

  updateChargingCollapsible(tempListOfChargingChargers) {
    if (tempListOfChargingChargers.length == 0) {
      numChargingSessionsActive = Text("No Charging Sessions Active");
      chargingSessionIcon = new Icon(Icons.battery_std);
    } else if (tempListOfChargingChargers.length == 1) {
      numChargingSessionsActive = Text("One Charging Session Active");
      chargingSessionIcon = new Icon(Icons.battery_charging_full);
    } else {
      numChargingSessionsActive =
          Text("${tempListOfChargingChargers.length} Charging Sessions Active");
      chargingSessionIcon = new Icon(Icons.battery_charging_full);
    }

    if (this.mounted) {
      setState(() {
        listOfChargingChargers = tempListOfChargingChargers;
      });
    }
  }

  grabChargingChargers(app) async {
    /// This function will grab information about the chargers that are
    /// currently charging

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;

    /// Listen to the evc_inputs charging node to see if there is any change in
    /// charging state
    _chargingRef = database.reference().child('users/$uid/evc_inputs/charging');
    _chargingSubscription = _chargingRef.onValue.listen((Event event) async {
      var chargingObj = event.snapshot.value;

      /// Loop through all of the chargers that exist
      List<Widget> tempListOfChargingChargers = [];
      for (var chargerID in chargingObj.keys.toList(growable: false)) {
        var isCharging = chargingObj[chargerID];

        /// If they are charging then we want to extract the charge session
        if (isCharging == true) {
          /// Get our latest date for this chargerID
          DataSnapshot tempSnapshot = await database
              .reference()
              .child('users/$uid/charging_history_keys/$chargerID')
              .orderByKey()
              .limitToLast(1)
              .once();

          var latestChargingDate =
          tempSnapshot.value.keys.toList(growable: false)[0];

          /// Using the latest date, get the latest time
          tempSnapshot = await database
              .reference()
              .child(
              'users/$uid/charging_history_keys/$chargerID/$latestChargingDate')
              .orderByKey()
              .limitToLast(1)
              .once();

          var latestChargingTime =
          tempSnapshot.value.keys.toList(growable: false)[0];

          /// Now combine them to get the latest charging timestamp
          var latestChargingTimestamp =
              '$latestChargingDate $latestChargingTime';

          /// Now add a new widget that takes care of the trailing energy
          var tempTrailingEnergy = new TrailingEnergyUsed(
              chargerID: chargerID,
              latestChargingTimestamp: latestChargingTimestamp,
              app: app);
          listOfTrailingEnergy.add(tempTrailingEnergy);

          /// Now add a list tile representing that chargerID
          tempListOfChargingChargers.add(new ListTile(
            title: new Text('$chargerID'),
            trailing: tempTrailingEnergy,
            onTap: () {
              print('tapped');
              showModalBottomSheet(
                  context: context,
                  builder: (builder) {
                    return new ChargingSessionModal(
                      chargerID: chargerID,
                      latestChargingTimestamp: latestChargingTimestamp,
                      database: database,
                    );
                  });
            },
          ));
        } else if (isCharging == "plugged") {
          print('$chargerID is plugged');
          tempListOfChargingChargers.add(new ListTile(
            title: new Text('$chargerID'),
            trailing: const Text('Charger plugged in'),
            onTap: () {
              print('tapped');
              showModalBottomSheet(
                  context: context,
                  builder: (builder) {
                    return new RemoteStartTransactionModal(
                        chargerID: chargerID, database: database);
                  });
            },
          ));
        }
      }

      print('fdghfd');
      print(tempListOfChargingChargers);

      if (tempListOfChargingChargers.length == 0) {
        numChargingSessionsActive = Text("No Chargers Active");
        chargingSessionIcon = new Icon(Icons.battery_std);
      } else if (tempListOfChargingChargers.length == 1) {
        numChargingSessionsActive = Text("One Charger Active");
        chargingSessionIcon = new Icon(Icons.battery_charging_full);
      } else {
        numChargingSessionsActive =
            Text("${tempListOfChargingChargers.length} Chargers Active");
        chargingSessionIcon = new Icon(Icons.battery_charging_full);
      }

      if (this.mounted) {
        setState(() {
          listOfChargingChargers = tempListOfChargingChargers;
        });
      }
      grabDailyChargerBreakdown(app);
    });
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    //    Navigator.popUntil(context, ModalRoute.withName('/'));
  }

  @override
  void initState() {
    super.initState();
    main().then((FirebaseApp app) {
      /// This gets values for our Nav email/name
      getUserDetails();

      /// Grab our info for solar generation
      grabSolarGenerationHistory(app);

      /// Grab our info for chargers that are currently charging
      /// Then grab our daily charger breakdown
      grabChargingChargers(app);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _analyticsRef = null;
    _evChargerRef = null;
    _chargingRef = null;
    _analyticsSubscription.cancel();
    _chargingSubscription.cancel();

    listOfTrailingEnergy.clear();

    print('Disposed');
  }
}

class TestData {
  final DateTime time;
  final int sales;

  TestData(this.time, this.sales);
}

class AnalyticsData {
  final DateTime date;
  final double analyticValue;

  AnalyticsData(this.date, this.analyticValue);
}

class TrailingEnergyUsed extends StatefulWidget {
  TrailingEnergyUsed({Key key,
    @required this.chargerID,
    @required this.app,
    @required this.latestChargingTimestamp})
      : super(key: key);

  final chargerID;
  final FirebaseApp app;
  final latestChargingTimestamp;

  @override
  _TrailingEnergyUsedState createState() => _TrailingEnergyUsedState();
}

class _TrailingEnergyUsedState extends State<TrailingEnergyUsed> {
  String chargingEnergyUsed;

  StreamSubscription chargeSessionSubscription;

  @override
  Widget build(BuildContext context) {
    return chargingEnergyUsed != null
        ? new Text('Energy Used: $chargingEnergyUsed kWh')
        : new Text('Energy Used: loading...');
  }

  Future grabChargingData() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: widget.app);
    String uid = user.uid;

    /// Then we will start a listener to get the latest value of the
    /// amount of energy charged. Then append the tempList
    chargeSessionSubscription = database
        .reference()
        .child(
        'users/$uid/charging_history/${widget.chargerID}/${widget
            .latestChargingTimestamp}')
        .limitToLast(1)
        .onValue
        .listen((Event event) {
      var latestPayload = event.snapshot.value;

      if (latestPayload != null) {
        /// Find the amount of energy used currently
        chargingEnergyUsed =
            latestPayload[latestPayload.keys.toList(growable: false)[0]]
            ['Energy_Import_Aggregate']
                .toStringAsFixed(2);

        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    chargeSessionSubscription.cancel();
    print('Disposed in ${widget.chargerID}');
  }

  @override
  void initState() {
    super.initState();
    grabChargingData();
  }

  @override
  void didUpdateWidget(TrailingEnergyUsed oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// We override this to ensure that the trailing energy will update every time
    chargingEnergyUsed = null;
    grabChargingData();
  }
}

class RemoteStartTransactionModal extends StatefulWidget {
  RemoteStartTransactionModal(
      {Key key, @required this.chargerID, @required this.database})
      : super(key: key);

  final chargerID;
  final database;

  @override
  _RemoteStartTransactionModalState createState() =>
      _RemoteStartTransactionModalState();
}

class _RemoteStartTransactionModalState
    extends State<RemoteStartTransactionModal> {
  bool startingCharge = false;

  StreamSubscription chargingSubscription;

  @override
  Widget build(BuildContext context) {
    return startingCharge
        ? new Center(
        child: const Center(child: const CircularProgressIndicator()))
        : new Center(
      child: new RaisedButton(
          child: const Text('Start Charging Session'),
          onPressed: () {
            print('pressed');
            remoteStartTransaction();
          }),
    );
  }

  remoteStartTransaction() async {

    setState(() {
      startingCharge = true;
    });

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    String uid = user.uid;

    FirebaseDatabase database = widget.database;

    database.reference().child('users/$uid/evc_inputs').update({
      "misc_command": {
        "chargerID": widget.chargerID,
        "action": "RemoteStartTransaction",
        "misc_data": ""
      }
    });

    chargingSubscription = database
        .reference()
        .child('users/$uid/evc_inputs/charging/${widget.chargerID}')
        .onValue
        .listen((Event event) {
      var isCharging = event.snapshot.value;

      if (isCharging == true) {
        Navigator.pop(context);
      }
    });
  }
}

class ChargingSessionModal extends StatefulWidget {
  ChargingSessionModal({Key key,
    @required this.chargerID,
    @required this.database,
    @required this.latestChargingTimestamp})
      : super(key: key);

  final chargerID;
  final database;
  final latestChargingTimestamp;

  @override
  _ChargingSessionModalState createState() => _ChargingSessionModalState();
}

class _ChargingSessionModalState extends State<ChargingSessionModal> {
  /// Initialize our information strings (the should include units!)
  String chargingStartTime;
  String chargingDuration;
  String chargingEnergy;
  String chargingPower;
  String chargingCurrent;

  /// Initialize our database references
  StreamSubscription chargeSessionSubscription;
  StreamSubscription chargingSubscription;

  bool stoppingCharging = false;

  @override
  Widget build(BuildContext context) {
    return stoppingCharging
        ? new Center(
        child: const Center(child: const CircularProgressIndicator()))
        : new Container(
      child: new ListView(
        shrinkWrap: true,
        padding: new EdgeInsets.only(
            top: 15,
            left: MediaQuery
                .of(context)
                .size
                .width / 11,
            right: MediaQuery
                .of(context)
                .size
                .width / 11),
        children: <Widget>[
          new Center(
              child: new AutoSizeText(
                '${widget.chargerID}: Live Charging Session',
                style: TextStyle(fontSize: 25.0),
                maxLines: 1,
              )),
          new Divider(),
          new ListTile(
            title: const Text('Charging Started:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: chargingStartTime != null
                ? Text('$chargingStartTime')
                : Text('loading...'),
          ),
          new ListTile(
            title: const Text('Duration:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: chargingDuration != null
                ? Text('$chargingDuration')
                : Text('loading...'),
          ),
          new ListTile(
            title: const Text('Energy Consumed:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: chargingEnergy != null
                ? Text('$chargingEnergy kWh')
                : Text('loading...'),
          ),
          new ListTile(
            title: const Text('Charging Power:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: chargingPower != null
                ? Text('$chargingPower kW')
                : Text('loading...'),
          ),
          new ListTile(
            title: const Text('Charging Current:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: chargingCurrent != null
                ? Text('$chargingCurrent A')
                : Text('loading...'),
          ),
          new Divider(),
          new Row(
            children: <Widget>[
              new RaisedButton(
                child: new Text('Stop charging session'),
                onPressed: () {
                  print('pressed');
                  stopChargingSession();
                },
                color: Colors.redAccent,
              ),
              new RaisedButton(
                child: new Text('More info...'),
                onPressed: () {
                  print('pressed');
//                  Navigator.pop(context);
                  var route = new MaterialPageRoute(
                      builder: (BuildContext context) =>
                      new ChargeSessionPage(
                        latestChargingTimestamp:
                        widget.latestChargingTimestamp,
                        database: widget.database,
                        chargerID: widget.chargerID,
                      ));
                  Navigator.of(context).push(route);
                },
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          )
        ],
      ),
    );
  }

  stopChargingSession() async {
    /// Set our stoppingCharging boolean to true so we can show loading circle
    setState(() {
      stoppingCharging = true;
    });

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    String uid = user.uid;
    final FirebaseDatabase database = widget.database;

    database.reference().child('users/$uid/evc_inputs').update({
      "misc_command": {
        "chargerID": widget.chargerID,
        "action": "RemoteStopTransaction",
        "misc_data": ""
      }
    });

    chargingSubscription = database
        .reference()
        .child('users/$uid/evc_inputs/charging/${widget.chargerID}')
        .onValue
        .listen((Event event) {
      var isCharging = event.snapshot.value;

      if (isCharging == false) {
        Navigator.pop(context);
      }
    });
  }

  String convertSecondsToDurationString(totalSecondsObject) {
    String localChargingDuration = '';

    int totalSeconds = totalSecondsObject.inSeconds;
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

  grabChargingSessionData() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    String uid = user.uid;
    final FirebaseDatabase database = widget.database;
    DateTime chargingStartTimeObj;

    /// Find when the charging session started
    database
        .reference()
        .child(
        'users/$uid/charging_history/${widget.chargerID}/${widget
            .latestChargingTimestamp}')
        .limitToFirst(1)
        .once()
        .then((DataSnapshot snapshot) {
      chargingStartTime = snapshot
          .value[snapshot.value.keys.toList(growable: false)[0]]['Time'];
      chargingStartTimeObj = DateTime.parse(chargingStartTime);

      /// Update our chargingStartTime value
      setState(() {});

      /// Now get our latest time object
      database
          .reference()
          .child(
          'users/$uid/charging_history/${widget.chargerID}/${widget
              .latestChargingTimestamp}')
          .limitToLast(1)
          .once()
          .then((DataSnapshot snapshot) {
        DateTime latestChargingTimeObj = DateTime.parse(snapshot
            .value[snapshot.value.keys.toList(growable: false)[0]]['Time']);

        /// Find the duration between the start of charging and now
        Duration totalSecondsObject =
        latestChargingTimeObj.difference(DateTime.parse(chargingStartTime));

        /// Convert it into a string to setState
        chargingDuration = convertSecondsToDurationString(totalSecondsObject);

        setState(() {});
      });
    });

    /// Then we will start a listener to get the latest values of the charge session
    chargeSessionSubscription = database
        .reference()
        .child(
        'users/$uid/charging_history/${widget.chargerID}/${widget
            .latestChargingTimestamp}')
        .limitToLast(1)
        .onValue
        .listen((Event event) {
      var latestPayload = event.snapshot.value;
//      print(latestPayload);

      /// Find the amount of energy used currently
      chargingEnergy =
          latestPayload[latestPayload.keys.toList(growable: false)[0]]
          ['Energy_Import_Aggregate']
              .toStringAsFixed(2);

      /// Find the amount of power being currently used
      chargingPower =
      latestPayload[latestPayload.keys.toList(growable: false)[0]]
      ['Power_Import'];

      /// Find the amount of current being currently used
      chargingCurrent =
      latestPayload[latestPayload.keys.toList(growable: false)[0]]
      ['Current_Import'];

      /// Find the charging duration
      if (chargingStartTimeObj != null) {
        Duration totalSecondsObject = DateTime.parse(
            latestPayload[latestPayload.keys.toList(growable: false)[0]]
            ['Time'])
            .difference(chargingStartTimeObj);
        int totalSeconds = totalSecondsObject.inSeconds;
        int hours = totalSeconds ~/ 3600;
        totalSeconds %= 3600;
        int minutes = totalSeconds ~/ 60;
        int seconds = totalSeconds %= 60;

        /// First reset our chargingDuration string
        chargingDuration = '';
        if (hours > 0) {
          if (hours == 1) {
            chargingDuration = '${hours}hr ';
          } else {
            chargingDuration = '${hours}hrs ';
          }
        }
        if (minutes > 0) {
          chargingDuration += '${minutes}min ';
        }
        if (seconds > 0) {
          chargingDuration += '${seconds}sec';
        }
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    stoppingCharging = false;
    if (chargingSubscription != null) {
      chargingSubscription.cancel();
    }
    if (chargeSessionSubscription != null) {
      chargeSessionSubscription.cancel();
      print('Charge session subscription in modal cancelled');
    }
    print('${widget.chargerID} modal disposed!');
  }

  @override
  void initState() {
    super.initState();

    grabChargingSessionData();
  }
}
