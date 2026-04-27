import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/MobileScanner/barcode_scanner_simple.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tenthousandshotchallenge/tabs/friends/PlayerProfileSheet.dart';

class AddFriend extends StatefulWidget {
  const AddFriend({super.key});

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

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3), fontSize: 16),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5)),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 12,
          letterSpacing: 0.5,
          color: (preferences?.darkMode ?? false) ? darken(Theme.of(context).colorScheme.onPrimary, 0.4) : darken(Theme.of(context).colorScheme.primaryContainer, 0.3),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
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
            color: Theme.of(context).primaryColor,
            margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Image(image: AssetImage('assets/images/logo.png')),
                Text("Where's the wifi bud?".toUpperCase(), style: const TextStyle(color: Colors.white70, fontFamily: 'NovecentoSans', fontSize: 24)),
                const SizedBox(height: 25),
                const CircularProgressIndicator(color: Colors.white70),
              ],
            ),
          ),
        ),
        onlineChild: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
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
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      title: const BasicTitle(title: "Invite Friend"),
                      background: Container(color: Theme.of(context).scaffoldBackgroundColor),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        onPressed: () {
                          SharePlus.instance.share(ShareParams(
                            text: 'Take the How To Hockey 10,000 Shot Challenge!\nhttp://hyperurl.co/tenthousandshots',
                            subject: 'Take the How To Hockey 10,000 Shot Challenge!',
                          ));
                        },
                        icon: Icon(Icons.share, size: 28, color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                    if (_selectedFriend != null)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: IconButton(
                          icon: Icon(Icons.send, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                          onPressed: () {
                            inviteFriend(
                              user!.uid,
                              _friends[_selectedFriend!].id,
                              Provider.of<FirebaseFirestore>(context, listen: false),
                            ).then((success) {
                              if (success!) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Theme.of(context).cardTheme.color,
                                    content: Text(
                                      "${UserProfile.fromSnapshot(_friends[_selectedFriend!]).displayName} Invited!",
                                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
                                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Search + QR ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _card(children: [
                      _sectionLabel('Find a Friend'),
                      Form(
                        key: _formKey,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: searchFieldController,
                                keyboardType: TextInputType.text,
                                style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onPrimary),
                                decoration: _fieldDecoration(hint: 'Name or email...'),
                                onChanged: (value) async {
                                  if (value.isNotEmpty) {
                                    setState(() => _isSearching = true);

                                    List<DocumentSnapshot> users = [];
                                    await FirebaseFirestore.instance.collection('users').orderBy('display_name_lowercase', descending: false).orderBy('display_name', descending: false).where('public', isEqualTo: true).startAt([value.toLowerCase()]).endAt(['${value.toLowerCase()}\uf8ff']).get().then((uSnaps) async {
                                          for (var uDoc in uSnaps.docs) {
                                            if (uDoc.reference.id != user!.uid) users.add(uDoc);
                                          }
                                        });
                                    if (users.isEmpty) {
                                      await FirebaseFirestore.instance.collection('users').orderBy('email', descending: false).where('public', isEqualTo: true).startAt([value.toLowerCase()]).endAt(['${value.toLowerCase()}\uf8ff']).get().then((uSnaps) async {
                                            for (var uDoc in uSnaps.docs) {
                                              if (uDoc.reference.id != user!.uid) users.add(uDoc);
                                            }
                                          });
                                    }

                                    await Future.delayed(const Duration(milliseconds: 500));

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
                                validator: (value) {
                                  if (value!.isEmpty) return 'Enter a name or email address';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // ── QR scan button ───────────────────────
                            Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  final auth = Provider.of<FirebaseAuth>(context, listen: false);
                                  final db = Provider.of<FirebaseFirestore>(context, listen: false);
                                  final barcodeScanRes = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const BarcodeScannerSimple(title: "Scan Friend's QR Code"),
                                    ),
                                  );
                                  addFriendBarcode(barcodeScanRes, auth, db).then((success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Theme.of(context).cardTheme.color,
                                        content: Text(
                                          "You are now friends!",
                                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                        ),
                                        duration: const Duration(milliseconds: 2500),
                                      ),
                                    );
                                    goToAppSection(context, AppSection.community, communitySection: CommunitySection.friends);
                                  }).onError((error, stackTrace) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Theme.of(context).cardTheme.color,
                                        content: Text(
                                          "There was an error scanning your friend's QR code :(",
                                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                        ),
                                        duration: const Duration(milliseconds: 4000),
                                      ),
                                    );
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 30,
                                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),

                  // ── Results ─────────────────────────────────────────
                  Expanded(child: _buildResultsArea()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_isSearching && _friends.isEmpty && searchFieldController.text.isNotEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    if (_friends.isEmpty && searchFieldController.text.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _card(children: [
            _sectionLabel("Can't find them?"),
            Text(
              "They may not have an account yet — challenge them to join!",
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  SharePlus.instance.share(ShareParams(
                    text: 'Take the How To Hockey 10,000 Shot Challenge!\nhttp://hyperurl.co/tenthousandshots',
                    subject: 'Take the How To Hockey 10,000 Shot Challenge!',
                  ));
                },
                icon: const Icon(Icons.share_rounded),
                label: Text('Share Challenge Link'.toUpperCase(), style: const TextStyle(fontFamily: 'NovecentoSans', fontSize: 16)),
              ),
            ),
          ]),
        ],
      );
    }

    if (_friends.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: _friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final UserProfile friend = UserProfile.fromSnapshot(_friends[i]);
        final bool selected = _selectedFriend == i;
        return GestureDetector(
          onTap: () {
            Feedback.forTap(context);
            FocusScope.of(context).unfocus();
            setState(() => _selectedFriend = selected ? null : i);
          },
          child: Card(
            elevation: 0,
            color: selected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Theme.of(context).cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: selected ? BorderSide(color: Theme.of(context).primaryColor, width: 1.5) : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar – tap to view profile
                  GestureDetector(
                    onTap: () {
                      Feedback.forTap(context);
                      showPlayerProfileSheet(context, _friends[i].id, initialUserProfile: friend);
                    },
                    child: ClipOval(
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: UserAvatar(user: friend, backgroundColor: Colors.transparent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (friend.displayName != null)
                          AutoSizeText(
                            friend.displayName!,
                            maxLines: 1,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
                          ),
                        StreamBuilder(
                          stream: FirebaseFirestore.instance.collection('iterations').doc(_friends[i].id).collection('iterations').snapshots(),
                          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(width: 80, height: 2, child: LinearProgressIndicator());
                            }
                            int total = 0;
                            Duration totalDuration = const Duration();
                            for (var doc in snapshot.data!.docs) {
                              final iter = Iteration.fromSnapshot(doc);
                              total += iter.total!;
                              totalDuration += iter.totalDuration!;
                            }
                            return Row(
                              children: [
                                Text(
                                  '$total Shots',
                                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6)),
                                ),
                                if (totalDuration > const Duration()) ...[
                                  Text('  ·  ', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3))),
                                  Text(
                                    printDuration(totalDuration, true),
                                    style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 15, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6)),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Selected indicator
                  if (selected) Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor, size: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
