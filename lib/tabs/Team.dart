// ignore_for_file: constant_identifier_names

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';

const TEAM_HEADER_HEIGHT = 65.0;

class Team extends StatefulWidget {
  const Team({Key? key}) : super(key: key);

  @override
  State<Team> createState() => _TeamState();
}

class _TeamState extends State<Team> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [],
    );
  }
}
