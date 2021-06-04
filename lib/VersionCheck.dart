import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

const APP_URL = 'https://hyperurl.co/tenthousandshots';

versionCheck(context) async {
  //Get Current installed version of app
  final PackageInfo info = await PackageInfo.fromPlatform();
  double currentVersion = double.parse(info.version.trim().replaceAll(".", ""));

  //Get Latest version info from firebase config
  final RemoteConfig remoteConfig = RemoteConfig.instance;

  try {
    // Using default duration to force fetching from remote server.
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: Duration(seconds: 5),
      minimumFetchInterval: Duration(hours: 1),
    ));
    await remoteConfig.fetchAndActivate();
    double newVersion = double.parse(remoteConfig.getString('force_update_current_version').trim().replaceAll(".", ""));

    if (newVersion > currentVersion) {
      _showVersionDialog(context);
    }
  } catch (exception) {
    print('Unable to fetch remote config. Cached or default values will be used. Exception: \n $exception');
  }
}

_showVersionDialog(context) async {
  await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      String title = "Update Available";
      String message = "There is a newer version of the app available, please update it now.";
      String btnLabel = "Update Now";
      String btnLabelCancel = "Later";
      return Platform.isIOS
          ? CupertinoAlertDialog(
              title: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontFamily: 'NovecentoSans',
                  fontSize: 24,
                ),
              ),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    btnLabelCancel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text(
                    btnLabel,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  onPressed: () => _launchURL(APP_URL),
                ),
              ],
            )
          : new AlertDialog(
              title: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontFamily: 'NovecentoSans',
                  fontSize: 24,
                ),
              ),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    btnLabelCancel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text(
                    btnLabel,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  onPressed: () => _launchURL(APP_URL),
                ),
              ],
            );
    },
  );
}

_launchURL(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}
