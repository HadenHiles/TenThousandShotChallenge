import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Shots extends StatefulWidget {
  Shots({Key key}) : super(key: key);

  @override
  _ShotsState createState() => _ShotsState();
}

class _ShotsState extends State<Shots> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
