import 'package:flutter/material.dart';
import 'dart:async';

import 'package:smart_charging_app/authenticate.dart';
import 'globals.dart' as globals;

import 'package:smart_charging_app/admin_dashboard.dart';
import 'package:smart_charging_app/dashboard.dart';
import 'package:smart_charging_app/initial_setup.dart';

import 'package:firebase_auth/firebase_auth.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Delta Solar Charger App',
        theme: new ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: new LandingPage(),
        routes: <String, WidgetBuilder>{
          "/AdminDashboard": (BuildContext context) => new AdminDashboard(),
          "/Dashboard": (BuildContext context) => new Dashboard(),
          "/InitialSetup": (BuildContext context) => new InitialSetup()
        });
  }
}

class LandingPage extends StatefulWidget {
  LandingPage({Key key}) : super(key: key);

  @override
  _LandingPageState createState() => new _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _headingFont = const TextStyle(fontSize: 20.0);
  bool loggingIn = false;

  final TextEditingController _email = new TextEditingController();
  final TextEditingController _pass = new TextEditingController();

  final FocusNode _emailFocus = new FocusNode();
  final FocusNode _passFocus = new FocusNode();

  UserData user = new UserData();
  UserAuth userAuth = new UserAuth();

  String get email => _email.text;

  String get password => _pass.text;

  void handleInitialSetup() {
    Navigator.pushNamed(context, "/InitialSetup");
  }

  Future<Null> _signOut() async {
    await FirebaseAuth.instance.signOut();
    print('Signed out');
  }

  void initializePostLoginGlobals() async {
    /// This function initializes all of our global variables needed to login
    /// to an admin account

    /// First we bring up the circular indicator
    setState(() {
      loggingIn = true;
    });

    /// Check if this account is an admin account
    bool isAdmin = await globals.checkForAdminStatus();

    /// Get the user details of this account
    await globals.getUserDetails();

    /// Now initialize all of our Firebase global variables
    await globals.getFirebaseUID();

    /// If the account is an admin account, then we go to the admin dashboard
    if (isAdmin) {
      Navigator.pushNamed(context, "/AdminDashboard");
    } else {
      Navigator.pushNamed(context, "/Dashboard");
    }
  }

  void _handleLogin() {
    /// This function is run when the user presses the login button

    /// Set loggingIn to true, so we have a circular progress icon
    setState(() {
      loggingIn = true;
    });

    user.email = email;
    user.password = password;

    /// Now we verify the user using the inputted credentials
    userAuth.verifyUser(user).then((onValue) async {
      print(onValue);
      if (onValue == "Login Successful") {
        initializePostLoginGlobals();
      } else {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (buildContext) {
              return new AlertDialog(
                title: Text('Sign in Error'),
                content: Text(onValue),
                actions: <Widget>[
                  new FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          loggingIn = false;
                        });
                      },
                      child: Text('Try Again'))
                ],
              );
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.

    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Delta Solar Charger'),
        ),
        body: new Container(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0),

          child: StreamBuilder(
              stream: FirebaseAuth.instance.onAuthStateChanged,
              builder:
                  (BuildContext context, AsyncSnapshot<FirebaseUser> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                    return CircularProgressIndicator();

                  default:

                    /// If the currentUser() returns and there is no user data
                    if (snapshot.data == null) {
                      /// Then we know that there is no existing user
                      return new Center(
                          child: loggingIn
                              ? const Center(
                                  child: const CircularProgressIndicator())
                              : new Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                      new Text("Please Login",
                                          style: _headingFont),
                                      new Padding(
                                        padding:
                                            const EdgeInsets.only(top: 30.0),
                                      ),
                                      new ListTile(
                                          leading: const Icon(Icons.email),
                                          title: new TextField(
                                            controller: _email,
                                            focusNode: _emailFocus,
                                            onSubmitted: (String value) {
                                              FocusScope.of(context)
                                                  .requestFocus(_passFocus);
                                            },
                                            decoration: new InputDecoration(
                                                hintText: "Email"),
                                          )),
                                      new ListTile(
                                          leading: const Icon(Icons.lock),
                                          title: new TextField(
                                            controller: _pass,
                                            focusNode: _passFocus,
                                            onSubmitted: (String value) {
                                              _handleLogin();
                                            },
                                            decoration: new InputDecoration(
                                                hintText: "Password"),
                                            obscureText: true,
                                          )),
                                      new Padding(
                                        padding: const EdgeInsets.all(15.0),
                                      ),
                                      new RaisedButton(
                                        child: new Text("Login"),
                                        onPressed: _handleLogin,
                                        padding:
                                            const EdgeInsets.only(top: 1.0),
                                      ),
                                      new Padding(
                                          padding: EdgeInsets.all(15.0)),
                                      new RaisedButton(
                                        onPressed: handleInitialSetup,
                                        child: Text(
                                            "Press here for initial setup"),
                                      ),
                                    ]));
                    } else {
                      return loggingIn
                          ? const Center(
                              child: const CircularProgressIndicator())
                          : new Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                new RaisedButton(
                                  onPressed: initializePostLoginGlobals,
                                  child: new Text(
                                      'Login as ${snapshot.data.displayName}'),
                                ),
                                new Align(
                                  alignment: Alignment.bottomCenter,
                                  child: new FlatButton(
                                      onPressed: () {
                                        _email.clear();
                                        _pass.clear();
                                        _signOut();
                                      },
                                      child: const Text(
                                          'Not you? Log into a different account')),
                                )
                              ],
                            );
                    }
                }
              }),
        ));
  }

  @override
  void initState() {
    super.initState();
  }
}
