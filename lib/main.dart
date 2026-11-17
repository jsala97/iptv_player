import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'accounts_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const IptvApp());
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const AccountsPage(),
    );
  }
}