import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:web_browser/web_browser.dart';

class Shop extends StatefulWidget {
  Shop({Key key, this.sessionPanelController}) : super(key: key);

  final PanelController sessionPanelController;

  @override
  _ShopState createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  // Static variables
  final user = FirebaseAuth.instance.currentUser;

  bool _show = false;

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
          Center(
            child: SizedBox(
              height: 25,
              width: 25,
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Opacity(
            opacity: _show ? 1 : 0,
            child: WebBrowser(
              initialUrl: 'https://merch.howtohockey.com',
              javascriptEnabled: true,
              interactionSettings: WebBrowserInteractionSettings(
                topBar: null,
                gestureNavigationEnabled: true,
              ),
              onCreated: (_) {
                Future.delayed(Duration(milliseconds: 1200)).then(
                  (_) => setState(() {
                    _show = true;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
