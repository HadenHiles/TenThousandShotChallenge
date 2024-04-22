import 'package:intl/intl.dart';

var numberFormat = NumberFormat('#,##,000');

String printDuration(Duration duration, bool showSeconds) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  String durationString = "";
  if (duration.inHours != 0) {
    durationString += "${twoDigits(duration.inHours)}h ";
  }

  if (duration.inMinutes != 0) {
    durationString += "${twoDigitMinutes}m ";
  }

  if (showSeconds == true) {
    if (duration.inSeconds != 0) {
      durationString += "${twoDigitSeconds}s";
    }
  }

  return durationString;
}

String printDate(DateTime date) {
  return DateFormat("EEEE MMMM d hh:mm a").format(date);
}

String printTime(DateTime date) {
  return DateFormat("hh:mm a").format(date);
}

String printWeekday(DateTime date) {
  switch (date.weekday) {
    case DateTime.sunday:
      return "Sunday";
    case DateTime.monday:
      return "Monday";
    case DateTime.tuesday:
      return "Tuesday";
    case DateTime.wednesday:
      return "Wednesday";
    case DateTime.thursday:
      return "Thursday";
    case DateTime.friday:
      return "Friday";
    case DateTime.saturday:
      return "Saturday";
    default:
      return "";
  }
}
