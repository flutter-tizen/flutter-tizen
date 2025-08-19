import 'package:flutter/material.dart';
import 'package:flutter_tizen/flutter_tizen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _tizenProfile = 'Unknown';
  String _isTizen = 'Unknown';
  String _apiVersion = 'Unknown';

  @override
  initState() {
    super.initState();
    setState(() {
      _tizenProfile = isTvProfile ? 'TV' : (isTizenProfile ? 'Tizen' : 'Unknown');
      _isTizen = isTizen.toString();
      _apiVersion = apiVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter-Tizen Plugin example app'),
        ),
        body: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('isTizen : $_isTizen\n'),
              Text('apiVersion : $_apiVersion\n'),
              Text('Profile : $_tizenProfile\n'),
            ],
          ),
        ),
      ),
    );
  }
}
