import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(home: Scaffold(body: Testwidget())));
}

class Testwidget extends StatelessWidget {
  const Testwidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          "Hello Flutter",
          style: TextStyle(fontSize: 60, color: Colors.black),
        ),
      ),
    );
  }
}
