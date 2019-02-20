import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

import 'globals.dart' as globals;

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smart_charging_app/dashboard.dart';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  var _headingFont = new TextStyle(fontSize: 20.0);
  var _valueFont = new TextStyle(fontSize: 30.0);

  bool loadingData = true;

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
                accountName: Text(globals.displayName),
                accountEmail: Text(globals.displayEmail),
                decoration: new BoxDecoration(color: Colors.blue),
              ),
              globals.isAdmin
                  ? ListTile(
                      leading: const Icon(Icons.supervisor_account),
                      title: const Text('Admin Dashboard'),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    )
                  : new Container(),
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
                        new GestureDetector(
                          child: new Card(
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
                          onLongPress: () {
                            showDialog(
                                context: context,
                                builder: (builder) {
                                  return new AnalyticPieDialog(
                                    analyticName: 'energy_consumed',
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

    DateFormat todayDateFormat = new DateFormat('yyyy-MM-dd');

    /// First clear our existing statusTiles
    listOfSystemStatusTiles.clear();

    /// Now grab the status of the admin UID
    DataSnapshot latestSnapshot = await globals.database
        .reference()
        .child(
            'users/${globals.adminUID}/history/${todayDateFormat.format(DateTime.now())}')
        .limitToLast(1)
        .once();

//    /// Check if there are any charging chargers
//    DataSnapshot chargingChargers = await globals.database
//        .reference()
//        .child('users/${globals.adminUID}/evc_inputs/charging')
//        .once();
//
//    chargingChargers.value;

    /// Convert the latest history payload into a DateTime object
    DateTime latestDateTime = DateTime.parse(
        '${todayDateFormat.format(DateTime.now())}T${latestSnapshot.value[latestSnapshot.value.keys.toList()[0]]['time']}');
    print(latestDateTime);

    /// Now we can use this to compare to see if there has been any update in the past 15 minutes
    if ((DateTime.now().difference(latestDateTime).inMinutes) > 15) {
      adminUIDMap[globals.adminUID]['alive'] = false;
    } else {
      adminUIDMap[globals.adminUID]['alive'] = true;
    }

    /// Now we have to create the list of system status tiles
    listOfSystemStatusTiles.add(new ListTile(
      key: new ObjectKey(globals.adminUID),
      leading: new Padding(
        padding: const EdgeInsets.only(right: 10, top: 5),
        child: new Container(
          child: new Material(
            color: adminUIDMap[globals.adminUID]['alive']
                ? Colors.green
                : Colors.red,
            type: MaterialType.circle,
            child: new Container(
              width: 12,
              height: 12,
              child: InkWell(),
            ),
          ),
        ),
      ),
      title: new Text(adminUIDMap[globals.adminUID]['name']),
      trailing: new TrailingActiveChargerCount(uid: globals.adminUID),
      onTap: () {
        showModalBottomSheet(
            context: context,
            builder: (builder) {
              return new SystemInfoModal(
                  uid: globals.adminUID,
                  name: adminUIDMap[globals.adminUID]['name']);
            });
      },
    ));

    /// Now grab the status of all of the linked UIDs
    for (String linkedUID in linkedUIDsMap.keys.toList()) {
      DataSnapshot latestSnapshot = await globals.database
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
        trailing: new TrailingActiveChargerCount(uid: linkedUID),
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
    /// First start listeners with our linked UIDs
    for (String linkedUID in linkedUIDsMap.keys.toList()) {
      liveAnalyticsMap[linkedUID] = {};

      /// Start a listener with our linked UID
      linkedUIDsMap[linkedUID]['analyticsSubscription'] = globals.database
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

    liveAnalyticsMap[globals.adminUID] = {};

    /// Then start a listener with our admin UID
    _adminAnalyticsSubscription = globals.database
        .reference()
        .child('users/${globals.adminUID}/analytics/live_analytics')
        .onValue
        .listen((Event event) {
      /// Now add all of the new information into the liveAnalyticsMap under
      Map snapshot = event.snapshot.value;
      liveAnalyticsMap[globals.adminUID]['btp_charged_t'] =
          (snapshot['btp_charged_t'] * -1);
      liveAnalyticsMap[globals.adminUID]['btp_consumed_t'] =
          snapshot['btp_consumed_t'];
      liveAnalyticsMap[globals.adminUID]['dcp_t'] = snapshot['dcp_t'];
      liveAnalyticsMap[globals.adminUID]['utility_p_export_t'] =
          snapshot['utility_p_export_t'];
      liveAnalyticsMap[globals.adminUID]['utility_p_import_t'] =
          (snapshot['utility_p_import_t'] * -1);
      liveAnalyticsMap[globals.adminUID]['ac2p_t'] = (snapshot['ac2p_t']);

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
    List linkedUIDsList = [];

    /// First get a list of all of our linked UIDs
    _linkedUIDSubscription = globals.database
        .reference()
        .child('users/${globals.adminUID}/user_info/linked_accounts')
        .onValue
        .listen((Event event) async {
      killAllSubscriptions();
      linkedUIDsList = event.snapshot.value.keys.toList();

      /// Now using our list of linked UIDs, we need to get the information for these
      /// linked UIDs
      for (String linkedUID in linkedUIDsList) {
        linkedUIDsMap[linkedUID] = {};

        DataSnapshot linkedUIDName = await globals.database
            .reference()
            .child('users/$linkedUID/user_info/nickname')
            .once();

        linkedUIDsMap[linkedUID]['name'] = linkedUIDName.value;
      }

      /// Now get information about the admin UID
      adminUIDMap[globals.adminUID] = {};
      DataSnapshot adminUIDName = await globals.database
          .reference()
          .child('users/${globals.adminUID}/user_info/nickname')
          .once();

      adminUIDMap[globals.adminUID]['name'] = adminUIDName.value;

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

    grabLinkedUIDInfo();
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
      padding: const EdgeInsets.all(1.0),
      child: loadingData
          ? new Center(
              child: const Center(child: const CircularProgressIndicator()))
          : new ListView(
              shrinkWrap: true,
//              physics: NeverScrollableScrollPhysics(),
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
                new RaisedButton(
                  child: const Text('Go to Dashboard'),
                  onPressed: () async {
                    /// First define the uid that we will use for our dashboard
                    globals.uid = widget.uid;

                    /// Then define the system name we will use for the dashboard
                    globals.getSystemName(widget.uid);
                    var route = new MaterialPageRoute(
                        builder: (BuildContext context) => new Dashboard(),
                        settings: RouteSettings(name: '/Dashboard'));
                    Navigator.of(context).pop();
                    Navigator.of(context).push(route);
                  },
                )
              ],
            ),
    );
  }

  void getSystemInfo() async {
    _systemAnalyticsSubscription = globals.database
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

  String chartTitle;

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
                    new charts.ChartTitle(chartTitle,
                        maxWidthStrategy: charts.MaxWidthStrategy.truncate,
                        behaviorPosition: charts.BehaviorPosition.top,
                        subTitle: '(kWh)',
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea),
                    new charts.SelectNearest(),
                    new charts.DomainHighlighter(),
                  ],
                  defaultRenderer: new charts.ArcRendererConfig(
                      arcRendererDecorators: [new charts.ArcLabelDecorator()]),
                  selectionModels: [
                    new charts.SelectionModelConfig(
                      type: charts.SelectionModelType.info,
                      changedListener: _onSelectionChanged,
                    )
                  ],
                ),
              ),
//              selectedAnalyticsData == null
//                  ? new ListTile(
//                      title: new Text(
//                        "Please click the pie chart",
//                        textAlign: TextAlign.center,
//                        style: TextStyle(fontWeight: FontWeight.bold),
//                      ),
//                    )
//                  : new ListTile(
//                      title: new Text(selectedAnalyticsDataLabel),
//                    )
            ],
    );
  }

  _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;
//    print(selectedDatum.first.datum.label);
//    print(selectedDatum.first.datum.value);

    selectedAnalyticsDataLabel = selectedDatum.first.datum.label;
    selectedAnalyticsData = selectedDatum.first.datum.value.toString();
//    setState(() {});
  }

  void grabAnalyticsBreakdown() async {
    /// This function will grab all of the data we need to build a pie chart
    /// that breaks down the analytic name

    List<AnalyticsData> chartData = [
//      new AnalyticsData(0, 100),
    ];

    for (String linkedUID in widget.linkedUIDMap.keys.toList()) {
      if (widget.analyticName == "solar") {
        chartTitle = 'Solar Energy Breakdown';

        DataSnapshot snapshot = await globals.database
            .reference()
            .child('users/$linkedUID/analytics/live_analytics/dcp_t')
            .once();
        print(snapshot.value);
        chartData.add(new AnalyticsData(
            0,
            double.parse(snapshot.value.toStringAsFixed(2)),
            widget.linkedUIDMap[linkedUID]['name']));

        snapshot = await globals.database
            .reference()
            .child('users/${globals.adminUID}/analytics/live_analytics/dcp_t')
            .once();
        print(snapshot.value);
        chartData.add(new AnalyticsData(
            1,
            double.parse(snapshot.value.toStringAsFixed(2)),
            widget.adminUIDMap[globals.adminUID]['name']));
      } else if (widget.analyticName == "energy_consumed") {
        chartTitle = 'Consumed Energy Breakdown';

        DataSnapshot snapshot = await globals.database
            .reference()
            .child('users/$linkedUID/analytics/live_analytics/ac2p_t')
            .once();
        print(snapshot.value);
        chartData.add(new AnalyticsData(
            0,
            double.parse(snapshot.value.toStringAsFixed(2)),
            widget.linkedUIDMap[linkedUID]['name']));

        snapshot = await globals.database
            .reference()
            .child('users/${globals.adminUID}/analytics/live_analytics/ac2p_t')
            .once();
        print(snapshot.value);
        chartData.add(new AnalyticsData(
            1,
            double.parse(snapshot.value.toStringAsFixed(2)),
            widget.adminUIDMap[globals.adminUID]['name']));
      }
    }

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
    setState(() {});
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

class TrailingActiveChargerCount extends StatefulWidget {
  TrailingActiveChargerCount({Key key, @required this.uid}) : super(key: key);

  final String uid;

  @override
  _TrailingActiveChargerCountState createState() =>
      _TrailingActiveChargerCountState();
}

class _TrailingActiveChargerCountState
    extends State<TrailingActiveChargerCount> {
  /// Define the integer representing the number of active chargers we have
  int numActiveChargers;

  /// Define our subscription to the charging node
  StreamSubscription chargingNodeSubscription;

  @override
  Widget build(BuildContext context) {
    return numActiveChargers != null
        ? new Text(convertNumChargersIntoString())
        : new Text('loading...');
  }

  String convertNumChargersIntoString() {
    /// This function takes the numActiveChargers that we have and returns
    /// a string that is readable

    String finalString;

    if (numActiveChargers == 0) {
      finalString = "No Chargers Active";
    } else if (numActiveChargers == 1) {
      finalString = "1 Charger Active";
    } else {
      finalString = "$numActiveChargers Chargers Active";
    }

    return finalString;
  }

  startActiveChargerListener() async {
    /// This function will listen to how many active chargers there are

    chargingNodeSubscription = globals.database
        .reference()
        .child('users/${widget.uid}/evc_inputs/charging')
        .onValue
        .listen((Event event) {
      DataSnapshot chargingSnapshot = event.snapshot;

      /// Reset the number of active chargers
      numActiveChargers = 0;

      Map chargingNode = chargingSnapshot.value;

      for (String chargerID in chargingNode.keys.toList(growable: false)) {
        if (chargingNode[chargerID] != false) {
          numActiveChargers += 1;
        }
      }

      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();

    startActiveChargerListener();
  }

  @override
  void didUpdateWidget(TrailingActiveChargerCount oldWidget) {
    super.didUpdateWidget(oldWidget);

    numActiveChargers = null;
    startActiveChargerListener();
  }

  @override
  void dispose() {
    super.dispose();

    if (chargingNodeSubscription != null) {
      chargingNodeSubscription.cancel();
    }
  }
}
