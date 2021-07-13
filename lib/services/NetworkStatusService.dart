import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { Online, Offline }

class NetworkStatusService {
  StreamController<NetworkStatus> networkStatusController = StreamController<NetworkStatus>();

  NetworkStatusService() {
    Connectivity().onConnectivityChanged.listen((status) async {
      // Delay so that the connection status doesn't get overriden
      Future.delayed(Duration(milliseconds: 500)).then((value) async {
        try {
          final result = await InternetAddress.lookup('google.com'); // check if they have internet access
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            networkStatusController.add(_getNetworkStatus(status));
          } else {
            networkStatusController.add(_getNetworkStatus(ConnectivityResult.none));
          }
        } on SocketException catch (_) {
          networkStatusController.add(_getNetworkStatus(ConnectivityResult.none));
        }
      });
    });
  }

  NetworkStatus _getNetworkStatus(ConnectivityResult status) {
    return status == ConnectivityResult.mobile || status == ConnectivityResult.wifi ? NetworkStatus.Online : NetworkStatus.Offline;
  }
}
