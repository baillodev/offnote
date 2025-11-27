import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _controller.stream;

  late final StreamSubscription _subscription;

  ConnectivityService() {
    _subscription = Connectivity().onConnectivityChanged.listen((status) {
      final isOnline = status != ConnectivityResult.none;
      _controller.add(isOnline);
    });
  }

  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
