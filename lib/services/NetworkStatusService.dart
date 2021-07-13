import 'dart:async';
import 'package:data_connection_checker/data_connection_checker.dart';

enum NetworkStatus { Online, Offline }

class NetworkStatusService {
  StreamController<NetworkStatus> networkStatusController = StreamController<NetworkStatus>();

  NetworkStatusService() {
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
