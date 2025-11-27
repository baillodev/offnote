import 'dart:async';
import 'package:flutter/material.dart';
import 'package:offnote/services/connectivity_service.dart';

class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService connectivityService;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  late final StreamSubscription _subscription;

  ConnectivityProvider({required this.connectivityService}) {
    _subscription = connectivityService.connectionStream.listen((status) {
      _isOnline = status;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
