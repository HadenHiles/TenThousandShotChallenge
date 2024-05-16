class Preferences {
  bool? darkMode;
  int? puckCount;
  bool? friendNotifications;
  DateTime? targetDate;
  String? fcmToken;

  Preferences(this.darkMode, this.puckCount, this.friendNotifications, this.targetDate, this.fcmToken);
}
