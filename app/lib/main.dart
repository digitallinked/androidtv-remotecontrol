import 'package:flutter/material.dart';

void main() => runApp(const TvRemoteApp());

/// Root widget of the app. Placeholder until the real UI lands.
class TvRemoteApp extends StatelessWidget {
  /// Creates the root widget.
  const TvRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('TV Remote'))),
    );
  }
}
