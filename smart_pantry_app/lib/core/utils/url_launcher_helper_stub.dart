import 'package:url_launcher/url_launcher.dart';

Future<bool> openWebOrNativeUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    return true;
  } catch (_) {
    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}
