library smart_charging_app.globals;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

bool isAdmin = false;

String displayName = "";
String displayEmail = "";

String systemName = "";

FirebaseDatabase database;
String uid;
String adminUID;

Future<bool> checkForAdminStatus() async {
  /// This function checks if the currently logged in account is a
  /// Solar Charger admin account and returns a boolean.

  FirebaseUser user = await FirebaseAuth.instance.currentUser();

  final FirebaseDatabase database = new FirebaseDatabase();
  DataSnapshot snapshot = await database
      .reference()
      .child('users/${user.uid}/user_info/account_type')
      .once();

  /// If the account_type is admin then we set the admin global variable to true
  if (snapshot.value == "admin") {
    isAdmin = true;
  } else {
    isAdmin = false;
  }

  return snapshot.value == "admin";
}

Future<Null> getUserDetails() async {
  /// This function gets the details of the currently logged in account so that
  /// we don't have to retrieve it on every page

  FirebaseUser user = await FirebaseAuth.instance.currentUser();

  displayName = user.displayName;
  displayEmail = user.email;

  return null;
}

Future<Null> getFirebaseUID() async {
  /// Initializes the uid and database global variables

  FirebaseUser user = await FirebaseAuth.instance.currentUser();
  database = new FirebaseDatabase();
  uid = adminUID = user.uid;

  return null;
}

Future<Null> getSystemName(uid) async {
  /// This function takes in a uid and grabs the name of the system

  database = new FirebaseDatabase();

  DataSnapshot currentSystemNameSnapshot = await database
      .reference()
      .child('users')
      .child(uid)
      .child('user_info')
      .child('nickname')
      .once();

  /// If the name does not yet exist, then we will use the email as the
  /// system name

  if (currentSystemNameSnapshot.value == null) {
    systemName = displayEmail.split('@')[0];
  } else {
    systemName = currentSystemNameSnapshot.value;
  }
}
