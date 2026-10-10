import 'package:flutter/foundation.dart';
class ModeManager extends ChangeNotifier {
  static final ModeManager I = ModeManager._();
  ModeManager._();
  bool get isLite => true;
  int get port => 3000;
  String get backendUrl => 'http://127.0.0.1:3000';
  Future<void> init() async {}
  Future<void> switchMode(bool _) async {}
}
