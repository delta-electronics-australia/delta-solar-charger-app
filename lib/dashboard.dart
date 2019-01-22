import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:io';
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
import 'package:flutter/scheduler.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  FirebaseApp app;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();

  /// Analytics ref is a reference to our system live analytics
  DatabaseReference _analyticsRef;
  StreamSubscription _analyticsSubscription;

  /// evCharger reference is a reference to a node with all our EV Chargers
  DatabaseReference _evChargerRef;

  /// chargingRef is a reference to a node with all of our EV chargers and their
  /// charging status
  DatabaseReference _chargingRef;
  StreamSubscription _chargingSubscription;

  /// btSOCRef is a reference to the node with our battery SOC
  DatabaseReference _historyRef;
  Timer _historySubscription;

  var listOfChargingSessionSubscriptions = <StreamSubscription>[];

  /// Initialize the strings that will define our display name and email
  String _displayName = "";
  String _displayEmail = "";

  /// Initialize a Text that will be displayed to show the number of active chargers
  Text numChargingSessionsActive = new Text('No Charging Sessions Active');

  /// Initialize a List containing the list of active chargers
  List<Widget> listOfChargingChargers = [
    new ListTile(
      title: Text('MEL-ACMP'),
    ),
  ];

  /// Initialize our charging session icon
  Icon chargingSessionIcon = new Icon(Icons.battery_std);

  Map liveAnalytics = {
    'btp_charged_t': '0.0',
    'btp_consumed_t': '0.0',
    'dcp_t': '0.0',
    'utility_p_export_t': '0.0',
    'utility_p_import_t': '0.0',
    'bt_soc': '0.0'
  };

  Map inverterHistoryData = {'btsoc': '0.0'};

  Map<String, String> chargingEnergyUsedMap = {};

  /// Initialize our map that will store our inverter history analytics
  Map inverterHistoryAnalytics;

  /// Initialize our list of series for the daily charger breakdown chart
  List<charts.Series<AnalyticsData, DateTime>> dailyChargerBreakdownSeriesList;

  List listOfTrailingEnergy = [];

  /// Initialize the last updated time for dashboard
  String lastUpdatedDatetime;

  /// Initialize the current back press time
  DateTime currentBackPressTime = DateTime.now().subtract(Duration(seconds: 3));

  /// Initialize a ScrollController for the whole page
  ScrollController _scrollController = new ScrollController();

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        child: new Scaffold(
            appBar: new AppBar(
              title: const Text("Delta Solar Charger Dashboard"),
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
                  Navigator.of(context).pop();
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
            body: loadingData
                ? new Center(
                    child:
                        const Center(child: const CircularProgressIndicator()))
                : new Center(
                    child: RefreshIndicator(
                        key: _refreshIndicatorKey,
                        child: new ListView(
                          controller: _scrollController,
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
                                      "Battery SOC",
                                      style: _headingFont,
                                      textAlign: TextAlign.center,
                                    ))),
                                    new ListTile(
                                        title: new Center(
                                            child: new Text(
                                      "${inverterHistoryData['btsoc']}",
//                                "hello",
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
                                      "Energy Consumed Today",
                                      style: _headingFont,
                                      textAlign: TextAlign.center,
                                    ))),
                                    new ListTile(
                                        title: new Center(
                                            child: new Text(
                                      "${liveAnalytics['ac2p_t']}",
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
                            new SolarGenerationHistoryCard(),
                            new DailyChargerBreakdownCard(
                              scrollController: _scrollController,
                            ),
                            new Text(
                              'Last updated: $lastUpdatedDatetime',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10),
                            )
                          ],
                        ),
                        onRefresh: _refresh))),
        onWillPop: () {
          return onWillPop();
        });
  }

  Future<Null> _refresh() async {
    /// This function will refresh the page when the user swipes down
    _analyticsSubscription.cancel();
    _chargingSubscription.cancel();
    _historySubscription.cancel();
    listOfTrailingEnergy.clear();

    /// Grab our info for solar generation
    await grabSolarGenerationHistory();

    /// Grab our info for chargers that are currently charging
    /// Then grab our daily charger breakdown
    await grabChargingChargers();

    return null;
  }

  Future<bool> onWillPop() {
    /// This function will run when the back button is pressed

    /// Get the time that the button was pressed
    DateTime now = DateTime.now();

    /// If the different in time between when the last back button was pressed and when
    /// the current button is pressed...
    if (now.difference(currentBackPressTime) > Duration(seconds: 3)) {
      /// Then we show a toast for the user to confirm that they want to exit the app
      currentBackPressTime = now;
      Fluttertoast.showToast(msg: 'Press back again to exit app');

      /// Prevent the back button from working
      return new Future(() => false);
    }

    /// If back button is pressed twice within 3 seconds then we exit the app
    exit(0);
    return new Future(() => true);
  }

  getUserDetails() {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) {
      setState(() {
        _displayName = user.displayName;
        _displayEmail = user.email;
      });
    });
  }

  Future<Null> grabSolarGenerationHistory() async {
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
      liveAnalytics['ac2p_t'] = (snapshot['ac2p_t']).toStringAsFixed(2) + 'kWh';

      lastUpdatedDatetime = snapshot['time'];
      setState(() {
        loadingData = false;
      });
    });

    DateFormat todayDateFormat = new DateFormat('yyyy-MM-dd');

    /// First define our history reference node
    _historyRef = database
        .reference()
        .child('users/$uid/history/${todayDateFormat.format(DateTime.now())}');

    /// Then get the battery SOC straight away
    _historyRef.limitToLast(1).once().then((DataSnapshot snapshot) {
      String key = snapshot.value.entries.elementAt(0).key;

      inverterHistoryData['btsoc'] =
          (snapshot.value[key]['btsoc']).toStringAsFixed(1) + "%";
      setState(() {});
    });

    /// Now make a Timer that runs every 10 seconds and grabs the BT SOC
    _historySubscription =
        new Timer.periodic(const Duration(seconds: 10), (Timer t) {
      _historyRef.limitToLast(1).once().then((DataSnapshot snapshot) {
        String key = snapshot.value.entries.elementAt(0).key;

        inverterHistoryData['btsoc'] =
            (snapshot.value[key]['btsoc']).toStringAsFixed(1) + "%";
      });
      setState(() {});
    });
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

  grabChargingChargers() async {
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
    });
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
    main().then((FirebaseApp firebaseapp) {
      app = firebaseapp;

      /// This gets values for our Nav email/name
      getUserDetails();

      /// Grab our info for solar generation
      grabSolarGenerationHistory();

      /// Grab our info for chargers that are currently charging
      /// Then grab our daily charger breakdown
      grabChargingChargers();
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
    _historySubscription.cancel();
    listOfTrailingEnergy.clear();

    print('Disposed');
  }
}

class AnalyticsData {
  final DateTime date;
  final double analyticValue;

  AnalyticsData(this.date, this.analyticValue);
}

class TrailingEnergyUsed extends StatefulWidget {
  TrailingEnergyUsed(
      {Key key,
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
            'users/$uid/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
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

  @override
  void dispose() {
    super.dispose();
    chargingSubscription.cancel();
  }
}

class ChargingSessionModal extends StatefulWidget {
  ChargingSessionModal(
      {Key key,
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
                  left: MediaQuery.of(context).size.width / 11,
                  right: MediaQuery.of(context).size.width / 11),
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
            'users/$uid/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
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
              'users/$uid/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
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
            'users/$uid/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
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

class SolarGenerationHistoryCard extends StatefulWidget {
  @override
  _SolarGenerationHistoryCardState createState() =>
      _SolarGenerationHistoryCardState();
}

class _SolarGenerationHistoryCardState
    extends State<SolarGenerationHistoryCard> {
  /// Define our loadingData flag
  bool loadingData = true;

  var _headingFont = new TextStyle(fontSize: 20.0);

  DatabaseReference _inverterHistoryAnalyticsRef;

  /// InverterHistoryAnalytics Map will be the Map that is dissected for
  /// solar generation information
  Map inverterHistoryAnalytics;

  /// This is the date of the selected SolarGeneration bar
  String selectedSolarGenerationDate = 'Click the chart to view the data';
  String selectedSolarGenerationValue = '';

  @override
  Widget build(BuildContext context) {
    return new Card(
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
          child: loadingData
              ? new Center(
                  child: const Center(child: const CircularProgressIndicator()))
              : new charts.TimeSeriesChart(
                  _getSolarGenerationData(inverterHistoryAnalytics),
                  animate: true,
//                          primaryMeasureAxis: new charts.NumericAxisSpec(
//                            renderSpec: new charts.GridlineRendererSpec(
//                              labelAnchor: charts.TickLabelAnchor.before
//                            )
//                          ),
                  defaultRenderer: new charts.BarRendererConfig<DateTime>(),
                  domainAxis:
                      new charts.DateTimeAxisSpec(usingBarRenderer: true),
                  defaultInteractions: true,
                  behaviors: [
                    new charts.SelectNearest(),
                    new charts.DomainHighlighter(),
                    new charts.ChartTitle('Energy (kWh)',
                        behaviorPosition: charts.BehaviorPosition.start,
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea)
                  ],
                  selectionModels: [
                    new charts.SelectionModelConfig(
                      type: charts.SelectionModelType.info,
                      changedListener: _onSelectionChanged,
                    )
                  ],
                ),
        ),
        new ListTile(
            title: new Text(
              selectedSolarGenerationDate,
            ),
            trailing: new Text(selectedSolarGenerationValue,
                style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    ));
  }

  /// This function is a callback for when a point is selected on the chart
  _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;

    /// Date will be the date selected on the solar generation bar chart
    DateTime date;

    /// If the selected point is not empty
    if (selectedDatum.isNotEmpty) {
      /// Define time as the DateTime object of our selected point
      date = selectedDatum.first.datum.date;

      /// Now loop through all of the values
      selectedDatum.forEach((charts.SeriesDatum datumPair) {
        selectedSolarGenerationValue =
            datumPair.datum.analyticValue.toString() + 'kWh';
      });

      /// Now create our final selectedDate string
      var formatter = new DateFormat('MMMMEEEEd');

      selectedSolarGenerationDate = '${formatter.format(date)}';

      setState(() {});
    }
  }

  List<charts.Series<AnalyticsData, DateTime>> _getSolarGenerationData(
      inverterHistoryAnalytics) {
    /// This function will take our inverter history analytics and extract
    /// solar generation data from it

    /// Define our list of data objects
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

    /// Now return the series object
    return [
      new charts.Series(
          id: 'Solar Generation History',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault,
          data: solarGenerationData,
          domainFn: (AnalyticsData sales, _) => sales.date,
          measureFn: (AnalyticsData sales, _) => sales.analyticValue)
    ];
  }

  Future<Null> grabInverterHistoryAnalytics(app) async {
    /// This function will grab all of our inverter history analytics

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;

    _inverterHistoryAnalyticsRef = database
        .reference()
        .child('users/$uid/analytics/inverter_history_analytics');

    _inverterHistoryAnalyticsRef
        .limitToLast(15)
        .once()
        .then((DataSnapshot snapshot) {
      setState(() {
        inverterHistoryAnalytics = snapshot.value;

        /// Now we can take away the loading data flag
        loadingData = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    main().then((FirebaseApp app) {
      grabInverterHistoryAnalytics(app);
    });
  }
}

class DailyChargerBreakdownCard extends StatefulWidget {
  DailyChargerBreakdownCard({Key key, @required this.scrollController})
      : super(key: key);

  final ScrollController scrollController;

  @override
  _DailyChargerBreakdownCardState createState() =>
      _DailyChargerBreakdownCardState();
}

class _DailyChargerBreakdownCardState extends State<DailyChargerBreakdownCard> {
  var _headingFont = new TextStyle(fontSize: 20.0);

  DatabaseReference _evChargerRef;
  DatabaseReference _chargingRef;
  StreamSubscription _chargingSubscription;

  List<charts.Series<AnalyticsData, DateTime>> dailyChargerBreakdownSeriesList;

  Map<String, String> selectedDailyChargerBreakdownData = {};

  String selectedDailyChargerBreakdownDate = '';
  String selectedDailyChargerBreakdownValue = '';

  /// Initialize our mapOfDataArrays
  Map<String, List<AnalyticsData>> mapOfDataArrays = {};

  @override
  Widget build(BuildContext context) {
    return new Card(
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
          height: 300.0,
          child: dailyChargerBreakdownSeriesList == null
              ? new Center(
                  child: const Center(child: const CircularProgressIndicator()))
              : new charts.TimeSeriesChart(
                  /// If our series list is empty then just display random data
                  /// If it isn't empty then we can display that data
                  dailyChargerBreakdownSeriesList,
                  animate: true,
                  defaultRenderer: new charts.BarRendererConfig<DateTime>(

                      // Todo: we still need to figure out the groupingtype
                      groupingType: charts.BarGroupingType.groupedStacked),
                  domainAxis:
                      new charts.DateTimeAxisSpec(usingBarRenderer: true),
                  defaultInteractions: true,
                  behaviors: [
                    new charts.SeriesLegend(
                      position: charts.BehaviorPosition.top,
                      desiredMaxColumns: 1,
                    ),
                    new charts.ChartTitle('Energy (kWh)',
                        behaviorPosition: charts.BehaviorPosition.start,
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea)
                  ],
                  selectionModels: [
                    new charts.SelectionModelConfig(
                      type: charts.SelectionModelType.info,
                      changedListener: _onSelectionChanged,
                    )
                  ],
                ),
        ),
        new ListTile(
            title: new Text(
          selectedDailyChargerBreakdownDate,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        )),

        /// This ListView will take in the selectedDailyChargerBreakdownData Map
        /// which is formatted like so: {chargerID: energy for that charger on selected date}
        ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: selectedDailyChargerBreakdownData.keys.toList().length,
            itemBuilder: (context, index) {
              String chargerID =
                  selectedDailyChargerBreakdownData.keys.toList()[index];
              return ListTile(
                  title: new Text(chargerID),
                  trailing: new Text(
                      selectedDailyChargerBreakdownData[chargerID],
                      style: TextStyle(fontWeight: FontWeight.bold)));
            }),
      ],
    ));
  }

  /// This function is a callback for when a point is selected on the chart
  _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;

    /// Date will be the date selected on the solar generation bar chart
    DateTime date;

    /// If the selected point is not empty
    if (selectedDatum.isNotEmpty) {
      /// Define time as the DateTime object of our selected point
      date = selectedDatum.first.datum.date;

      /// Get the time index of the selected datum
      int index = selectedDatum.first.index;

      /// Reset our daily charger breakdown data
      selectedDailyChargerBreakdownData = {};

      /// Look through the map of arrays and create our Map: selectedDailyChargerBreakdownData
      mapOfDataArrays.forEach((chargerID, dataArray) {
        double energy = dataArray[index].analyticValue;

        if (energy != null) {
          selectedDailyChargerBreakdownData[chargerID] =
              energy.toStringAsFixed(2) + 'kWh';
        }
      });

      /// Now loop through all of the values
      selectedDatum.forEach((charts.SeriesDatum datumPair) {
        selectedDailyChargerBreakdownValue =
            datumPair.datum.analyticValue.toStringAsFixed(2) + 'kWh';
      });

      /// Now create our final selectedDate string
      var formatter = new DateFormat('MMMMEEEEd');

      selectedDailyChargerBreakdownDate = '${formatter.format(date)}';

      setState(() {
        /// Once we have clicked on the bar chart, we need to scroll down to the bottom after the widget updates
//        Timer(
//            Duration(milliseconds: 200),
//            () => widget.scrollController
//                .jumpTo(widget.scrollController.position.maxScrollExtent));
        Timer(
            Duration(milliseconds: 100),
            () => widget.scrollController.animateTo(
                widget.scrollController.position.maxScrollExtent,
                duration: Duration(milliseconds: 150),
                curve: Curves.easeIn));
      });
    }
  }

  Future<Null> grabDailyChargerBreakdown(app) async {
    /// This function grabs all of the data needed to draw the daily charger
    /// breakdown bar chart

    print('grabbing daily charger breakdown');

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

    /// seriesArray is the final array of series to go into build
    var seriesArray =
        await grabChargerAnalyticsValues(user, database, evChargers, 15);

    if (this.mounted) {
      setState(() {
        dailyChargerBreakdownSeriesList = seriesArray;
        print(dailyChargerBreakdownSeriesList);
      });
    }
  }

  Future grabChargerAnalyticsValues(user, database, evChargers, numDays) async {
    String uid = user.uid;

    /// Initialize a dateFormatter
    var dateFormatter = new DateFormat('yyyy-MM-dd');

    /// Initialize our mapOfDataArrays
    mapOfDataArrays = {};

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

  startListeningToChargingStatus(app) async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase(app: app);
    String uid = user.uid;

    _chargingRef = database.reference().child('users/$uid/evc_inputs/charging');
    _chargingSubscription = _chargingRef.onValue.listen((Event event) async {
      grabDailyChargerBreakdown(app);
    });
  }

  @override
  void initState() {
    super.initState();

    main().then((FirebaseApp app) {
      startListeningToChargingStatus(app);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _chargingSubscription.cancel();
  }
}
