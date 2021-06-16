import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:tenthousandshotchallenge/models/firestore/Merch.dart';
import 'package:tenthousandshotchallenge/models/YouTubeVideo.dart';
import 'package:tenthousandshotchallenge/services/YouTubeChannelService.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class More extends StatefulWidget {
  More({Key key}) : super(key: key);

  @override
  _MoreState createState() => _MoreState();
}

class _MoreState extends State<More> {
  final user = FirebaseAuth.instance.currentUser;

  String _connectionStatus = 'Unknown';
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult> _connectivitySubscription;

  String _coachJeremyPhoto = "";
  bool _loadingCoachJeremyVideos = true;
  List<YouTubeVideo> _coachJeremyVideos = [];
  String _hthPhoto = "";
  bool _loadingHthVideos = true;
  List<YouTubeVideo> _hthVideos = [];

  final PageController _learnPageController = PageController(initialPage: 0);
  bool _loadingLearnVideos = true;
  List<YouTubeVideo> _learnVideos = [];

  bool _loadingMerch = true;
  List<Merch> _merch = [];

  WebViewController _webviewController;
  bool _loadingHockeyshotProducts = true;
  List<Merch> _hockeyshotProducts = [];
  dom.Document _hsPageBody;
  String _hsBaseUrl = "https://www.hockeyshot.com";
  String _hsShootingProductsLink = 'https://www.hockeyshot.com/collections/complete-shooting-lineup?blogResultsPerPage=12&resultsPerPage=12&page=1&filter.ss_price_ca.low=0&filter.ss_price_ca.high=1850&region=CAD&selected_sort_option=0&price_interval=50&max_price=1850&selectedTab=products&blog_selected_sort_option=0&blogPage=1&filter.ss_tags_use=office';

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initConnectivity() async {
    ConnectivityResult result = ConnectivityResult.none;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      print(e.toString());
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      return Future.value(null);
    }

    return _updateConnectionStatus(result);
  }

  @override
  void initState() {
    _loadYoutubeChannels();
    _loadLearningVideos();
    _loadMerch();

    initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    super.initState();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.none:
        setState(() => _connectionStatus = result.toString());
        break;
      default:
        setState(() => _connectionStatus = 'Failed to get connectivity.');
        break;
    }
  }

  Future<Null> _loadYoutubeChannels() async {
    // Coach Jeremy Channel
    await getChannelThumbnail(GlobalConfiguration().getValue("coach_jeremy_channel_id")).then((photo) {
      setState(() {
        _coachJeremyPhoto = photo;
      });
    });
    await getVideos(GlobalConfiguration().getValue("coach_jeremy_channel_id")).then((v) {
      setState(() {
        _coachJeremyVideos = v;
        _loadingCoachJeremyVideos = false;
      });
    });

    // HTH channel
    await getChannelThumbnail(GlobalConfiguration().getValue("hth_channel_id")).then((photo) {
      setState(() {
        _hthPhoto = photo;
      });
    });
    await getVideos(GlobalConfiguration().getValue("hth_channel_id")).then((v) {
      setState(() {
        _hthVideos = v;
        _loadingHthVideos = false;
      });
    });
  }

  Future<Null> _loadLearningVideos() async {
    await FirebaseFirestore.instance.collection('learn_videos').orderBy('order', descending: false).get().then((snapshot) {
      List<YouTubeVideo> videos = [];
      if (snapshot.docs.isNotEmpty) {
        snapshot.docs.forEach((vDoc) {
          YouTubeVideo vid = YouTubeVideo.fromSnapshot(vDoc);
          videos.add(vid);
        });

        setState(() {
          _learnVideos = videos;
          _loadingLearnVideos = false;
        });
      }
    });
  }

  Future<Null> _loadMerch() async {
    await FirebaseFirestore.instance.collection('merch').orderBy('order', descending: false).get().then((snapshot) {
      List<Merch> merch = [];
      snapshot.docs.forEach((mDoc) {
        Merch product = Merch.fromSnapshot(mDoc);
        merch.add(product);
      });

      setState(() {
        _merch = merch;
        _loadingMerch = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _connectionStatus != "ConnectivityResult.mobile" && _connectionStatus != "ConnectivityResult.wifi"
        ? Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              right: 0,
              bottom: 0,
              left: 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Where's the wifi bud?".toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontFamily: "NovecentoSans",
                    fontSize: 24,
                  ),
                ),
                SizedBox(
                  height: 25,
                ),
                CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          )
        : Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              right: 0,
              bottom: 0,
              left: 0,
            ),
            child: DefaultTabController(
              length: 3,
              initialIndex: 0,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: HomeTheme.darkTheme.colorScheme.primaryVariant,
                    ),
                    child: TabBar(
                      labelStyle: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                      ),
                      labelPadding: EdgeInsets.all(0),
                      tabs: [
                        Tab(
                          icon: Icon(
                            Icons.video_collection_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: EdgeInsets.all(0),
                          text: "Watch".toUpperCase(),
                        ),
                        Tab(
                          icon: Icon(
                            Icons.school_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: EdgeInsets.all(0),
                          text: "Learn".toUpperCase(),
                        ),
                        Tab(
                          icon: Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: EdgeInsets.all(0),
                          text: "Shop".toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Column(
                          children: [
                            Container(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        child: GestureDetector(
                                          onTap: () async {
                                            String channelLink = "https://www.youtube.com/CoachJeremy";
                                            await canLaunch(channelLink).then((can) {
                                              launch(channelLink).catchError((err) {
                                                print(err);
                                              });
                                            });
                                          },
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 50,
                                                height: 50,
                                                child: FittedBox(
                                                  fit: BoxFit.cover,
                                                  clipBehavior: Clip.antiAlias,
                                                  child: CircleAvatar(
                                                    radius: 50,
                                                    backgroundImage: _coachJeremyPhoto == null
                                                        ? AssetImage("assets/images/avatar.png")
                                                        : NetworkImage(
                                                            _coachJeremyPhoto,
                                                          ),
                                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 15,
                                              ),
                                              AutoSizeText(
                                                "Coach Jeremy".toUpperCase(),
                                                maxLines: 2,
                                                maxFontSize: 22,
                                                style: TextStyle(
                                                  fontFamily: "NovecentoSans",
                                                  fontSize: 22,
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () async {
                                                  String channelLink = "https://www.youtube.com/CoachJeremy";
                                                  await canLaunch(channelLink).then((can) {
                                                    launch(channelLink).catchError((err) {
                                                      print(err);
                                                    });
                                                  });
                                                },
                                                icon: Icon(
                                                  FontAwesomeIcons.youtube,
                                                  color: Colors.red.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _loadingCoachJeremyVideos || _coachJeremyVideos.length < 1
                                      ? Container(
                                          margin: EdgeInsets.symmetric(vertical: 25),
                                          child: Center(
                                            child: LinearProgressIndicator(
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          height: 185.0,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _coachJeremyVideos.length,
                                            itemBuilder: (BuildContext context, int i) {
                                              return GestureDetector(
                                                onTap: () async {
                                                  String videoLink = "https://www.youtube.com/watch?v=${_coachJeremyVideos[i].id}";
                                                  await canLaunch(videoLink).then((can) {
                                                    launch(videoLink).catchError((err) {
                                                      print(err);
                                                    });
                                                  });
                                                },
                                                child: Card(
                                                  color: Theme.of(context).cardTheme.color,
                                                  elevation: 4,
                                                  child: Container(
                                                    width: 200.0,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                      children: [
                                                        Image(
                                                          image: NetworkImage(_coachJeremyVideos[i].thumbnail),
                                                          width: 200,
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets.all(5),
                                                          child: AutoSizeText(
                                                            _coachJeremyVideos[i].title,
                                                            maxLines: 2,
                                                            maxFontSize: 22,
                                                            style: TextStyle(
                                                              fontFamily: "NovecentoSans",
                                                              fontSize: 22,
                                                              color: Theme.of(context).colorScheme.onPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            Container(
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    child: GestureDetector(
                                      onTap: () async {
                                        String channelLink = "https://www.youtube.com/howtohockeydotcom";
                                        await canLaunch(channelLink).then((can) {
                                          launch(channelLink).catchError((err) {
                                            print(err);
                                          });
                                        });
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: FittedBox(
                                              fit: BoxFit.cover,
                                              clipBehavior: Clip.antiAlias,
                                              child: CircleAvatar(
                                                radius: 50,
                                                backgroundImage: _hthPhoto == null
                                                    ? AssetImage("assets/images/avatar.png")
                                                    : NetworkImage(
                                                        _hthPhoto,
                                                      ),
                                                backgroundColor: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 15,
                                          ),
                                          AutoSizeText(
                                            "How To Hockey".toUpperCase(),
                                            maxLines: 2,
                                            maxFontSize: 22,
                                            style: TextStyle(
                                              fontFamily: "NovecentoSans",
                                              fontSize: 22,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              String channelLink = "https://www.youtube.com/howtohockeydotcom";
                                              await canLaunch(channelLink).then((can) {
                                                launch(channelLink).catchError((err) {
                                                  print(err);
                                                });
                                              });
                                            },
                                            icon: Icon(
                                              FontAwesomeIcons.youtube,
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _loadingHthVideos || _hthVideos.length < 1
                                      ? Container(
                                          margin: EdgeInsets.symmetric(vertical: 25),
                                          child: Center(
                                            child: LinearProgressIndicator(
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          height: 185.0,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _hthVideos.length,
                                            itemBuilder: (BuildContext context, int i) {
                                              return GestureDetector(
                                                onTap: () async {
                                                  String videoLink = "https://www.youtube.com/watch?v=${_hthVideos[i].id}";
                                                  await canLaunch(videoLink).then((can) {
                                                    launch(videoLink).catchError((err) {
                                                      print(err);
                                                    });
                                                  });
                                                },
                                                child: Card(
                                                  color: Theme.of(context).cardTheme.color,
                                                  elevation: 4,
                                                  child: Container(
                                                    width: 200.0,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                      children: [
                                                        Image(
                                                          image: NetworkImage(_hthVideos[i].thumbnail),
                                                          width: 200,
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets.all(5),
                                                          child: AutoSizeText(
                                                            _hthVideos[i].title,
                                                            maxLines: 2,
                                                            maxFontSize: 22,
                                                            style: TextStyle(
                                                              fontFamily: "NovecentoSans",
                                                              fontSize: 22,
                                                              color: Theme.of(context).colorScheme.onPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Container(
                              child: Column(
                                children: [
                                  _loadingLearnVideos || _learnVideos.length < 1
                                      ? Container(
                                          margin: EdgeInsets.symmetric(vertical: 25),
                                          child: Column(
                                            children: [
                                              Center(
                                                child: LinearProgressIndicator(
                                                  color: Theme.of(context).primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Container(
                                          height: MediaQuery.of(context).size.height - (MediaQuery.of(context).padding.top + AppBar().preferredSize.height + 60),
                                          child: PageView.builder(
                                            controller: _learnPageController,
                                            scrollDirection: Axis.vertical,
                                            itemCount: _learnVideos.length,
                                            itemBuilder: (BuildContext context, int i) {
                                              YoutubePlayerController _ytController = YoutubePlayerController(
                                                initialVideoId: _learnVideos[i].id,
                                                flags: YoutubePlayerFlags(
                                                  autoPlay: false,
                                                  mute: false,
                                                ),
                                              );

                                              return Flex(
                                                direction: Axis.vertical,
                                                children: [
                                                  YoutubePlayerBuilder(
                                                    player: YoutubePlayer(
                                                      controller: _ytController,
                                                      aspectRatio: 16 / 9,
                                                      showVideoProgressIndicator: true,
                                                      progressIndicatorColor: Theme.of(context).primaryColor,
                                                      progressColors: ProgressBarColors(
                                                        playedColor: Theme.of(context).primaryColor,
                                                        handleColor: Theme.of(context).accentColor,
                                                      ),
                                                      actionsPadding: EdgeInsets.all(2),
                                                      liveUIColor: Theme.of(context).primaryColor,
                                                      onReady: () {
                                                        // _ytController.addListener(listener);
                                                      },
                                                    ),
                                                    builder: (context, player) {
                                                      return Column(
                                                        children: [
                                                          player,
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Container(
                              child: Column(
                                children: [
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            child: GestureDetector(
                                              onTap: () async {
                                                String merchLink = "https://merch.howtohockey.com";
                                                await canLaunch(merchLink).then((can) {
                                                  launch(merchLink).catchError((err) {
                                                    print(err);
                                                  });
                                                });
                                              },
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 50,
                                                    height: 50,
                                                    child: FittedBox(
                                                      fit: BoxFit.cover,
                                                      clipBehavior: Clip.antiAlias,
                                                      child: CircleAvatar(
                                                        radius: 50,
                                                        backgroundImage: AssetImage("assets/images/avatar.png"),
                                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 15,
                                                  ),
                                                  AutoSizeText(
                                                    "How To Hockey Merch".toUpperCase(),
                                                    maxLines: 2,
                                                    maxFontSize: 22,
                                                    style: TextStyle(
                                                      fontFamily: "NovecentoSans",
                                                      fontSize: 22,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () async {
                                                      String merchLink = "https://merch.howtohockey.com";
                                                      await canLaunch(merchLink).then((can) {
                                                        launch(merchLink).catchError((err) {
                                                          print(err);
                                                        });
                                                      });
                                                    },
                                                    icon: Icon(
                                                      FontAwesomeIcons.shoppingBag,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      _loadingMerch || _merch.length < 1
                                          ? Container(
                                              margin: EdgeInsets.symmetric(vertical: 25),
                                              child: Column(
                                                children: [
                                                  Center(
                                                    child: LinearProgressIndicator(
                                                      color: Theme.of(context).primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Container(
                                              height: 200.0,
                                              child: ListView.builder(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: _merch.length,
                                                itemBuilder: (BuildContext context, int i) {
                                                  return GestureDetector(
                                                    onTap: () async {
                                                      String link = _merch[i].url;
                                                      await canLaunch(link).then((can) {
                                                        launch(link).catchError((err) {
                                                          print(err);
                                                        });
                                                      });
                                                    },
                                                    child: Card(
                                                      color: Theme.of(context).cardTheme.color,
                                                      elevation: 4,
                                                      child: Container(
                                                        width: 150.0,
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.start,
                                                          children: [
                                                            Image(
                                                              image: _merch[i].image == null
                                                                  ? AssetImage("assets/images/avatar.png")
                                                                  : NetworkImage(
                                                                      _merch[i].image,
                                                                    ),
                                                              width: 150,
                                                            ),
                                                            Container(
                                                              padding: EdgeInsets.all(5),
                                                              child: AutoSizeText(
                                                                _merch[i].title,
                                                                maxLines: 2,
                                                                maxFontSize: 22,
                                                                style: TextStyle(
                                                                  fontFamily: "NovecentoSans",
                                                                  fontSize: 20,
                                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 25,
                                  ),
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Opacity(
                                            opacity: 0,
                                            child: Container(
                                              height: 1,
                                              width: 1,
                                              child: WebView(
                                                initialUrl: _hsShootingProductsLink,
                                                javascriptMode: JavascriptMode.unrestricted,
                                                javascriptChannels: <JavascriptChannel>[
                                                  _extractDataJSChannel(context),
                                                ].toSet(),
                                                onWebViewCreated: (WebViewController cont) {
                                                  print('webview was created.');
                                                  _webviewController = cont;
                                                },
                                                onPageFinished: (String url) {
                                                  _webviewController.evaluateJavascript("(function(){Flutter.postMessage(window.document.body.outerHTML)})();");
                                                },
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            child: GestureDetector(
                                              onTap: () async {
                                                String hockeyshotLink = "https://www.hockeyshot.com";
                                                await canLaunch(hockeyshotLink).then((can) {
                                                  launch(hockeyshotLink).catchError((err) {
                                                    print(err);
                                                  });
                                                });
                                              },
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 150,
                                                    height: 32.25,
                                                    child: FittedBox(
                                                      fit: BoxFit.cover,
                                                      clipBehavior: Clip.antiAlias,
                                                      child: Image(
                                                        image: AssetImage("assets/images/shop/logo-hockeyshot.png"),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 15,
                                                  ),
                                                  AutoSizeText(
                                                    "Shooting Products".toUpperCase(),
                                                    maxLines: 2,
                                                    maxFontSize: 22,
                                                    style: TextStyle(
                                                      fontFamily: "NovecentoSans",
                                                      fontSize: 22,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () async {
                                                      String hockeyshotLink = "https://www.hockeyshot.com";
                                                      await canLaunch(hockeyshotLink).then((can) {
                                                        launch(hockeyshotLink).catchError((err) {
                                                          print(err);
                                                        });
                                                      });
                                                    },
                                                    icon: Icon(
                                                      Icons.link_rounded,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      _loadingHockeyshotProducts || _hockeyshotProducts.length < 1
                                          ? Container(
                                              margin: EdgeInsets.symmetric(vertical: 25),
                                              child: Column(
                                                children: [
                                                  Center(
                                                    child: LinearProgressIndicator(
                                                      color: Theme.of(context).primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Container(
                                              height: 205.0,
                                              child: ListView.builder(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: _hockeyshotProducts.length,
                                                itemBuilder: (BuildContext context, int i) {
                                                  return GestureDetector(
                                                    onTap: () async {
                                                      String link = _hsBaseUrl + _hockeyshotProducts[i].url;
                                                      await canLaunch(link).then((can) {
                                                        launch(link).catchError((err) {
                                                          print(err);
                                                        });
                                                      });
                                                    },
                                                    child: Card(
                                                      color: Theme.of(context).cardTheme.color,
                                                      elevation: 4,
                                                      child: Container(
                                                        width: 140.0,
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.start,
                                                          children: [
                                                            Image(
                                                              image: _hockeyshotProducts[i].image == null
                                                                  ? AssetImage("assets/images/avatar.png")
                                                                  : NetworkImage(
                                                                      _hockeyshotProducts[i].image,
                                                                    ),
                                                              width: 140,
                                                            ),
                                                            Container(
                                                              padding: EdgeInsets.all(5),
                                                              child: AutoSizeText(
                                                                _hockeyshotProducts[i].title,
                                                                maxLines: 2,
                                                                maxFontSize: 18,
                                                                style: TextStyle(
                                                                  fontFamily: "NovecentoSans",
                                                                  fontSize: 18,
                                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  JavascriptChannel _extractDataJSChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'Flutter',
      onMessageReceived: (JavascriptMessage message) {
        _hsPageBody = parse(message.message);
        List<dom.Element> prods = _hsPageBody.getElementsByClassName('product-card__link');
        List<Merch> products = [];
        prods.forEach((el) {
          String url = el.attributes['href'];
          String title = el.getElementsByClassName('product-card__title')[0].innerHtml;
          dom.Element img = el.getElementsByClassName('product-card__img')[0];
          String image = img.attributes['data-src'];

          if (title != null && url != null && image != null) {
            products.add(Merch(title, url, image));
          }
        });

        setState(() {
          _hockeyshotProducts = products;
          _loadingHockeyshotProducts = false;
        });
      },
    );
  }
}
