import 'package:tenthousandshotchallenge/models/Settings.dart';
import 'package:flutter/material.dart';

class SettingsStateNotifier extends ChangeNotifier {
  Settings settings = Settings(
    (ThemeMode.system == ThemeMode.dark),
  );

  void updateSettings(Settings settings) {
    this.settings = settings;
    notifyListeners();
  }
}
