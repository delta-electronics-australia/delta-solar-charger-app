import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_charging_app/dashboard.dart';
import 'package:smart_charging_app/liveDataStream.dart';
import 'package:smart_charging_app/solarChargerSettings.dart';
import 'package:smart_charging_app/chargeSession.dart';
import 'package:smart_charging_app/charging_archive.dart';
import 'package:smart_charging_app/inverter_archive.dart';
import 'package:smart_charging_app/charger_info.dart';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  var _headingFont = new TextStyle(fontSize: 20.0);
  var _valueFont = new TextStyle(fontSize: 30.0);

  bool isAdminAccount = true;

  bool loadingData = true;

  /// Initialize the strings that will define our display name and email
  String _displayName = "";
  String _displayEmail = "";

  /// Initialize the current back press time
  DateTime currentBackPressTime = DateTime.now().subtract(Duration(seconds: 3));

  /// Initialize our admin analytics subscriptions
  StreamSubscription _adminAnalyticsSubscription;

  /// Initialize a subscription for our linked UIDs
  StreamSubscription _linkedUIDSubscription;

  /// Initialize a Map to store information about our admin UID
  Map adminUIDMap = {};

  /// Initialize a Map to store information about our linked UIDs
  Map linkedUIDsMap = {};

  /// Initialize a map containing the analytics subcriptions for all our linked uids
  Map<String, StreamSubscription> linkedAnalyticsSubscriptionMap = {};

  /// Initialize the last updated time for dashboard
  String lastUpdatedDatetime;

  Map liveAnalyticsMap = {};

  Map<String, dynamic> summedLiveAnalytics = {
    'btp_charged_t': '0.0',
    'btp_consumed_t': '0.0',
    'dcp_t': '0.0',
    'utility_p_export_t': '0.0',
    'utility_p_import_t': '0.0',
  };

  Timer _systemStatusTimer;

  List<Widget> listOfSystemStatusTiles = [];

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        child: new Scaffold(
            appBar: new AppBar(
              title: const Text("Admin Dashboard"),
            ),
            drawer: new Drawer(
                child: ListView(children: <Widget>[
              UserAccountsDrawerHeader(
                accountName: Text(_displayName),
                accountEmail: Text(_displayEmail),
                decoration: new BoxDecoration(color: Colors.blue),
              ),
              isAdminAccount
                  ? ListView(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.supervisor_account),
                          title: const Text('Admin Dashboard'),
                          onTap: () {
                            Navigator.of(context).pop();
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
                  var route = new MaterialPageRoute(
                      builder: (BuildContext context) => new Dashboard());
                  Navigator.of(context).pop();
                  Navigator.of(context).push(route);
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
                    child:
                        const Center(child: const CircularProgressIndicator()))
                :
                // Todo: missing refresh indicator, scroll controller
                new Center(
                    child: new ListView(
                      children: <Widget>[
                        new GestureDetector(
                          child: new Card(
                            child: new Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                new ListTile(
                                  title: new Center(
                                      child: new Text(
                                    "Total Solar Generated Today",
                                    style: _headingFont,
                                  )),
                                ),
                                new ListTile(
                                    title: new Center(
                                        child: new Text(
                                  "${summedLiveAnalytics['dcp_t']}",
                                  style: _valueFont,
                                ))),
                              ],
                            ),
                          ),
                          onLongPress: () {
                            showDialog(
                                context: context,
                                builder: (builder) {
                                  return new AnalyticPieDialog(
                                    analyticName: 'solar',
                                    linkedUIDMap: linkedUIDsMap,
                                    adminUIDMap: adminUIDMap,
                                  );
                                });
                          },
                        ),
                        new Card(
                          child: new Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              new ListTile(
                                  title: new Center(
                                      child: new Text(
                                "Total Energy Consumed Today",
                                style: _headingFont,
                              ))),
                              new ListTile(
                                  title: new Center(
                                      child: new Text(
                                "${summedLiveAnalytics['ac2p_t']}",
                                style: _valueFont,
                              ))),
                            ],
                          ),
                        ),
                        new Card(
                          child: new Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              new ExpansionTile(
                                title: Text(
                                  'Systems Overview',
                                  textAlign: TextAlign.center,
                                  style: _headingFont,
                                ),
                                children: listOfSystemStatusTiles,
                                initiallyExpanded: true,
                              )
                            ],
                          ),
                        ),
                        new Text(
                          'Last updated: $lastUpdatedDatetime',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10),
                        )
                      ],
                    ),
                  )),
        onWillPop: onWillPop);
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

  void grabSystemStatus() async {
    /// This function grabs all system statuses

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    DateFormat todayDateFormat = new DateFormat('yyyy-MM-dd');

    /// First clear our existing statusTiles
    listOfSystemStatusTiles.clear();

    /// Now grab the status of the admin UID
    DataSnapshot latestSnapshot = await database
        .reference()
        .child('users/$uid/history/${todayDateFormat.format(DateTime.now())}')
        .limitToLast(1)
        .once();

    /// Convert the latest history payload into a DateTime object
    DateTime latestDateTime = DateTime.parse(
        '${todayDateFormat.format(DateTime.now())}T${latestSnapshot.value[latestSnapshot.value.keys.toList()[0]]['time']}');
    print(latestDateTime);

    /// Now we can use this to compare to see if there has been any update in the past 15 minutes
    if ((DateTime.now().difference(latestDateTime).inMinutes) > 15) {
      adminUIDMap[uid]['alive'] = false;
    } else {
      adminUIDMap[uid]['alive'] = true;
    }

    /// Now we have to create the list of system status tiles
    listOfSystemStatusTiles.add(new ListTile(
      key: new ObjectKey(uid),
      leading: new Padding(
        padding: const EdgeInsets.only(right: 10, top: 5),
        child: new Container(
          child: new Material(
            color: adminUIDMap[uid]['alive'] ? Colors.green : Colors.red,
            type: MaterialType.circle,
            child: new Container(
              width: 12,
              height: 12,
              child: InkWell(),
            ),
          ),
        ),
      ),
      title: new Text(adminUIDMap[uid]['name']),
      onTap: () {
        showModalBottomSheet(
            context: context,
            builder: (builder) {
              return new SystemInfoModal(
                  uid: uid, name: adminUIDMap[uid]['name']);
            });
      },
    ));

    /// Now grab the status of all of the linked UIDs
    for (String linkedUID in linkedUIDsMap.keys.toList()) {
      DataSnapshot latestSnapshot = await database
          .reference()
          .child(
              'users/$linkedUID/history/${todayDateFormat.format(DateTime.now())}')
          .limitToLast(1)
          .once();

      /// Convert the latest history payload into a DateTime object
      DateTime latestDateTime = DateTime.parse(
          '${todayDateFormat.format(DateTime.now())}T${latestSnapshot.value[latestSnapshot.value.keys.toList()[0]]['time']}');
      print(latestDateTime);

      /// Now we can use this to compare to see if there has been any update in the past 15 minutes
      if ((DateTime.now().difference(latestDateTime).inMinutes) > 15) {
        linkedUIDsMap[linkedUID]['alive'] = false;
      } else {
        linkedUIDsMap[linkedUID]['alive'] = true;
      }

      /// Now finally add these systems into tiles
      listOfSystemStatusTiles.add(new ListTile(
        key: new ObjectKey(linkedUID),
        leading: new Padding(
          padding: const EdgeInsets.only(right: 10, top: 5),
          child: new Container(
            child: new Material(
              color:
                  linkedUIDsMap[linkedUID]['alive'] ? Colors.green : Colors.red,
              type: MaterialType.circle,
              child: new Container(
                width: 12,
                height: 12,
                child: InkWell(),
              ),
            ),
          ),
        ),
        title: new Text(linkedUIDsMap[linkedUID]['name']),
        onTap: () {
          showModalBottomSheet(
              context: context,
              builder: (builder) {
                return new SystemInfoModal(
                    uid: linkedUID, name: linkedUIDsMap[linkedUID]['name']);
              });
        },
      ));
    }
    setState(() {});
  }

  void grabAggregateAnalytics() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    /// First start listeners with our linked UIDs
    for (String linkedUID in linkedUIDsMap.keys.toList()) {
      liveAnalyticsMap[linkedUID] = {};

      /// Start a listener with our linked UID
      linkedUIDsMap[linkedUID]['analyticsSubscription'] = database
          .reference()
          .child('users/$linkedUID/analytics/live_analytics')
          .onValue
          .listen((Event event) {
        /// Now add all of the new information into the liveAnalyticsMap
        /// under the linkedUID
        Map snapshot = event.snapshot.value;
        liveAnalyticsMap[linkedUID]['btp_charged_t'] =
            (snapshot['btp_charged_t'] * -1);
        liveAnalyticsMap[linkedUID]['btp_consumed_t'] =
            snapshot['btp_consumed_t'];
        liveAnalyticsMap[linkedUID]['dcp_t'] = snapshot['dcp_t'];
        liveAnalyticsMap[linkedUID]['utility_p_export_t'] =
            snapshot['utility_p_export_t'];
        liveAnalyticsMap[linkedUID]['utility_p_import_t'] =
            (snapshot['utility_p_import_t'] * -1);
        liveAnalyticsMap[linkedUID]['ac2p_t'] = (snapshot['ac2p_t']);

        lastUpdatedDatetime = snapshot['time'];
      });
    }

    liveAnalyticsMap[uid] = {};

    /// Then start a listener with our admin UID
    _adminAnalyticsSubscription = database
        .reference()
        .child('users/$uid/analytics/live_analytics')
        .onValue
        .listen((Event event) {
      /// Now add all of the new information into the liveAnalyticsMap under
      Map snapshot = event.snapshot.value;
      liveAnalyticsMap[uid]['btp_charged_t'] = (snapshot['btp_charged_t'] * -1);
      liveAnalyticsMap[uid]['btp_consumed_t'] = snapshot['btp_consumed_t'];
      liveAnalyticsMap[uid]['dcp_t'] = snapshot['dcp_t'];
      liveAnalyticsMap[uid]['utility_p_export_t'] =
          snapshot['utility_p_export_t'];
      liveAnalyticsMap[uid]['utility_p_import_t'] =
          (snapshot['utility_p_import_t'] * -1);
      liveAnalyticsMap[uid]['ac2p_t'] = (snapshot['ac2p_t']);

      lastUpdatedDatetime = snapshot['time'];

      /// Now we have to add up all of the analytics and setState

      summedLiveAnalytics = {
        'btp_charged_t': 0,
        'btp_consumed_t': 0,
        'dcp_t': 0,
        'utility_p_export_t': 0,
        'utility_p_import_t': 0,
        'ac2p_t': 0
      };

      for (Map analyticsMap in liveAnalyticsMap.values) {
        analyticsMap.forEach((dataString, value) {
          summedLiveAnalytics[dataString] += value;
        });
      }

      summedLiveAnalytics.forEach((dataString, summedValue) {
        summedLiveAnalytics[dataString] =
            summedValue.toStringAsFixed(2) + 'kWh';
      });

      loadingData = false;

      setState(() {});
    });
  }

  void grabLinkedUIDInfo() async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    List linkedUIDsList = [];

    /// First get a list of all of our linked UIDs
    _linkedUIDSubscription = database
        .reference()
        .child('users/$uid/user_info/linked_accounts')
        .onValue
        .listen((Event event) async {
      killAllSubscriptions();
      linkedUIDsList = event.snapshot.value.keys.toList();

      /// Now using our list of linked UIDs, we need to get the information for these
      /// linked UIDs
      for (String linkedUID in linkedUIDsList) {
        linkedUIDsMap[linkedUID] = {};

        DataSnapshot linkedUIDName = await database
            .reference()
            .child('users/$linkedUID/user_info/nickname')
            .once();

        linkedUIDsMap[linkedUID]['name'] = linkedUIDName.value;
      }

      /// Now get information about the admin UID
      adminUIDMap[uid] = {};
      DataSnapshot adminUIDName = await database
          .reference()
          .child('users/$uid/user_info/nickname')
          .once();

      adminUIDMap[uid]['name'] = adminUIDName.value;

      /// Now grab all of our aggregate analytics (for the top cards)
      grabAggregateAnalytics();

      /// Now grab the initial system status
      grabSystemStatus();

      /// Now set a timer so that this function runs every 2 minutes
      _systemStatusTimer =
          new Timer.periodic(const Duration(minutes: 2), (Timer t) {
        grabSystemStatus();
      });
    });
  }

  void getUserDetails() {
    FirebaseAuth.instance.currentUser().then((FirebaseUser user) async {
      final FirebaseDatabase database = new FirebaseDatabase();
      database
          .reference()
          .child('users/${user.uid}/user_info/account_type')
          .once()
          .then((DataSnapshot snapshot) {
        if (snapshot.value == "admin") {
          isAdminAccount = true;
        } else {
          isAdminAccount = false;
        }
      });

      setState(() {
        _displayName = user.displayName;
        _displayEmail = user.email;
      });
    });
  }

  void killAllSubscriptions() async {
    if (_adminAnalyticsSubscription != null) {
      _adminAnalyticsSubscription.cancel();
    }
    if (_systemStatusTimer != null) {
      _systemStatusTimer.cancel();
    }

    /// Cancel the subscriptions of all of our linked UIDs
    for (String linkedUID in linkedUIDsMap.keys.toList()) {
      linkedUIDsMap[linkedUID]['analyticsSubscription'].cancel();
    }
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
    getUserDetails();

    grabLinkedUIDInfo();

//    grabSystemStatus();
  }

  @override
  void dispose() {
    super.dispose();
    _linkedUIDSubscription.cancel();
    killAllSubscriptions();
  }
}

class SystemInfoModal extends StatefulWidget {
  SystemInfoModal({Key key, @required this.uid, @required this.name})
      : super(key: key);

  /// uid will be the uid of the system that was tapped
  final String uid;

  final String name;

  @override
  _SystemInfoModalState createState() => _SystemInfoModalState();
}

class _SystemInfoModalState extends State<SystemInfoModal> {
  bool loadingData = true;

  bool systemOnline = true;

  Map systemInfo = {};

  StreamSubscription _systemAnalyticsSubscription;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: loadingData
          ? new Center(
              child: const Center(child: const CircularProgressIndicator()))
          : new ListView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[
                new Padding(
                  padding: const EdgeInsets.all(8),
                  child: new Row(
                    children: <Widget>[
                      new Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: new Container(
                          child: new Material(
                            color: systemOnline ? Colors.green : Colors.red,
                            type: MaterialType.circle,
                            child: new Container(
                              width: 16,
                              height: 16,
                              child: InkWell(),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '${widget.name}',
//                    textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      )
                    ],
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                ),
                new ListTile(
                  leading: Icon(Icons.wb_sunny),
                  title: const Text(
                    'Solar Generated Today',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: new Text(systemInfo['dcp_t']),
                ),
                new ListTile(
                  leading: Icon(Icons.power),
                  title: const Text(
                    'Energy Consumed Today',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: new Text(systemInfo['ac2p_t']),
                ),
                new ListTile(
                  leading: Icon(Icons.import_export),
                  title: const Text('Energy Exported Today',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: new Text(systemInfo['utility_p_export_t']),
                ),
                new ListTile(
                  leading: Icon(Icons.import_export),
                  title: const Text('Energy Imported Today',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: new Text(systemInfo['utility_p_import_t']),
                ),
                new ListTile(
                  leading: Icon(Icons.battery_std),
                  title: const Text('Battery Consumed Today',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: new Text(systemInfo['btp_consumed_t']),
                ),
                new ListTile(
                  leading: Icon(Icons.battery_charging_full),
                  title: const Text('Battery Charged Today',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: new Text(systemInfo['btp_charged_t']),
                ),
              ],
            ),
    );
  }

  void getSystemInfo() async {
    final FirebaseDatabase database = new FirebaseDatabase();

    _systemAnalyticsSubscription = database
        .reference()
        .child('users/${widget.uid}/analytics/live_analytics')
        .onValue
        .listen((Event event) {
      /// Now add all of the new information into the liveAnalyticsMap
      /// under the linkedUID
      Map snapshot = event.snapshot.value;
      systemInfo['btp_charged_t'] =
          (snapshot['btp_charged_t'] * -1).toStringAsFixed(2) + 'kWh';
      systemInfo['btp_consumed_t'] =
          snapshot['btp_consumed_t'].toStringAsFixed(2) + 'kWh';
      systemInfo['dcp_t'] = snapshot['dcp_t'].toStringAsFixed(2) + 'kWh';
      systemInfo['utility_p_export_t'] =
          snapshot['utility_p_export_t'].toStringAsFixed(2) + 'kWh';
      systemInfo['utility_p_import_t'] =
          (snapshot['utility_p_import_t'] * -1).toStringAsFixed(2) + 'kWh';
      systemInfo['ac2p_t'] = (snapshot['ac2p_t']).toStringAsFixed(2) + 'kWh';

//      lastUpdatedDatetime = snapshot['time'];
      setState(() {
        loadingData = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    getSystemInfo();
  }

  @override
  void dispose() {
    super.dispose();
    _systemAnalyticsSubscription.cancel();
  }
}

class AnalyticPieDialog extends StatefulWidget {
  AnalyticPieDialog(
      {Key key,
      @required this.analyticName,
      @required this.linkedUIDMap,
      @required this.adminUIDMap})
      : super(key: key);

  /// analyticName is the name of the card that we want to show a pie chart for
  final String analyticName;
  final Map linkedUIDMap;
  final Map adminUIDMap;

  @override
  _AnalyticPieDialogState createState() => _AnalyticPieDialogState();
}

class _AnalyticPieDialogState extends State<AnalyticPieDialog> {
  List<charts.Series<AnalyticsData, double>> pieChartSeriesList;

  String selectedAnalyticsData;
  String selectedAnalyticsDataLabel;

  ObjectKey analyticsPieChartKey;

  @override
  Widget build(BuildContext context) {
    return new SimpleDialog(
      children: pieChartSeriesList == null
          ? <Widget>[
              new Center(
                  child: const Center(child: const CircularProgressIndicator()))
            ]
          : <Widget>[
              new SizedBox(
                height: MediaQuery.of(context).size.height / 2,
                width: MediaQuery.of(context).size.width,
                child: new charts.PieChart(
                  pieChartSeriesList,
                  animate: true,
                  behaviors: [
                    new charts.ChartTitle('Solar Energy Breakdown (kWh)',
                        behaviorPosition: charts.BehaviorPosition.top,
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea),
                    new charts.SelectNearest(),
                    new charts.DomainHighlighter(),
                  ],
                  defaultRenderer: new charts.ArcRendererConfig(
                      arcRendererDecorators: [new charts.ArcLabelDecorator()]),
//                  selectionModels: [
//                    new charts.SelectionModelConfig(
//                      type: charts.SelectionModelType.info,
//                      changedListener: _onSelectionChanged,
//                    )
//                  ],
                ),
                key: analyticsPieChartKey,
              ),
              selectedAnalyticsData == null
                  ? new ListTile(
                      title: new Text(
                        "Please click the pie chart",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  : new ListTile(
                      title: new Text(selectedAnalyticsDataLabel),
                    )
            ],
    );
  }

  _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;
//    print(selectedDatum.first.datum.label);
//    print(selectedDatum.first.datum.value);

    selectedAnalyticsDataLabel = selectedDatum.first.datum.label;
    selectedAnalyticsData = selectedDatum.first.datum.value.toString();
    setState(() {});
  }

  void grabAnalyticsBreakdown() async {
    /// This function will grab all of the data we need to build a pie chart
    /// that breaks down the analytic name

    FirebaseUser user = await FirebaseAuth.instance.currentUser();
    final FirebaseDatabase database = new FirebaseDatabase();
    String uid = user.uid;

    List<AnalyticsData> chartData = [
//      new AnalyticsData(0, 100),
//      new AnalyticsData(1, 75),
//      new AnalyticsData(2, 25),
//      new AnalyticsData(3, 5),
    ];

//    DateFormat todayDateFormat = new DateFormat('yyyy-MM-dd');

    for (String linkedUID in widget.linkedUIDMap.keys.toList()) {
      if (widget.analyticName == "solar") {
        DataSnapshot snapshot = await database
            .reference()
            .child('users/$linkedUID/analytics/live_analytics/dcp_t')
            .once();
        print(snapshot.value);
        chartData.add(new AnalyticsData(
            0,
            double.parse(snapshot.value.toStringAsFixed(2)),
            widget.linkedUIDMap[linkedUID]['name']));
      }
    }

    DataSnapshot snapshot = await database
        .reference()
        .child('users/$uid/analytics/live_analytics/dcp_t')
        .once();
    print(snapshot.value);
    chartData.add(new AnalyticsData(
        1,
        double.parse(snapshot.value.toStringAsFixed(2)),
        widget.adminUIDMap[uid]['name']));

    pieChartSeriesList = [
      new charts.Series<AnalyticsData, double>(
        id: 'Sales',
        domainFn: (AnalyticsData sales, _) => sales.date,
        measureFn: (AnalyticsData sales, _) => sales.value,
        data: chartData,

        // Set a label accessor to control the text of the arc label.
        labelAccessorFn: (AnalyticsData row, _) =>
            '${row.label} - ${row.value}',
      )
    ];
    setState(() {
      analyticsPieChartKey = new ObjectKey(widget.analyticName);
    });
  }

  @override
  void initState() {
    super.initState();
    grabAnalyticsBreakdown();
  }
}

class AnalyticsData {
  final double date;
  final double value;
  final String label;

  AnalyticsData(this.date, this.value, this.label);
}
