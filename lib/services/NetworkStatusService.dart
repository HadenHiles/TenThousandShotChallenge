// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:data_connection_checker_nulls/data_connection_checker_nulls.dart';

enum NetworkStatus { Online, Offline }

class NetworkStatusService {
  static bool? isTestingOverride;
  StreamController<NetworkStatus> networkStatusController = StreamController<NetworkStatus>();
  final bool isTesting;

  NetworkStatusService({bool isTesting = false}) : isTesting = isTestingOverride ?? isTesting {
    if (!this.isTesting) {
      // actively listen for status updates
      DataConnectionChecker().onStatusChange.listen((status) {
        switch (status) {
          case DataConnectionStatus.connected:
            networkStatusController.add(NetworkStatus.Online);
            break;
          case DataConnectionStatus.disconnected:
            networkStatusController.add(NetworkStatus.Offline);
            break;
        }
      });
    }
  }
}
