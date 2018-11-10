import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:smart_charging_app/authenticate.dart';
import 'package:smart_charging_app/connect_bluetooth.dart';

class InitialSetup extends StatefulWidget {
  @override
  State createState() => new _InitialSetup();
}

class _InitialSetup extends State<InitialSetup> {
  final _headingFont = const TextStyle(fontSize: 20.0);

  bool registering = false;

  UserData user = new UserData();
  UserAuth userAuth = new UserAuth();

  final TextEditingController _email = new TextEditingController();
  final TextEditingController _password = new TextEditingController();
  final TextEditingController _ssid = new TextEditingController();
  final TextEditingController _wifipw = new TextEditingController();
  final TextEditingController _chargerID = new TextEditingController();

  final FocusNode _passwordFocus = new FocusNode();
  final FocusNode _ssidFocus = new FocusNode();
  final FocusNode _wifipwFocus = new FocusNode();
  final FocusNode _chargerIDFocus = new FocusNode();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: Text("Delta Smart Charging Initial Setup"),
        ),
        body: new Center(
            child: registering
                ? const Center(child: const CircularProgressIndicator())
                : ListView(
                    children: <Widget>[
                      new Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              "Please create a Delta Solar Charger account",
                              style: _headingFont,
                              textAlign: TextAlign.center,
                            ),
                            new Padding(
                                padding: const EdgeInsets.only(top: 30.0)),
                            new ListTile(
                                leading: const Icon(Icons.email),
                                title: new TextField(
                                  controller: _email,
                                  decoration:
                                      new InputDecoration(hintText: "Email"),
                                  onSubmitted: (String value) {
                                    FocusScope
                                        .of(context)
                                        .requestFocus(_passwordFocus);
                                  },
                                )),
                            new ListTile(
                                leading: const Icon(Icons.lock),
                                title: new TextField(
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  decoration:
                                      new InputDecoration(hintText: "Password"),
                                  onSubmitted: (String value) {
                                    FocusScope
                                        .of(context)
                                        .requestFocus(_ssidFocus);
                                  },
                                  obscureText: false,
                                )),
                            new Padding(padding: const EdgeInsets.all(15.0)),
                            new Text(
                              "Enter Wi-Fi Details",
                              style: _headingFont,
                              textAlign: TextAlign.center,
                            ),
                            new ListTile(
                                title: TextField(
                              controller: _ssid,
                              focusNode: _ssidFocus,
                              decoration:
                                  InputDecoration(hintText: "Wifi SSID"),
                              onSubmitted: (String value) {
                                FocusScope
                                    .of(context)
                                    .requestFocus(_wifipwFocus);
                              },
                            )),
                            new ListTile(
                                title: TextField(
                              controller: _wifipw,
                              focusNode: _wifipwFocus,
                              decoration: new InputDecoration(
                                  hintText: "Wi-Fi Password"),
                              onSubmitted: (String value) {
                                FocusScope
                                    .of(context)
                                    .requestFocus(_chargerIDFocus);
                              },
                            )),
                            new Padding(padding: const EdgeInsets.all(15.0)),
                            new ListTile(
                                title: TextField(
                              controller: _chargerID,
                              decoration:
                                  InputDecoration(hintText: "Charger ID"),
                            )),
                            new RaisedButton(
                                child: Text('Register'),
                                onPressed: _handleRegister,
                                padding: const EdgeInsets.only(top: 1.0)),
                            new Padding(
                              padding: const EdgeInsets.all(15.0),
                            ),
                            new RaisedButton(
                              child: Text('Bypass'),
                              onPressed: () {
                                var route = new MaterialPageRoute(
                                    builder: (BuildContext context) =>
                                        new ConnectBluetooth(
                                          email: 'test123@gmail.com',
                                          password: 'test123',
                                          ssid: "Delta-Guest",
                                          wifipw: "1234567890",
                                        ));
                                Navigator.of(context).push(route);
                              },
                            ),
                          ])
                    ],
                    padding: const EdgeInsets.only(
                        top: 15.0, left: 10.0, right: 10.0),
                  )));
  }

  void _handleRegister() {
    setState(() {
      registering = true;
    });
    // This function handles the registration.
    user.email = _email.text;
    user.password = _password.text;
    userAuth.createUser(user).then((returnValue) {
      if (returnValue == "Account Created Successfully!") {
        // Now let's send the charger ID and the user/pass to OCPP backend
        var route = new MaterialPageRoute(
          builder: (BuildContext context) => new ConnectBluetooth(
                email: user.email,
                password: user.password,
                ssid: _ssid.text,
                wifipw: _wifipw.text,
              ),
        );
        Navigator.of(context).push(route);
      } else {
        // If there is an error, we show a dialog with the error
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return new AlertDialog(
                title: new Text("Registration Error"),
                content: new Text(returnValue),
                actions: <Widget>[
                  new FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          registering = false;
                        });
                      },
                      child: new Text('Try Again'))
                ],
              );
            });
      }
    });
  }
}
