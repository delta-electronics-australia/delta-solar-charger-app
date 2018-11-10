import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class UserData {
  String displayName;
  String email;
  String uid;
  String password;

  UserData({this.displayName, this.email, this.uid, this.password});
}

class UserAuth {
  Future<String> createUser(UserData userData) async {
    FirebaseAuth firebaseAuth = FirebaseAuth.instance;
    try {
      await firebaseAuth.createUserWithEmailAndPassword(
          email: userData.email, password: userData.password);
      return "Account Created Successfully!";
    } catch (e) {
      print(e.toString());
      print(e.message);
      return e.message;
    }
  }

  Future<String> verifyUser(UserData userData) async {
    FirebaseAuth firebaseAuth = FirebaseAuth.instance;
    try {
      await firebaseAuth.signInWithEmailAndPassword(
          email: userData.email, password: userData.password);
      return "Login Successful";
    } catch (e) {
      return e.message;
    }
  }
}
