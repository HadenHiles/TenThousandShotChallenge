import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/YouTubeVideo.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/VideoStream.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class Learn extends StatefulWidget {
  Learn({Key key}) : super(key: key);

  @override
  _LearnState createState() => _LearnState();
}

class _LearnState extends State<Learn> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  final PageController _learnPageController = PageController(initialPage: 0);
  bool _loadingLearnVideos = true;
  List<YouTubeVideo> _learnVideos = [];
  ScrollController _learnScrollController;

  TabController _tabController;

  @override
  void initState() {
    _loadLearningVideos();
    _learnScrollController = ScrollController();
    _learnScrollController.addListener(this.swapPageListener);

    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
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

  void swapPageListener() {
    if (_learnScrollController.offset > _learnScrollController.position.maxScrollExtent + 50) {
      _learnPageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );
    }

    if (_learnScrollController.offset < _learnScrollController.position.minScrollExtent - 50) {
      _learnPageController.previousPage(
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
                          text: "Free".toUpperCase(),
                        ),
                        Tab(
                          icon: Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: EdgeInsets.all(0),
                          text: "Premium".toUpperCase(),
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
                            height: MediaQuery.of(context).size.height - (MediaQuery.of(context).padding.top + 100 + (sessionService.isRunning ? 60 : 0)),
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
                                          controller: _learnScrollController,
                                          child: Column(
                                            children: [
                                              Container(
                                                margin: EdgeInsets.only(top: 25),
                                                child: Text(
                                                  _learnVideos[i].title.toUpperCase(),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: 42,
                                                  ),
                                                ),
                                              ),
                                              Html(
                                                data: _learnVideos[i].content,
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
                                              _learnVideos[i].buttonUrl.isNotEmpty
                                                  ? Container(
                                                      margin: EdgeInsets.only(bottom: 50),
                                                      child: TextButton(
                                                        onPressed: () async {
                                                          await canLaunch(_learnVideos[i].buttonUrl).then((can) {
                                                            launch(_learnVideos[i].buttonUrl).catchError((err) {
                                                              print(err);
                                                            });
                                                          });
                                                        },
                                                        child: Text(
                                                          _learnVideos[i].buttonText.toUpperCase() ?? "See more".toUpperCase(),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
