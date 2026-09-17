import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true
      ..connectionTimeout = const Duration(seconds: 30);
  }
}

void setupHttpOverrides() {
  HttpOverrides.global = MyHttpOverrides();
}
