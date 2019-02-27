import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'globals.dart' as globals;

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_charging_app/admin_dashboard.dart';
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/solarChargerSettings.dart';
import 'package:smart_charging_app/solarChargerSettings2.dart';
import 'package:smart_charging_app/chargeSession.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/inverter_archive.dart';
import 'package:smart_charging_app/charger_info.dart';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
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

  /// Initialize keys that will be used to refresh the page
  ObjectKey solarGenerationKey;
  ObjectKey dailyChargerBreakdownKey;

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        child: new Scaffold(
            appBar: new AppBar(
              title: globals.isAdmin
                  ? new Text("${globals.systemName}'s Dashboard")
                  : new Text("Delta Solar Charger Dashboard"),
            ),
            drawer: new Drawer(
                child: ListView(children: <Widget>[
              globals.isAdmin
                  ? UserAccountsDrawerHeader(
                      accountName:
                          Text('Currently logged in as ${globals.systemName}'),
                      decoration: new BoxDecoration(color: Colors.blue),
                    )
                  : UserAccountsDrawerHeader(
                      accountName: Text(globals.displayName),
                      accountEmail: Text(globals.displayEmail),
                      decoration: new BoxDecoration(color: Colors.blue),
                    ),
              globals.isAdmin
                  ? ListView(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.supervisor_account),
                          title: const Text('Admin Dashboard'),
                          onTap: () {
                            Navigator.popUntil(context,
                                ModalRoute.withName('/AdminDashboard'));
                          },
                        ),
                        new Divider()
                      ],
                    )
                  : new Container(),
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
                  MaterialPageRoute route = new MaterialPageRoute(
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
                          new SolarChargerSettings2());
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
                            new SolarGenerationHistoryCard(
                                key: solarGenerationKey),
                            new DailyChargerBreakdownCard(
                              key: dailyChargerBreakdownKey,
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

  int generateRandomInteger() {
    var rnd = new Random();
    var next = rnd.nextDouble() * 1000000;
    while (next < 100000) {
      next *= 10;
    }
    return next.toInt();
  }

  Future<Null> _refresh() async {
    /// This function will refresh the page when the user swipes down

    /// First cancel all our existing subscriptions
    _analyticsSubscription.cancel();
    _chargingSubscription.cancel();
    _historySubscription.cancel();
    listOfTrailingEnergy.clear();

    /// Grab our info for solar generation
    await grabSolarGenerationHistory();

    /// Grab our info for chargers that are currently charging
    /// Then grab our daily charger breakdown
    await grabChargingChargers();

    /// Now change the key of so that our solar generation and daily charger
    /// breakdown charts can be completely updated
    setState(() {
      solarGenerationKey = ObjectKey(generateRandomInteger());
      dailyChargerBreakdownKey = ObjectKey(generateRandomInteger());
    });

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

      if (globals.isAdmin) {
        Fluttertoast.showToast(
            msg: 'Press back again to exit to admin dashboard');
      } else {
        Fluttertoast.showToast(msg: 'Press back again to exit app');
      }

      /// Prevent the back button from working
      return new Future(() => false);
    }

    if (globals.isAdmin) {
    } else {
      /// If back button is pressed twice within 3 seconds then we exit the app
      exit(0);
    }

    return new Future(() => true);
  }

  Future<Null> grabSolarGenerationHistory() async {
    _analyticsRef = globals.database
        .reference()
        .child('users/${globals.uid}/analytics/live_analytics');

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
    _historyRef = globals.database.reference().child(
        'users/${globals.uid}/history/${todayDateFormat.format(DateTime.now())}');

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

  grabChargingChargers() async {
    /// This function will grab information about the chargers that are
    /// currently charging

    /// Listen to the evc_inputs charging node to see if there is any change in
    /// charging state
    _chargingRef = globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging');
    _chargingSubscription = _chargingRef.onValue.listen((Event event) async {
      var chargingObj = event.snapshot.value;

      /// Loop through all of the chargers that exist
      List<Widget> tempListOfChargingChargers = [];
      for (var chargerID in chargingObj.keys.toList(growable: false)) {
        var isCharging = chargingObj[chargerID];

        /// If they are charging then we want to extract the charge session
        if (isCharging == true) {
          /// Get our latest date for this chargerID
          DataSnapshot tempSnapshot = await globals.database
              .reference()
              .child('users/${globals.uid}/charging_history_keys/$chargerID')
              .orderByKey()
              .limitToLast(1)
              .once();

          var latestChargingDate =
              tempSnapshot.value.keys.toList(growable: false)[0];

          /// Using the latest date, get the latest time
          tempSnapshot = await globals.database
              .reference()
              .child(
                  'users/${globals.uid}/charging_history_keys/$chargerID/$latestChargingDate')
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
          );
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
                        chargerID: chargerID);
                  });
            },
          ));
        }
      }

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
    _analyticsSubscription.cancel();
    _chargingSubscription.cancel();
    _historySubscription.cancel();
    listOfTrailingEnergy.clear();

    await FirebaseAuth.instance.signOut();
    print('Signed out');
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  @override
  void initState() {
    super.initState();

    /// Grab our info for solar generation
    grabSolarGenerationHistory();

    /// Grab our info for chargers that are currently charging
    /// Then grab our daily charger breakdown
    grabChargingChargers();
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

    print('Disposed dashboard');
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
      @required this.latestChargingTimestamp})
      : super(key: key);

  final chargerID;
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
    /// Then we will start a listener to get the latest value of the
    /// amount of energy charged. Then append the tempList
    chargeSessionSubscription = globals.database
        .reference()
        .child(
            'users/${globals.uid}/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
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
  RemoteStartTransactionModal({Key key, @required this.chargerID})
      : super(key: key);

  final chargerID;

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

    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs')
        .update({
      "misc_command": {
        "chargerID": widget.chargerID,
        "action": "RemoteStartTransaction",
        "misc_data": ""
      }
    });

    chargingSubscription = globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging/${widget.chargerID}')
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
      @required this.latestChargingTimestamp})
      : super(key: key);

  final chargerID;
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
        : new ListView(
            physics: NeverScrollableScrollPhysics(),
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
                                chargerID: widget.chargerID,
                              ));
                      Navigator.of(context).push(route);
                    },
                  ),
                ],
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              )
            ],
          );
  }

  stopChargingSession() async {
    /// Set our stoppingCharging boolean to true so we can show loading circle
    setState(() {
      stoppingCharging = true;
    });

    globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs')
        .update({
      "misc_command": {
        "chargerID": widget.chargerID,
        "action": "RemoteStopTransaction",
        "misc_data": ""
      }
    });

    chargingSubscription = globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging/${widget.chargerID}')
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
    DateTime chargingStartTimeObj;

    /// Find when the charging session started
    globals.database
        .reference()
        .child(
            'users/${globals.uid}/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
        .limitToFirst(1)
        .once()
        .then((DataSnapshot snapshot) {
      chargingStartTime = snapshot
          .value[snapshot.value.keys.toList(growable: false)[0]]['Time'];
      chargingStartTimeObj = DateTime.parse(chargingStartTime);

      /// Update our chargingStartTime value
      setState(() {});

      /// Now get our latest time object
      globals.database
          .reference()
          .child(
              'users/${globals.uid}/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
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
    chargeSessionSubscription = globals.database
        .reference()
        .child(
            'users/${globals.uid}/charging_history/${widget.chargerID}/${widget.latestChargingTimestamp}')
        .limitToLast(1)
        .onValue
        .listen((Event event) {
      var latestPayload = event.snapshot.value;

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
  SolarGenerationHistoryCard({Key key}) : super(key: key);

  @override
  _SolarGenerationHistoryCardState createState() =>
      _SolarGenerationHistoryCardState();
}

class _SolarGenerationHistoryCardState
    extends State<SolarGenerationHistoryCard> {
  var _headingFont = new TextStyle(fontSize: 20.0);

  List<charts.Series<AnalyticsData, DateTime>> solarGenerationSeriesList;

  /// Initialize our inverter history analytics subscription
  StreamSubscription _inverterHistoryAnalyticsSubscription;

  /// This is the date of the selected SolarGeneration bar
  String selectedSolarGenerationDate = '';
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
          child: solarGenerationSeriesList == null
              ? new Center(
                  child: const Center(child: const CircularProgressIndicator()))
              : new charts.TimeSeriesChart(
                  solarGenerationSeriesList,
                  animate: true,
                  defaultRenderer: new charts.BarRendererConfig<DateTime>(),
                  domainAxis:
                      new charts.DateTimeAxisSpec(usingBarRenderer: true),
                  defaultInteractions: false,
                  behaviors: [
                    new charts.ChartTitle('Energy (kWh)',
                        behaviorPosition: charts.BehaviorPosition.start,
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea),
                    new charts.SelectNearest(),
                    new charts.DomainHighlighter(),
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
            title: selectedSolarGenerationDate == ''
                ? new Text(
                    'Click the chart to view the data',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                : new Text(
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

  void _getSolarGenerationChartList(inverterHistoryAnalytics) {
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
    solarGenerationSeriesList = [
      new charts.Series(
          id: 'Solar Generation History',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault,
          data: solarGenerationData,
          domainFn: (AnalyticsData sales, _) => sales.date,
          measureFn: (AnalyticsData sales, _) => sales.analyticValue)
    ];
    setState(() {});
  }

  void grabInverterHistoryAnalytics() async {
    /// This function will grab all of our inverter history analytics

    /// First start a listener for any changes in inverter history analytics
    /// Whenever the day changes the graph will automatically update
    _inverterHistoryAnalyticsSubscription = globals.database
        .reference()
        .child('users/${globals.uid}/analytics/inverter_history_analytics')
        .limitToLast(15)
        .onValue
        .listen((Event event) {
      Map inverterHistoryAnalytics = event.snapshot.value;

      /// Get our chart object from our inverterHistoryAnalytics Map
      _getSolarGenerationChartList(inverterHistoryAnalytics);
    });
  }

  @override
  void initState() {
    super.initState();
    grabInverterHistoryAnalytics();
  }

  @override
  void dispose() {
    super.dispose();
    _inverterHistoryAnalyticsSubscription.cancel();
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

  String selectedDailyChargerBreakdownDate = 'Click the chart to view the data';
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
                      groupingType: charts.BarGroupingType.stacked),
                  domainAxis:
                      new charts.DateTimeAxisSpec(usingBarRenderer: true),
                  defaultInteractions: false,
                  behaviors: [
                    new charts.SeriesLegend(
                      position: charts.BehaviorPosition.top,
                      desiredMaxColumns: 1,
                    ),
                    new charts.ChartTitle('Energy (kWh)',
                        behaviorPosition: charts.BehaviorPosition.start,
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea),
                    new charts.SelectNearest(),
                    new charts.DomainHighlighter(),
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
        /// If the value in the selected bar is not null, then we create the
        /// string value to display
        if (datumPair.datum.analyticValue != null) {
          selectedDailyChargerBreakdownValue =
              datumPair.datum.analyticValue.toStringAsFixed(2) + 'kWh';
        }
      });

      /// Now create our final selectedDate string
      var formatter = new DateFormat('MMMMEEEEd');

      /// Update our selected date
      selectedDailyChargerBreakdownDate = '${formatter.format(date)}';

      setState(() {
        /// Once we have clicked on the bar chart, we need to scroll down to the
        /// bottom AFTER the widget updates
        Timer(
            Duration(milliseconds: 300),
            () => widget.scrollController.animateTo(
                widget.scrollController.position.maxScrollExtent,
                duration: Duration(milliseconds: 150),
                curve: Curves.easeIn));
      });
    }
  }

  Future<Null> grabDailyChargerBreakdown() async {
    /// This function grabs all of the data needed to draw the daily charger
    /// breakdown bar chart

    /// Define our list of ev chargers
    List evChargers = [];

    /// Now grab our ev chargers from Firebase, populate them in a list
    _evChargerRef = globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging');
    DataSnapshot snapshot = await _evChargerRef.once();
    evChargers = snapshot.value.keys.toList(growable: false);

    /// seriesArray is the final array of series to go into build
    var seriesArray = await grabChargerAnalyticsValues(evChargers, 15);

    if (this.mounted) {
      setState(() {
        dailyChargerBreakdownSeriesList = seriesArray;
      });
    }
  }

  Future grabChargerAnalyticsValues(evChargers, numDays) async {
    /// This function takes in the list of evChargers, grabs all of the
    /// charging analytics information for them and puts them into chart Series
    /// ready to be charted

    /// Initialize a dateFormatter
    var dateFormatter = new DateFormat('yyyy-MM-dd');

    /// Initialize our mapOfDataArrays.
    /// mapOfDataArrays will have key: charger ID and value as data array
    mapOfDataArrays = {};

    /// Loop through all of our EV Chargers
    for (String chargerID in evChargers) {
      /// Download charging history analytics for this EV Charger
      DataSnapshot tempSnapshot = await globals.database
          .reference()
          .child(
              'users/${globals.uid}/analytics/charging_history_analytics/$chargerID/')
          .limitToLast(numDays)
          .once();
      var tempData = tempSnapshot.value;

      if (tempData != null) {
        /// Initialize the charger ID's data array
        mapOfDataArrays[chargerID] = [];

        /// Now loop back from numDays to 0
        for (var i = numDays; i >= 0; i--) {
          /// Get the DateTime object of today subtracted by i days
          final now = DateTime.now();
          DateTime dateObject = new DateTime(now.year, now.month, now.day)
              .subtract(new Duration(days: i));

          /// Now format the DateTime object as a string
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
    }

    /// Once we have our map of data arrays, we can turn them into chart series
    List<charts.Series<AnalyticsData, DateTime>> seriesList = [];

    mapOfDataArrays.forEach((chargerID, dataArray) {
      seriesList.add(new charts.Series<AnalyticsData, DateTime>(
        id: chargerID,
        domainFn: (AnalyticsData sales, _) => sales.date,
        measureFn: (AnalyticsData sales, _) => sales.analyticValue,
        data: dataArray,
      ));
    });

    return seriesList;
  }

  startListeningToChargingStatus() async {
    /// Start a listener for changes in charging status of our chargers
    _chargingRef = globals.database
        .reference()
        .child('users/${globals.uid}/evc_inputs/charging');
    _chargingSubscription = _chargingRef.onValue.listen((Event event) async {
      grabDailyChargerBreakdown();
    });
  }

  @override
  void initState() {
    super.initState();
    startListeningToChargingStatus();
  }

  @override
  void dispose() {
    super.dispose();
    _chargingSubscription.cancel();
  }
}
