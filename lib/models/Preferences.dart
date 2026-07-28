const int minimumPuckCount = 1;
const int maximumPuckCount = 500;
const int defaultPuckCount = 25;

int sanitizePuckCount(int? value) {
  return (value ?? defaultPuckCount).clamp(minimumPuckCount, maximumPuckCount);
}

String? validatePuckCount(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null) return 'Please enter how many pucks you have';
  if (parsed < minimumPuckCount) return 'Must have at least $minimumPuckCount puck';
  if (parsed > maximumPuckCount) return 'Maximum is $maximumPuckCount pucks';
  return null;
}

class Preferences {
  bool? darkMode;
  int? puckCount;
  bool? friendNotifications;
  DateTime? targetDate;
  String? fcmToken;

  Preferences(this.darkMode, this.puckCount, this.friendNotifications, this.targetDate, this.fcmToken);
}
