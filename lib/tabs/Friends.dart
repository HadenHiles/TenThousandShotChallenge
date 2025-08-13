import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/Invite.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class Friends extends StatefulWidget {
  const Friends({super.key});

  @override
  State<Friends> createState() => _FriendsState();
}

class _FriendsState extends State<Friends> {
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  bool _isLoadingFriends = false;
  List<DocumentSnapshot> _friends = [];

  bool _isLoadingInvites = false;
  List<DocumentSnapshot> _invites = [];
  List<Invite> _inviteDates = [];

  @override
  void initState() {
    _loadFriends();
    _loadInvites();

    super.initState();
  }

  Future<Null> _loadInvites() async {
    setState(() {
      _isLoadingInvites = true;
      _invites = [];
      _inviteDates = [];
    });

    await FirebaseFirestore.instance.collection('invites').doc(user!.uid).collection('invites').orderBy('date', descending: true).get().then((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));

        await Future.forEach(snapshot.docs, (doc) {
          Invite invite = Invite.fromSnapshot(doc as DocumentSnapshot);
          String? fromUid = invite.fromUid;

          FirebaseFirestore.instance.collection('users').doc(fromUid).get().then((uSnap) {
            if (mounted) {
              setState(() {
                _inviteDates.add(invite);
                _invites.add(uSnap);
              });
            }
          });
        }).then((_) {
          if (mounted) {
            setState(() {
              _isLoadingInvites = false;
            });
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingInvites = false;
          });
        }
      }
    });
  }

  Future<Null> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
      _friends = [];
    });

    await FirebaseFirestore.instance.collection('teammates').doc(user!.uid).collection('teammates').orderBy('display_name', descending: false).get().then((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));

        await Future.forEach(snapshot.docs, (DocumentSnapshot doc) {
          FirebaseFirestore.instance.collection('users').doc(doc.reference.id).get().then((uSnap) {
            if (mounted) {
              setState(() {
                _friends.add(uSnap);
              });
            }
          });
        }).then((_) {
          if (mounted) {
            setState(() {
              _isLoadingFriends = false;
            });
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingFriends = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('friends_tab_body'),
      padding: isThreeButtonAndroidNavigation(context) ? EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight) : EdgeInsets.zero,
      margin: const EdgeInsets.all(0),
      child: DefaultTabController(
        length: 2,
        initialIndex: 0,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: HomeTheme.darkTheme.colorScheme.primaryContainer,
              ),
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.white70,
                    labelColor: Colors.white70,
                    labelStyle: const TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 18,
                    ),
                    labelPadding: const EdgeInsets.all(0),
                    tabs: [
                      Tab(
                        icon: const Icon(
                          Icons.people,
                          color: Colors.white70,
                        ),
                        iconMargin: const EdgeInsets.all(0),
                        text: "Friends".toUpperCase(),
                      ),
                      Tab(
                        icon: const Icon(
                          Icons.person_add,
                          color: Colors.white70,
                        ),
                        iconMargin: const EdgeInsets.all(0),
                        text: "Invites".toUpperCase(),
                      ),
                    ],
                  ),
                  // Accept All button for Invites tab
                  Builder(
                    builder: (context) {
                      final tabController = DefaultTabController.of(context);
                      return AnimatedBuilder(
                        animation: tabController,
                        builder: (context, child) {
                          if (tabController.index == 1 && _invites.isNotEmpty) {
                            return Container(
                              alignment: Alignment.centerRight,
                              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 4),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () async {
                                  for (int i = 0; i < _invites.length; i++) {
                                    final UserProfile friend = UserProfile.fromSnapshot(_invites[i]);
                                    await acceptInvite(
                                      Invite(friend.reference!.id, DateTime.now()),
                                      Provider.of<FirebaseAuth>(context, listen: false),
                                      Provider.of<FirebaseFirestore>(context, listen: false),
                                    );
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Theme.of(context).cardTheme.color,
                                      content: const Text(
                                        "All invites accepted!",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      duration: const Duration(milliseconds: 2000),
                                    ),
                                  );
                                  _loadFriends();
                                  _loadInvites();
                                },
                                child: const Text(
                                  "Accept All",
                                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16),
                                ),
                              ),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    child: _isLoadingFriends
                        ? Container(
                            margin: const EdgeInsets.only(top: 25),
                            child: Center(
                              child: SizedBox(
                                height: 30,
                                width: 30,
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          )
                        : _friends.isEmpty
                            ? SizedBox(
                                width: MediaQuery.of(context).size.width - 30,
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 40),
                                      child: Text(
                                        "Tap + to invite a friend".toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 15),
                                      child: Center(
                                        child: Ink(
                                          decoration: ShapeDecoration(
                                            color: Theme.of(context).cardTheme.color,
                                            shape: const CircleBorder(),
                                          ),
                                          child: IconButton(
                                            color: Theme.of(context).cardTheme.color,
                                            onPressed: () {
                                              context.push('/add-friend');
                                            },
                                            iconSize: 40,
                                            icon: Icon(
                                              Icons.add,
                                              size: 40,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 0, right: 0, left: 0, bottom: kToolbarHeight),
                                itemCount: _friends.length + 1,
                                itemBuilder: (_, int index) {
                                  if (index < _friends.length) {
                                    final DocumentSnapshot document = _friends[index];
                                    return _buildFriendItem(UserProfile.fromSnapshot(document), index % 2 == 0 ? true : false);
                                  }

                                  return !_isLoadingFriends
                                      ? Container()
                                      : const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                height: 25,
                                                width: 25,
                                                child: CircularProgressIndicator(),
                                              ),
                                            ],
                                          ),
                                        );
                                },
                              ),
                    onRefresh: () async {
                      _friends.clear();
                      await _loadFriends();
                    },
                  ),
                  RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    child: _isLoadingInvites
                        ? Container(
                            margin: const EdgeInsets.only(top: 25),
                            child: Center(
                              child: SizedBox(
                                height: 30,
                                width: 30,
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          )
                        : _invites.isEmpty
                            ? Container(
                                margin: const EdgeInsets.symmetric(vertical: 25),
                                child: const Center(
                                  child: Text("No invites"),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 0, left: 0, right: 0, bottom: kToolbarHeight),
                                itemCount: _invites.length + 1,
                                itemBuilder: (_, int index) {
                                  if (index < _invites.length) {
                                    final DocumentSnapshot document = _invites[index];
                                    return _buildFriendInviteItem(UserProfile.fromSnapshot(document), _inviteDates[index], index % 2 == 0 ? true : false);
                                  }

                                  return !_isLoadingInvites
                                      ? Container()
                                      : const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                height: 25,
                                                width: 25,
                                                child: CircularProgressIndicator(),
                                              ),
                                            ],
                                          ),
                                        );
                                },
                              ),
                    onRefresh: () async {
                      _invites.clear();
                      await _loadInvites();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(UserProfile friend, bool bg) {
    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);

        context.push('/player/${friend.reference!.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
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
    );
  }

  Widget _buildFriendInviteItem(UserProfile friend, Invite invite, bool bg) {
    User? user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;

    return Dismissible(
      key: UniqueKey(),
      onDismissed: (direction) async {
        await deleteInvite(
          friend.reference!.id,
          user!.uid,
          Provider.of<FirebaseAuth>(context, listen: false),
          Provider.of<FirebaseFirestore>(context, listen: false),
        ).then((deleted) {
          if (!deleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).cardTheme.color,
                content: Text(
                  "The invite couldn't be deleted",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                duration: const Duration(milliseconds: 1500),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).cardTheme.color,
                content: Text(
                  "Invite from ${friend.displayName} deleted",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                duration: const Duration(milliseconds: 1500),
              ),
            );
          }

          _invites.clear();
          _loadInvites();
        });
      },
      confirmDismiss: (DismissDirection direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                "Delete Invite from ${friend.displayName}?".toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 24,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Are you sure you want to delete this friend's invite?",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    "Cancel".toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    "Delete".toUpperCase(),
                    style: TextStyle(fontFamily: 'NovecentoSans', color: Theme.of(context).primaryColor),
                  ),
                ),
              ],
            );
          },
        );
      },
      background: Container(
        color: Theme.of(context).primaryColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 15),
              child: Text(
                "Delete".toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 15),
              child: const Icon(
                Icons.delete,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg ? Theme.of(context).cardTheme.color : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15),
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: SizedBox(
                    height: 60,
                    child: GestureDetector(
                      onTap: () {
                        Feedback.forTap(context);
                        context.push('/player/${friend.reference!.id}');
                      },
                      child: UserAvatar(
                        user: friend,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    friend.displayName != null
                        ? SizedBox(
                            width: MediaQuery.of(context).size.width - 255,
                            child: AutoSizeText(
                              friend.displayName!,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                          )
                        : Container(),
                  ],
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 40,
                  child: AutoSizeText(
                    printDuration(DateTime.now().difference(invite.date!), false),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextButton(
                    onPressed: () {
                      acceptInvite(
                        Invite(friend.reference!.id, DateTime.now()),
                        Provider.of<FirebaseAuth>(context, listen: false),
                        Provider.of<FirebaseFirestore>(context, listen: false),
                      ).then((accepted) {
                        if (!accepted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Theme.of(context).cardTheme.color,
                              content: Text(
                                "Error accepting invite from ${friend.displayName} :(",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              duration: const Duration(milliseconds: 2500),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Theme.of(context).cardTheme.color,
                              content: Text(
                                "Invite from ${friend.displayName} accepted!",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              duration: const Duration(milliseconds: 1500),
                            ),
                          );

                          _loadFriends();
                          _loadInvites();
                        }
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.blue.shade600),
                    ),
                    child: Text(
                      "Accept".toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
