import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:web_browser/web_browser.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Shop extends StatefulWidget {
  Shop({Key key, this.sessionPanelController}) : super(key: key);

  final PanelController sessionPanelController;

  @override
  _ShopState createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;
  final Completer<WebViewController> _controller = Completer<WebViewController>();

  int _loadProgress = 0;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryVariant,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        bottom: AppBar().preferredSize.height,
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        children: [
          _loadProgress >= 100
              ? Container()
              : Center(
                  child: SizedBox(
                    height: 25,
                    width: 25,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
          WebBrowser(
            initialUrl: 'https://merch.howtohockey.com',
            javascriptEnabled: true,
            interactionSettings: WebBrowserInteractionSettings(
              topBar: null,
              gestureNavigationEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}
