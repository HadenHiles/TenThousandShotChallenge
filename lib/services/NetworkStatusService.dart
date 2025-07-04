// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:data_connection_checker_nulls/data_connection_checker_nulls.dart';

enum NetworkStatus { Online, Offline }

class NetworkStatusService {
  static bool? isTestingOverride;
  late final StreamController<NetworkStatus> _networkStatusController;
  final bool isTesting;

  NetworkStatusService({bool isTesting = false}) : isTesting = isTestingOverride ?? isTesting {
    _networkStatusController = StreamController<NetworkStatus>.broadcast();
    if (!this.isTesting) {
      // actively listen for status updates
      DataConnectionChecker().onStatusChange.listen((status) {
        switch (status) {
          case DataConnectionStatus.connected:
            _networkStatusController.add(NetworkStatus.Online);
            break;
          case DataConnectionStatus.disconnected:
            _networkStatusController.add(NetworkStatus.Offline);
            break;
        }
      });
    }
  }

  StreamController<NetworkStatus> get networkStatusController => _networkStatusController;
}
