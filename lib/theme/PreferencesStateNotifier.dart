import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:flutter/material.dart';

class PreferencesStateNotifier extends ChangeNotifier {
  Preferences preferences = Preferences((ThemeMode.system == ThemeMode.dark), 25, null);

  void updateSettings(Preferences preferences) {
    this.preferences = preferences;
    notifyListeners();
  }
}
