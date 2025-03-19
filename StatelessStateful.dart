import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String valor = 'Hello';
  void _set() {
    setState(() {
      valor = 'World';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('My First App')),
        body: Column(children: [Text(valor), Child(clickf: _set)]),
      ),
    );
  }
}

class Child extends StatelessWidget {
  final Function() clickf;
  const Child({super.key, required this.clickf});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: clickf, child: Text('change'));
  }
}
