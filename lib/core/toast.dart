import 'package:flutter/material.dart';

/// Gắn vào MaterialApp.scaffoldMessengerKey để hiện thông báo từ bất kỳ đâu (store, auth...).
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String msg) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
