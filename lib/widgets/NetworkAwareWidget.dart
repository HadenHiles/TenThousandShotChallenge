import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:provider/provider.dart';

class NetworkAwareWidget extends StatelessWidget {
  const NetworkAwareWidget({super.key, required this.onlineChild, required this.offlineChild});

  final Widget onlineChild;
  final Widget offlineChild;

  @override
  Widget build(BuildContext context) {
    NetworkStatus networkStatus = Provider.of<NetworkStatus>(context);
    if (networkStatus == NetworkStatus.Online) {
      return onlineChild;
    } else {
      return offlineChild;
    }
  }
}
