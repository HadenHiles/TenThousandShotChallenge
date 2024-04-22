import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:tenthousandshotchallenge/models/YouTubeVideo.dart';
import 'package:tenthousandshotchallenge/models/firestore/LearnToPlayItem.dart';
import 'package:tenthousandshotchallenge/models/firestore/Merch.dart';
import 'package:tenthousandshotchallenge/models/firestore/TrainingProgram.dart';
import 'package:tenthousandshotchallenge/services/YouTubeChannelService.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:tenthousandshotchallenge/widgets/VideoStream.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class Explore extends StatefulWidget {
  const Explore({Key? key}) : super(key: key);

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  final PageController _explorePageController = PageController(initialPage: 0);
  bool _loadingExploreVideos = true;
  List<YouTubeVideo> _exploreVideos = [];
  ScrollController? _exploreScrollController;

  String _coachJeremyPhoto = "";
  final bool _loadingCoachJeremyVideos = true;
  final List<YouTubeVideo> _coachJeremyVideos = [];
  String _hthPhoto = "";
  final bool _loadingHthVideos = true;
  final List<YouTubeVideo> _hthVideos = [];

  bool _loadingPrograms = true;
  List<TrainingProgram> _programs = [];

  bool _loadingLearnToPlayItems = true;
  List<LearnToPlayItem> _learnToPlayItems = [];

  bool _loadingMerch = true;
  List<Merch> _merch = [];

  bool _oneChallengeCompleted = false;

  TabController? _tabController;

  @override
  void initState() {
    _loadExploringVideos();
    _loadTrainingPrograms();
    _loadLearnToPlayItems();
    _loadMerch();
    _checkIfChallengeCompletedOnce();
    _loadYoutubeChannels();

    _exploreScrollController = ScrollController();
    _exploreScrollController!.addListener(swapPageListener);

    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController!.addListener(changeTabListener);

    super.initState();
  }

  @override
  void dispose() {
    _tabController!.dispose();

    super.dispose();
  }

  Future<void> changeTabListener() async {
    if (_tabController!.indexIsChanging) {
      switch (_tabController!.index) {
        case 0:
          break;
        case 1:
          break;
        case 2:
          break;
      }
    }
  }

  Future<Null> _loadExploringVideos() async {
    List<YouTubeVideo> videos = [];
    await FirebaseFirestore.instance.collection('learn_videos').orderBy('order', descending: false).get().then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        for (var vDoc in snapshot.docs) {
          YouTubeVideo vid = YouTubeVideo.fromSnapshot(vDoc);
          videos.add(vid);
        }
      }
    }).timeout(const Duration(seconds: 10), onTimeout: () {
      print("_loadExploringVideos timed out");
      setState(() {
        _loadingExploreVideos = false;
      });
    }).onError((error, stackTrace) {
      print("Error loading explore videos: $error");
      setState(() {
        _loadingExploreVideos = false;
      });
    });

    setState(() {
      _exploreVideos = videos;
      _loadingExploreVideos = false;
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

  Future<Null> _loadTrainingPrograms() async {
    List<TrainingProgram> programs = [];
    await FirebaseFirestore.instance.collection('trainingPrograms').orderBy('order', descending: false).get().then((snapshot) {
      for (var pDoc in snapshot.docs) {
        TrainingProgram program = TrainingProgram.fromSnapshot(pDoc);
        programs.add(program);
      }
    }).timeout(const Duration(seconds: 10), onTimeout: () {
      print("_loadTrainingPrograms timed out");
      setState(() {
        _loadingPrograms = false;
      });
    }).onError((error, stackTrace) {
      print("Error loading training programs: $error");
      setState(() {
        _loadingPrograms = false;
      });
    });

    setState(() {
      _programs = programs;
      _loadingPrograms = false;
    });
  }

  Future<Null> _loadLearnToPlayItems() async {
    List<LearnToPlayItem> items = [];
    await FirebaseFirestore.instance.collection('learn_to_play').orderBy('order', descending: false).get().then((snapshot) {
      for (var pDoc in snapshot.docs) {
        LearnToPlayItem item = LearnToPlayItem.fromSnapshot(pDoc);
        items.add(item);
      }
    }).timeout(const Duration(seconds: 10), onTimeout: () {
      print("_loadLearnToPlayItems timed out");
      setState(() {
        _loadingLearnToPlayItems = false;
      });
    }).onError((error, stackTrace) {
      print("Error loading learn to play items: $error");
      setState(() {
        _loadingLearnToPlayItems = false;
      });
    });

    setState(() {
      _learnToPlayItems = items;
      _loadingLearnToPlayItems = false;
    });
  }

  Future<Null> _loadMerch() async {
    List<Merch> merch = [];
    await FirebaseFirestore.instance.collection('merch').orderBy('order', descending: false).get().then((snapshot) {
      for (var mDoc in snapshot.docs) {
        Merch product = Merch.fromSnapshot(mDoc);
        merch.add(product);
      }
    }).timeout(const Duration(seconds: 30), onTimeout: () {
      print("_loadMerch timed out");
      setState(() {
        _loadingMerch = false;
      });
    }).onError((error, stackTrace) {
      print("Error loading merch: $error");
      setState(() {
        _loadingMerch = false;
      });
    });

    setState(() {
      _merch = merch;
      _loadingMerch = false;
    });
  }

  Future<Null> _checkIfChallengeCompletedOnce() async {
    await FirebaseFirestore.instance.collection('iterations').doc(user!.uid).collection('iterations').where('complete', isEqualTo: true).get().then((snap) async {
      if (snap.docs.isNotEmpty) {
        setState(() {
          _oneChallengeCompleted = true;
        });
      }
    });
  }

  void swapPageListener() {
    if (_exploreScrollController!.offset > _exploreScrollController!.position.maxScrollExtent + 50) {
      _explorePageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );
    }

    if (_exploreScrollController!.offset < _exploreScrollController!.position.minScrollExtent - 50) {
      _explorePageController.previousPage(
        duration: const Duration(milliseconds: 500),
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
          margin: const EdgeInsets.only(
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
                      labelStyle: const TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                      ),
                      labelPadding: const EdgeInsets.all(0),
                      indicatorColor: Theme.of(context).primaryColor,
                      tabs: [
                        Tab(
                          icon: const Icon(
                            Icons.video_collection_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: const EdgeInsets.all(0),
                          text: "Tips".toUpperCase(),
                        ),
                        Tab(
                          icon: const Icon(
                            Icons.sports_hockey_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: const EdgeInsets.all(0),
                          text: "Train".toUpperCase(),
                        ),
                        Tab(
                          icon: const Icon(
                            Icons.add_box_rounded,
                            color: Colors.white70,
                          ),
                          iconMargin: const EdgeInsets.all(0),
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
                    _loadingExploreVideos || _exploreVideos.isEmpty
                        ? Container(
                            margin: const EdgeInsets.symmetric(vertical: 25),
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
                        : Expanded(
                            child: PageView.builder(
                              controller: _explorePageController,
                              scrollDirection: Axis.vertical,
                              itemCount: _exploreVideos.length,
                              itemBuilder: (BuildContext context, int i) {
                                YoutubePlayerController ytController = YoutubePlayerController(
                                  initialVideoId: _exploreVideos[i].id,
                                  flags: const YoutubePlayerFlags(
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
                                        controller: ytController,
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
                                        actionsPadding: const EdgeInsets.all(2),
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
                                          vertical: 5,
                                          horizontal: MediaQuery.of(context).size.width * .075,
                                        ),
                                        child: SingleChildScrollView(
                                          physics: const BouncingScrollPhysics(),
                                          controller: _exploreScrollController,
                                          child: Column(
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(top: 15),
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
                                                    fontSize: FontSize(23),
                                                  ),
                                                  "ul": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: FontSize(23),
                                                    listStyleType: ListStyleType.disc,
                                                  ),
                                                  "ol": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontFamily: "NovecentoSans",
                                                    fontSize: FontSize(23),
                                                    listStyleType: ListStyleType.decimal,
                                                    listStylePosition: ListStylePosition.inside,
                                                    lineHeight: LineHeight.em(1.1),
                                                  ),
                                                  "ul li, ol li": Style(
                                                    padding: HtmlPaddings.symmetric(vertical: 5),
                                                    margin: Margins.only(bottom: 2),
                                                  ),
                                                  "p": Style(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    fontSize: FontSize(16),
                                                  ),
                                                },
                                              ),
                                              _exploreVideos[i].buttonUrl!.isNotEmpty
                                                  ? Container(
                                                      margin: const EdgeInsets.only(bottom: 25),
                                                      child: TextButton(
                                                        onPressed: () async {
                                                          await canLaunchUrlString(_exploreVideos[i].buttonUrl!).then((can) {
                                                            launchUrlString(_exploreVideos[i].buttonUrl!).catchError((err) {
                                                              print(err);
                                                              return false;
                                                            });
                                                          });
                                                        },
                                                        style: ButtonStyle(
                                                          padding: MaterialStateProperty.all(
                                                            const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                                          ),
                                                          backgroundColor: MaterialStateProperty.all(
                                                            Theme.of(context).primaryColor,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          _exploreVideos[i].buttonText?.toUpperCase() ?? "See more".toUpperCase(),
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontFamily: "NovecentoSans",
                                                            fontSize: 24,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _loadingPrograms || _programs.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                "Coming Soon!".toUpperCase(),
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                height: 50,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(top: 10),
                                  width: MediaQuery.of(context).size.width - 15,
                                  height: 40,
                                  child: Text(
                                    "Training Programs:".toUpperCase(),
                                    style: Theme.of(context).textTheme.headlineSmall,
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                SizedBox(
                                  height: 280,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _programs.length,
                                    shrinkWrap: false,
                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                                    itemBuilder: (BuildContext context, int i) {
                                      return SizedBox(
                                        height: 240,
                                        width: MediaQuery.of(context).size.width - (MediaQuery.of(context).size.width * 0.25),
                                        child: GestureDetector(
                                          onTap: () async {
                                            String? link = _programs[i].url;
                                            await canLaunchUrlString(link!).then((can) {
                                              launchUrlString(link).catchError((err) {
                                                print(err);
                                                return false;
                                              });
                                            });
                                          },
                                          child: Card(
                                            color: Theme.of(context).cardTheme.color,
                                            elevation: 4,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: MediaQuery.of(context).size.width - (MediaQuery.of(context).size.width * 0.25),
                                                  height: 215,
                                                  decoration: BoxDecoration(
                                                    image: DecorationImage(
                                                      fit: BoxFit.cover,
                                                      image: NetworkImage(
                                                        _programs[i].image!,
                                                      ) as ImageProvider,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  child: AutoSizeText(
                                                    _programs[i].title!.toUpperCase(),
                                                    maxLines: 2,
                                                    maxFontSize: 25,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: "NovecentoSans",
                                                      fontSize: 25,
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
                    _loadingLearnToPlayItems || _learnToPlayItems.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              SizedBox(
                                height: 50,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(top: 10),
                                  width: MediaQuery.of(context).size.width - 25,
                                  height: 40,
                                  child: Text(
                                    "Learn the game:".toUpperCase(),
                                    style: Theme.of(context).textTheme.headlineSmall,
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                SizedBox(
                                  height: 280,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _learnToPlayItems.length,
                                    shrinkWrap: false,
                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                                    itemBuilder: (BuildContext context, int i) {
                                      return SizedBox(
                                        height: 240,
                                        width: MediaQuery.of(context).size.width - (MediaQuery.of(context).size.width * 0.25),
                                        child: GestureDetector(
                                          onTap: () async {
                                            String link = _learnToPlayItems[i].url!;
                                            await canLaunchUrlString(link).then((can) {
                                              launchUrlString(link).catchError((err) {
                                                print(err);
                                                return false;
                                              });
                                            });
                                          },
                                          child: Card(
                                            color: Theme.of(context).cardTheme.color,
                                            elevation: 4,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: MediaQuery.of(context).size.width - (MediaQuery.of(context).size.width * 0.25),
                                                  height: 215,
                                                  decoration: BoxDecoration(
                                                    image: DecorationImage(
                                                      fit: BoxFit.cover,
                                                      image: NetworkImage(
                                                        _learnToPlayItems[i].image!,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  child: AutoSizeText(
                                                    _learnToPlayItems[i].title!.toUpperCase(),
                                                    maxLines: 2,
                                                    maxFontSize: 25,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: "NovecentoSans",
                                                      fontSize: 25,
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
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: GestureDetector(
                            onTap: () async {
                              Uri merchLink = Uri(scheme: "https", host: "merch.howtohockey.com");
                              await canLaunchUrl(merchLink).then((can) {
                                launchUrl(merchLink).catchError((err) {
                                  print(err);
                                  return false;
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
                                      backgroundImage: const AssetImage("assets/images/avatar.png"),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(
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
                                        return false;
                                      });
                                    });
                                  },
                                  icon: Icon(
                                    FontAwesomeIcons.bagShopping,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    _loadingMerch || _merch.isEmpty
                        ? Container(
                            margin: const EdgeInsets.symmetric(vertical: 25),
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
                        : SizedBox(
                            height: 220.0,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const AlwaysScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _merch.length,
                              itemBuilder: (BuildContext context, int i) {
                                return GestureDetector(
                                  onTap: () async {
                                    String link = _merch[i].url!;

                                    if (_oneChallengeCompleted && _merch[i].title!.replaceAll(" ", "").toLowerCase() == "snipersnapback") {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return Dialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                                            child: SingleChildScrollView(
                                              clipBehavior: Clip.none,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.topCenter,
                                                children: [
                                                  SizedBox(
                                                    height: 550,
                                                    child: Padding(
                                                      padding: const EdgeInsets.fromLTRB(10, 70, 10, 10),
                                                      child: Column(
                                                        children: [
                                                          Text(
                                                            "Congradulations!".toUpperCase(),
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                              color: Theme.of(context).primaryColor,
                                                              fontFamily: "NovecentoSans",
                                                              fontSize: 32,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          Text(
                                                            "Nice job, ya beauty!\n10,000 shots isn't easy.",
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onPrimary,
                                                              fontFamily: "NovecentoSans",
                                                              fontSize: 22,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          Opacity(
                                                            opacity: 0.8,
                                                            child: Text(
                                                              "To celebrate, here's 40% off our limited edition Sniper Snapback only available to snipers like yourself!",
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onPrimary,
                                                                fontFamily: "NovecentoSans",
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 15,
                                                          ),
                                                          GestureDetector(
                                                            onTap: () async {
                                                              String link = "https://howtohockey.com/link/sniper-snapback-coupon/";
                                                              await canLaunchUrlString(link).then((can) {
                                                                launchUrlString(link).catchError((err) {
                                                                  print(err);
                                                                  return false;
                                                                });
                                                              });
                                                            },
                                                            child: Card(
                                                              color: Theme.of(context).cardTheme.color,
                                                              elevation: 4,
                                                              child: SizedBox(
                                                                width: 125,
                                                                height: 180,
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                                  children: [
                                                                    const Image(
                                                                      image: NetworkImage(
                                                                        "https://howtohockey.com/wp-content/uploads/2021/07/featured.jpg",
                                                                      ),
                                                                      width: 150,
                                                                    ),
                                                                    Expanded(
                                                                      child: Column(
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        children: [
                                                                          Container(
                                                                            padding: const EdgeInsets.all(5),
                                                                            child: AutoSizeText(
                                                                              "Sniper Snapback".toUpperCase(),
                                                                              maxLines: 2,
                                                                              maxFontSize: 20,
                                                                              textAlign: TextAlign.center,
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
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.primaryContainer,
                                                            ),
                                                            padding: const EdgeInsets.all(5),
                                                            child: SelectableText(
                                                              "TENKSNIPER",
                                                              style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onPrimary,
                                                                fontFamily: "NovecentoSans",
                                                                fontSize: 24,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          TextButton(
                                                            onPressed: () async {
                                                              Navigator.of(context).pop();
                                                              String link = "https://howtohockey.com/link/sniper-snapback-coupon/";
                                                              await canLaunchUrlString(link).then((can) {
                                                                launchUrlString(link).catchError((err) {
                                                                  print(err);
                                                                  return false;
                                                                });
                                                              });
                                                            },
                                                            style: ButtonStyle(
                                                              backgroundColor: MaterialStateProperty.all(
                                                                Theme.of(context).primaryColor,
                                                              ),
                                                              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 4, horizontal: 15)),
                                                            ),
                                                            child: Text(
                                                              "Get yours".toUpperCase(),
                                                              style: const TextStyle(
                                                                fontFamily: "NovecentoSans",
                                                                fontSize: 30,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const Positioned(
                                                    top: -40,
                                                    child: SizedBox(
                                                      width: 100,
                                                      height: 100,
                                                      child: Image(
                                                        image: AssetImage("assets/images/GoalLight.gif"),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    } else {
                                      await canLaunchUrlString(link).then((can) {
                                        launchUrlString(link).catchError((err) {
                                          print(err);
                                          return false;
                                        });
                                      });
                                    }
                                  },
                                  child: Card(
                                    color: Theme.of(context).cardTheme.color,
                                    elevation: 4,
                                    child: SizedBox(
                                      width: 150.0,
                                      height: 32.25,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 150,
                                            height: 175,
                                            decoration: BoxDecoration(
                                              image: DecorationImage(
                                                fit: BoxFit.cover,
                                                image: NetworkImage(
                                                  _merch[i].image!,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(5),
                                                  child: AutoSizeText(
                                                    _merch[i].title!.toUpperCase(),
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
                          padding: const EdgeInsets.only(left: 5),
                          width: (MediaQuery.of(context).size.width * 0.5),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: GestureDetector(
                                      onTap: () async {
                                        String channelLink = "https://www.youtube.com/CoachJeremy";
                                        await canLaunchUrlString(channelLink).then((can) {
                                          launchUrlString(channelLink).catchError((err) {
                                            print(err);
                                            return false;
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
                                                backgroundImage: NetworkImage(
                                                  _coachJeremyPhoto,
                                                ),
                                                backgroundColor: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 5,
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
                                                  return false;
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
                              _loadingCoachJeremyVideos || _coachJeremyVideos.isEmpty
                                  ? Container(
                                      // margin: EdgeInsets.symmetric(vertical: 25),
                                      // child: Center(
                                      //   child: LinearProgressIndicator(
                                      //     color: Theme.of(context).primaryColor,
                                      //   ),
                                      // ),
                                      )
                                  : SizedBox(
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
                                                  return false;
                                                });
                                              });
                                            },
                                            child: Card(
                                              color: Theme.of(context).cardTheme.color,
                                              elevation: 4,
                                              child: SizedBox(
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
                                                            padding: const EdgeInsets.all(5),
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
                        SizedBox(
                          width: (MediaQuery.of(context).size.width * 0.5),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: GestureDetector(
                                  onTap: () async {
                                    String channelLink = "https://www.youtube.com/howtohockeydotcom";
                                    await canLaunchUrlString(channelLink).then((can) {
                                      launchUrlString(channelLink).catchError((err) {
                                        print(err);
                                        return false;
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
                                            backgroundImage: NetworkImage(
                                              _hthPhoto,
                                            ),
                                            backgroundColor: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 5,
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
                                              return false;
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
                              _loadingHthVideos || _hthVideos.isEmpty
                                  ? Container(
                                      // margin: EdgeInsets.symmetric(vertical: 25),
                                      // child: Center(
                                      //   child: LinearProgressIndicator(
                                      //     color: Theme.of(context).primaryColor,
                                      //   ),
                                      // ),
                                      )
                                  : SizedBox(
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
                                                  return false;
                                                });
                                              });
                                            },
                                            child: Card(
                                              color: Theme.of(context).cardTheme.color,
                                              elevation: 4,
                                              child: SizedBox(
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
                                                            padding: const EdgeInsets.all(5),
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
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      padding: const EdgeInsets.only(top: 15, bottom: 15),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  String videoLink = "https://www.instagram.com/howtohockey";
                                  await canLaunchUrlString(videoLink).then((can) {
                                    launchUrlString(videoLink).catchError((err) {
                                      print(err);
                                      return false;
                                    });
                                  });
                                },
                                child: const Row(
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
                              GestureDetector(
                                onTap: () async {
                                  String videoLink = "https://www.facebook.com/howtohockey";
                                  await canLaunchUrlString(videoLink).then((can) {
                                    launchUrlString(videoLink).catchError((err) {
                                      print(err);
                                      return false;
                                    });
                                  });
                                },
                                child: const Row(
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
                              GestureDetector(
                                onTap: () async {
                                  String videoLink = "https://www.tiktok.com/@coachjeremyhth";
                                  await canLaunchUrlString(videoLink).then((can) {
                                    launchUrlString(videoLink).catchError((err) {
                                      print(err);
                                      return false;
                                    });
                                  });
                                },
                                child: const Row(
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
                              GestureDetector(
                                onTap: () async {
                                  String videoLink = "https://www.twitter.com/howtohockey";
                                  await canLaunchUrlString(videoLink).then((can) {
                                    launchUrlString(videoLink).catchError((err) {
                                      print(err);
                                      return false;
                                    });
                                  });
                                },
                                child: const Row(
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
