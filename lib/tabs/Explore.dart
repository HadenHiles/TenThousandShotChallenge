import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/YouTubeVideo.dart';
import 'package:tenthousandshotchallenge/models/firestore/Merch.dart';
import 'package:tenthousandshotchallenge/services/YouTubeChannelService.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:tenthousandshotchallenge/widgets/VideoStream.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class Explore extends StatefulWidget {
  Explore({Key key}) : super(key: key);

  @override
  _ExploreState createState() => _ExploreState();
}

class _ExploreState extends State<Explore> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  final PageController _explorePageController = PageController(initialPage: 0);
  bool _loadingExploreVideos = true;
  List<YouTubeVideo> _exploreVideos = [];
  ScrollController _exploreScrollController;

  String _coachJeremyPhoto = "";
  bool _loadingCoachJeremyVideos = true;
  List<YouTubeVideo> _coachJeremyVideos = [];
  String _hthPhoto = "";
  bool _loadingHthVideos = true;
  List<YouTubeVideo> _hthVideos = [];

  bool _loadingMerch = true;
  List<Merch> _merch = [];

  TabController _tabController;

  @override
  void initState() {
    _loadExploreingVideos();
    _loadYoutubeChannels();
    _loadMerch();

    _exploreScrollController = ScrollController();
    _exploreScrollController.addListener(this.swapPageListener);

    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(this.changeTabListener);

    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  void changeTabListener() {
    if (_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          break;
        case 1:
          break;
        case 2:
          break;
      }
    }
  }

  Future<Null> _loadExploreingVideos() async {
    await FirebaseFirestore.instance.collection('learn_videos').orderBy('order', descending: false).get().then((snapshot) {
      List<YouTubeVideo> videos = [];
      if (snapshot.docs.isNotEmpty) {
        snapshot.docs.forEach((vDoc) {
          YouTubeVideo vid = YouTubeVideo.fromSnapshot(vDoc);
          videos.add(vid);
        });

        setState(() {
          _exploreVideos = videos;
          _loadingExploreVideos = false;
        });
      }
    });
  }

  Future<Null> _loadYoutubeChannels() async {
    // Coach Jeremy Channel
    await getChannelThumbnail(GlobalConfiguration().getValue("coach_jeremy_channel_id")).then((photo) {
      setState(() {
        _coachJeremyPhoto = photo;
      });
    });

    // HTH channel
    await getChannelThumbnail(GlobalConfiguration().getValue("hth_channel_id")).then((photo) {
      setState(() {
        _hthPhoto = photo;
      });
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

  void swapPageListener() {
    if (_exploreScrollController.offset > _exploreScrollController.position.maxScrollExtent + 50) {
      _explorePageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );
    }

    if (_exploreScrollController.offset < _exploreScrollController.position.minScrollExtent - 50) {
      _explorePageController.previousPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
          margin: EdgeInsets.only(
            top: 0,
            right: 0,
            bottom: 0,
            left: 0,
          ),
          child: NestedScrollView(
            clipBehavior: Clip.antiAlias,
            scrollDirection: Axis.vertical,
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              // These are the slivers that show up in the "outer" scroll view.
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    floating: false,
                    primary: true,
                    toolbarHeight: 0,
                    collapsedHeight: 0,
                    expandedHeight: 0,
                    forceElevated: false,
                    titleSpacing: 0,
                    title: null,
                    backgroundColor: HomeTheme.darkTheme.colorScheme.primaryContainer,
                    bottom: TabBar(
                      controller: _tabController,
                      labelStyle: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                      ),
                      labelPadding: EdgeInsets.all(0),
                      indicatorColor: Theme.of(context).primaryColor,
                      tabs: [
                        Tab(
                          icon: Icon(
                            Icons.video_collection_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: EdgeInsets.all(0),
                          text: "Tips".toUpperCase(),
                        ),
                        Tab(
                          icon: Icon(
                            Icons.sports_hockey_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: EdgeInsets.all(0),
                          text: "Train".toUpperCase(),
                        ),
                        Tab(
                          icon: Icon(
                            Icons.add_box_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: EdgeInsets.all(0),
                          text: "More".toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _loadingExploreVideos || _exploreVideos.length < 1
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
                            height: MediaQuery.of(context).size.height - (MediaQuery.of(context).padding.top + 125 + (sessionService.isRunning ? 60 : 0)),
                            child: PageView.builder(
                              controller: _explorePageController,
                              scrollDirection: Axis.vertical,
                              itemCount: _exploreVideos.length,
                              itemBuilder: (BuildContext context, int i) {
                                YoutubePlayerController _ytController = YoutubePlayerController(
                                  initialVideoId: _exploreVideos[i].id,
                                  flags: YoutubePlayerFlags(
                                    autoPlay: false,
                                    mute: false,
                                  ),
                                );

                                return Flex(
                                  direction: Axis.vertical,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    YoutubePlayerBuilder(
                                      player: YoutubePlayer(
                                        controller: _ytController,
                                        aspectRatio: 16 / 9,
                                        showVideoProgressIndicator: true,
                                        progressIndicatorColor: Theme.of(context).primaryColor,
                                        progressColors: ProgressBarColors(
                                          playedColor: Theme.of(context).primaryColor,
                                          handleColor: Theme.of(context).primaryColor,
                                        ),
                                        bottomActions: [
                                          const SizedBox(width: 14.0),
                                          CurrentPosition(),
                                          const SizedBox(width: 8.0),
                                          ProgressBar(
                                            isExpanded: true,
                                          ),
                                          RemainingDuration(),
                                          const PlaybackSpeedButton(),
                                        ],
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
                                    Flexible(
                                      flex: 2,
                                      child: Container(
                                        margin: EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: MediaQuery.of(context).size.width * .1,
                                        ),
                                        child: SingleChildScrollView(
                                          physics: BouncingScrollPhysics(),
                                          controller: _exploreScrollController,
                                          child: Column(
                                            children: [
                                              Container(
                                                margin: EdgeInsets.only(top: 25),
                                                child: Text(
                                                  _exploreVideos[i].title.toUpperCase(),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: 42,
                                                  ),
                                                ),
                                              ),
                                              Html(
                                                data: _exploreVideos[i].content,
                                                style: {
                                                  "h1": Style(
                                                    textAlign: TextAlign.center,
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: FontSize(36),
                                                  ),
                                                  "h2": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: FontSize(30),
                                                  ),
                                                  "h3": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: FontSize(24),
                                                  ),
                                                  "ul": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: FontSize(24),
                                                    listStyleType: ListStyleType.DISC,
                                                  ),
                                                  "ol": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: FontSize(24),
                                                    listStyleType: ListStyleType.DECIMAL,
                                                  ),
                                                  "ul li, ol li": Style(
                                                    padding: EdgeInsets.symmetric(vertical: 5),
                                                    margin: EdgeInsets.only(bottom: 2),
                                                  ),
                                                  "p": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontSize: FontSize(16),
                                                  ),
                                                },
                                              ),
                                              _exploreVideos[i].buttonUrl.isNotEmpty
                                                  ? Container(
                                                      margin: EdgeInsets.only(bottom: 50),
                                                      child: TextButton(
                                                        onPressed: () async {
                                                          await canLaunchUrlString(_exploreVideos[i].buttonUrl).then((can) {
                                                            launchUrlString(_exploreVideos[i].buttonUrl).catchError((err) {
                                                              print(err);
                                                            });
                                                          });
                                                        },
                                                        child: Text(
                                                          _exploreVideos[i].buttonText.toUpperCase() ?? "See more".toUpperCase(),
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontFamily: "NovecentoSans",
                                                            fontSize: 24,
                                                          ),
                                                        ),
                                                        style: ButtonStyle(
                                                          padding: MaterialStateProperty.all(
                                                            EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                                          ),
                                                          backgroundColor: MaterialStateProperty.all(
                                                            Theme.of(context).primaryColor,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : Container(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      child: Text(
                        "Coming Soon!".toUpperCase(),
                        style: Theme.of(context).textTheme.headline5,
                      ),
                    ),
                    /*
                    Container(
                      child: VideoStream(url: "https://player.vimeo.com/progressive_redirect/playback/685958839/rendition/1080p?loc=external&signature=f7542ffea715bb844a2acdadcc34870f7955d7595ee274893e2293a640b4fd11"),
                    )
                    */
                  ],
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: GestureDetector(
                            onTap: () async {
                              Uri merchLink = Uri(scheme: "https", host: "merch.howtohockey.com");
                              await canLaunchUrl(merchLink).then((can) {
                                launchUrl(merchLink).catchError((err) {
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
                                    Uri merchLink = Uri(scheme: "https", host: "merch.howtohockey.com");
                                    await canLaunchUrl(merchLink).then((can) {
                                      launchUrl(merchLink).catchError((err) {
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
                            height: 50,
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
                            height: 220.0,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: AlwaysScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _merch.length,
                              itemBuilder: (BuildContext context, int i) {
                                return GestureDetector(
                                  onTap: () async {
                                    String link = _merch[i].url;
                                    await canLaunchUrlString(link).then((can) {
                                      launchUrlString(link).catchError((err) {
                                        print(err);
                                      });
                                    });
                                  },
                                  child: Card(
                                    color: Theme.of(context).cardTheme.color,
                                    elevation: 4,
                                    child: Container(
                                      width: 150.0,
                                      height: 32.25,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image(
                                            image: _merch[i].image == null
                                                ? AssetImage("assets/images/avatar.png")
                                                : NetworkImage(
                                                    _merch[i].image,
                                                  ),
                                            width: 150,
                                          ),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(5),
                                                  child: AutoSizeText(
                                                    _merch[i].title.toUpperCase(),
                                                    maxLines: 2,
                                                    maxFontSize: 22,
                                                    textAlign: TextAlign.center,
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
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          padding: EdgeInsets.only(left: 5),
                          width: (MediaQuery.of(context).size.width * 0.5),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: GestureDetector(
                                      onTap: () async {
                                        String channelLink = "https://www.youtube.com/CoachJeremy";
                                        await canLaunchUrlString(channelLink).then((can) {
                                          launchUrlString(channelLink).catchError((err) {
                                            print(err);
                                          });
                                        });
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: FittedBox(
                                              fit: BoxFit.cover,
                                              clipBehavior: Clip.antiAlias,
                                              child: CircleAvatar(
                                                radius: 40,
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
                                            width: 10,
                                          ),
                                          AutoSizeText(
                                            "Coach Jeremy".toUpperCase(),
                                            maxLines: 2,
                                            maxFontSize: 20,
                                            style: TextStyle(
                                              fontFamily: "NovecentoSans",
                                              fontSize: 20,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              String channelLink = "https://www.youtube.com/CoachJeremy";
                                              await canLaunchUrlString(channelLink).then((can) {
                                                launchUrlString(channelLink).catchError((err) {
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
                                      // margin: EdgeInsets.symmetric(vertical: 25),
                                      // child: Center(
                                      //   child: LinearProgressIndicator(
                                      //     color: Theme.of(context).primaryColor,
                                      //   ),
                                      // ),
                                      )
                                  : Container(
                                      height: 185.0,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        shrinkWrap: true,
                                        itemCount: _coachJeremyVideos.length,
                                        itemBuilder: (BuildContext context, int i) {
                                          return GestureDetector(
                                            onTap: () async {
                                              String videoLink = "https://www.youtube.com/watch?v=${_coachJeremyVideos[i].id}";
                                              await canLaunchUrlString(videoLink).then((can) {
                                                launchUrlString(videoLink).catchError((err) {
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
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
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
                          width: (MediaQuery.of(context).size.width * 0.5),
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 5),
                                child: GestureDetector(
                                  onTap: () async {
                                    String channelLink = "https://www.youtube.com/howtohockeydotcom";
                                    await canLaunchUrlString(channelLink).then((can) {
                                      launchUrlString(channelLink).catchError((err) {
                                        print(err);
                                      });
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          clipBehavior: Clip.antiAlias,
                                          child: CircleAvatar(
                                            radius: 40,
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
                                        width: 10,
                                      ),
                                      AutoSizeText(
                                        "How To Hockey".toUpperCase(),
                                        maxLines: 2,
                                        maxFontSize: 20,
                                        style: TextStyle(
                                          fontFamily: "NovecentoSans",
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () async {
                                          String channelLink = "https://www.youtube.com/howtohockeydotcom";
                                          await canLaunchUrlString(channelLink).then((can) {
                                            launchUrlString(channelLink).catchError((err) {
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
                                      // margin: EdgeInsets.symmetric(vertical: 25),
                                      // child: Center(
                                      //   child: LinearProgressIndicator(
                                      //     color: Theme.of(context).primaryColor,
                                      //   ),
                                      // ),
                                      )
                                  : Container(
                                      height: 185.0,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        shrinkWrap: true,
                                        itemCount: _hthVideos.length,
                                        itemBuilder: (BuildContext context, int i) {
                                          return GestureDetector(
                                            onTap: () async {
                                              String videoLink = "https://www.youtube.com/watch?v=${_hthVideos[i].id}";
                                              await canLaunchUrlString(videoLink).then((can) {
                                                launchUrlString(videoLink).catchError((err) {
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
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
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
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 25),
                      padding: EdgeInsets.only(top: 15, bottom: 15),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                child: GestureDetector(
                                  onTap: () async {
                                    String videoLink = "https://www.instagram.com/howtohockey";
                                    await canLaunchUrlString(videoLink).then((can) {
                                      launchUrlString(videoLink).catchError((err) {
                                        print(err);
                                      });
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          clipBehavior: Clip.antiAlias,
                                          child: Image(
                                            image: AssetImage("assets/images/instagram.png"),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                child: GestureDetector(
                                  onTap: () async {
                                    String videoLink = "https://www.facebook.com/howtohockey";
                                    await canLaunchUrlString(videoLink).then((can) {
                                      launchUrlString(videoLink).catchError((err) {
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
                                          child: Image(
                                            image: AssetImage("assets/images/facebook.png"),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                child: GestureDetector(
                                  onTap: () async {
                                    String videoLink = "https://www.tiktok.com/@coachjeremyhth";
                                    await canLaunchUrlString(videoLink).then((can) {
                                      launchUrlString(videoLink).catchError((err) {
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
                                          child: Image(
                                            image: AssetImage("assets/images/tiktok.png"),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                child: GestureDetector(
                                  onTap: () async {
                                    String videoLink = "https://www.twitter.com/howtohockey";
                                    await canLaunchUrlString(videoLink).then((can) {
                                      launchUrlString(videoLink).catchError((err) {
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
                                          child: Image(
                                            image: AssetImage("assets/images/twitter.png"),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
        ),
      ],
    );
  }
}
