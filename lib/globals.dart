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
  print('Im in check for adminstatus');

  FirebaseUser user = await FirebaseAuth.instance.currentUser();

  final FirebaseDatabase database = new FirebaseDatabase();
  DataSnapshot snapshot = await database
      .reference()
      .child('users/${user.uid}/user_info/account_type')
      .once();

  if (snapshot.value == "admin") {
    print('isAdmin is set to true now');
    isAdmin = true;
  } else {
    isAdmin = false;
  }

  return snapshot.value == "admin";
}

Future<Null> getUserDetails() async {
  FirebaseUser user = await FirebaseAuth.instance.currentUser();

  displayName = user.displayName;
  displayEmail = user.email;

  return null;
}

Future<Null> getFirebaseUID() async {
  FirebaseUser user = await FirebaseAuth.instance.currentUser();
  database = new FirebaseDatabase();
  uid = adminUID = user.uid;

  return null;
}

Future<Null> getSystemName(uid) async {
  database = new FirebaseDatabase();

  DataSnapshot currentSystemNameSnapshot = await database
      .reference()
      .child('users')
      .child(uid)
      .child('user_info')
      .child('nickname')
      .once();

  print(currentSystemNameSnapshot.value);
  if (currentSystemNameSnapshot.value == null) {
    systemName = displayEmail.split('@')[0];
  } else {
    systemName = currentSystemNameSnapshot.value;
  }
}
