import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
  
  static String getDaysLeftText(int daysLeft) {
    if (daysLeft < 0) {
      return 'Expired ${daysLeft.abs()} days ago';
    } else if (daysLeft == 0) {
      return 'Expires today';
    } else if (daysLeft == 1) {
      return 'Expires tomorrow';
    } else {
      return 'Expires in $daysLeft days';
    }
  }
}
