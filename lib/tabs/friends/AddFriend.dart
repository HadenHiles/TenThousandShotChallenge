import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:share_plus/share_plus.dart';

class AddFriend extends StatefulWidget {
  const AddFriend({Key? key}) : super(key: key);

  @override
  State<AddFriend> createState() => _AddFriendState();
}

class _AddFriendState extends State<AddFriend> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController searchFieldController = TextEditingController();

  List<DocumentSnapshot> _friends = [];
  bool _isSearching = false;
  int? _selectedFriend;

  Future<bool> scanBarcodeNormal() async {
    String barcodeScanRes;

    // Invitee uid (from_uid)
    barcodeScanRes = await FlutterBarcodeScanner.scanBarcode("#ff6666", "Cancel", true, ScanMode.QR);
    print(barcodeScanRes);

    return addFriendBarcode(barcodeScanRes);
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider<NetworkStatus>(
      create: (context) {
        return NetworkStatusService().networkStatusController.stream;
      },
      initialData: NetworkStatus.Online,
      child: NetworkAwareWidget(
        offlineChild: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
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
                const Image(
                  image: AssetImage('assets/images/logo.png'),
                ),
                Text(
                  "Where's the wifi bud?".toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: "NovecentoSans",
                    fontSize: 24,
                  ),
                ),
                const SizedBox(
                  height: 25,
                ),
                const CircularProgressIndicator(
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        onlineChild: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  collapsedHeight: 65,
                  expandedHeight: 65,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  floating: true,
                  pinned: true,
                  leading: Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () {
                        navigatorKey.currentState!.pop();
                      },
                    ),
                  ),
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
                    ),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      title: const BasicTitle(title: "Invite Friend"),
                      background: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        onPressed: () {
                          Share.share(
                            'Take the How To Hockey 10,000 Shot Challenge!\nhttp://hyperurl.co/tenthousandshots',
                            subject: 'Take the How To Hockey 10,000 Shot Challenge!',
                          );
                        },
                        icon: Icon(
                          Icons.share,
                          size: 28,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    _selectedFriend == null
                        ? Container()
                        : Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: IconButton(
                              icon: Icon(
                                Icons.send,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 28,
                              ),
                              onPressed: () {
                                inviteTeammate(user!.uid, _friends[_selectedFriend!].id).then((success) {
                                  if (success!) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Theme.of(context).cardTheme.color,
                                        content: Text(
                                          "${UserProfile.fromSnapshot(_friends[_selectedFriend!]).displayName} Invited!",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );

                                    setState(() {
                                      _selectedFriend = null;
                                      _friends = [];
                                    });
                                    searchFieldController.text = "";
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Theme.of(context).cardTheme.color,
                                        content: Text(
                                          "Failed to invite ${UserProfile.fromSnapshot(_friends[_selectedFriend!]).displayName} :(",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                });
                              },
                            ),
                          ),
                  ],
                ),
              ];
            },
            body: GestureDetector(
              onTap: () {
                Feedback.forTap(context);

                FocusScopeNode currentFocus = FocusScope.of(context);

                if (!currentFocus.hasPrimaryFocus) {
                  currentFocus.unfocus();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.05),
                          width: (MediaQuery.of(context).size.width * 0.7) - 10,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Name or Email'.toUpperCase(),
                                    labelText: "Find a friend".toUpperCase(),
                                    alignLabelWithHint: true,
                                    labelStyle: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                    hintStyle: TextStyle(
                                      fontFamily: 'NovecentoSans',
                                      fontSize: 20,
                                      color: Theme.of(context).cardTheme.color,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontFamily: 'NovecentoSans',
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  onChanged: (value) async {
                                    if (value.isNotEmpty) {
                                      setState(() {
                                        _isSearching = true;
                                      });

                                      List<DocumentSnapshot> users = [];
                                      if (value.isNotEmpty) {
                                        await FirebaseFirestore.instance.collection('users').orderBy('display_name_lowercase', descending: false).orderBy('display_name', descending: false).where('public', isEqualTo: true).startAt([value.toLowerCase()]).endAt(['${value.toLowerCase()}\uf8ff']).get().then((uSnaps) async {
                                              for (var uDoc in uSnaps.docs) {
                                                if (uDoc.reference.id != user!.uid) {
                                                  users.add(uDoc);
                                                }
                                              }
                                            });
                                        if (users.isEmpty) {
                                          await FirebaseFirestore.instance.collection('users').orderBy('email', descending: false).where('public', isEqualTo: true).startAt([value.toLowerCase()]).endAt(['${value.toLowerCase()}\uf8ff']).get().then((uSnaps) async {
                                                for (var uDoc in uSnaps.docs) {
                                                  if (uDoc.reference.id != user!.uid) {
                                                    users.add(uDoc);
                                                  }
                                                }
                                              });
                                        }

                                        await Future.delayed(const Duration(milliseconds: 500));

                                        setState(() {
                                          _friends = users;
                                          _isSearching = false;
                                        });
                                      }

                                      setState(() {
                                        _friends = users;
                                        _isSearching = false;
                                      });
                                    } else {
                                      setState(() {
                                        _friends = [];
                                        _isSearching = false;
                                      });
                                    }
                                  },
                                  controller: searchFieldController,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return 'Enter a name or email address';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Scan".toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 20,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(right: 0),
                                child: IconButton(
                                  onPressed: () {
                                    scanBarcodeNormal().then((success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Theme.of(context).cardTheme.color,
                                          content: Text(
                                            "You are now friends!",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          duration: const Duration(milliseconds: 2500),
                                        ),
                                      );

                                      navigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (context) {
                                        return Navigation(
                                          title: NavigationTitle(title: "Friends".toUpperCase()),
                                          selectedIndex: 1,
                                        );
                                      }));
                                    }).onError((error, stackTrace) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Theme.of(context).cardTheme.color,
                                          content: Text(
                                            "There was an error scanning your friend's QR code :(",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          duration: const Duration(milliseconds: 4000),
                                        ),
                                      );
                                    });
                                  },
                                  icon: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 50,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: _isSearching && _friends.isEmpty && searchFieldController.text.isNotEmpty
                          ? Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Center(
                                  child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                                )
                              ],
                            )
                          : _friends.isEmpty && searchFieldController.text.isNotEmpty
                              ? Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 40),
                                      child: Text(
                                        "Couldn't find your friend?",
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 25),
                                      child: Text(
                                        "Challenge them!".toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 26,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 5),
                                      child: IconButton(
                                        onPressed: () {
                                          Share.share(
                                            'Take the How To Hockey 10,000 Shot Challenge!\nhttp://hyperurl.co/tenthousandshots',
                                            subject: 'Take the How To Hockey 10,000 Shot Challenge!',
                                          );
                                        },
                                        icon: Icon(
                                          Icons.share,
                                          size: 40,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  children: _buildFriendResults(),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFriendResults() {
    List<Widget> friends = [];
    _friends.asMap().forEach((i, doc) {
      UserProfile friend = UserProfile.fromSnapshot(doc);

      friends.add(
        GestureDetector(
          onTap: () {
            Feedback.forTap(context);

            FocusScopeNode currentFocus = FocusScope.of(context);

            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }

            setState(() {
              _selectedFriend = _selectedFriend == i ? null : i;
              searchFieldController.text = searchFieldController.text;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: _selectedFriend == i ? Theme.of(context).cardTheme.color : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                _selectedFriend == i
                    ? Container(
                        height: 60,
                        width: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(30)),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedFriend = null;
                              searchFieldController.text = searchFieldController.text;
                            });
                          },
                          icon: const Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        width: 60,
                        height: 60,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: SizedBox(
                          height: 60,
                          child: UserAvatar(
                            user: friend,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        friend.displayName != null
                            ? SizedBox(
                                width: MediaQuery.of(context).size.width - 235,
                                child: AutoSizeText(
                                  friend.displayName!,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                              )
                            : Container(),
                      ],
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 135,
                          child: StreamBuilder(
                              stream: FirebaseFirestore.instance.collection('iterations').doc(friend.reference!.id).collection('iterations').snapshots(),
                              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: SizedBox(
                                      width: 120,
                                      height: 2,
                                      child: LinearProgressIndicator(),
                                    ),
                                  );
                                } else {
                                  int total = 0;
                                  for (var doc in snapshot.data!.docs) {
                                    total += Iteration.fromSnapshot(doc).total!;
                                  }

                                  return AutoSizeText(
                                    "$total Lifetime Shots",
                                    maxLines: 1,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'NovecentoSans',
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  );
                                }
                              }),
                        ),
                        StreamBuilder(
                            stream: FirebaseFirestore.instance.collection('iterations').doc(friend.reference!.id).collection('iterations').snapshots(),
                            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: SizedBox(
                                    width: 120,
                                    height: 2,
                                    child: LinearProgressIndicator(),
                                  ),
                                );
                              } else {
                                Duration totalDuration = const Duration();
                                for (var doc in snapshot.data!.docs) {
                                  totalDuration += Iteration.fromSnapshot(doc).totalDuration!;
                                }

                                return totalDuration > const Duration()
                                    ? Text(
                                        "IN ${printDuration(totalDuration, true)}",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontFamily: 'NovecentoSans',
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      )
                                    : Container();
                              }
                            }),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });

    return friends;
  }
}
