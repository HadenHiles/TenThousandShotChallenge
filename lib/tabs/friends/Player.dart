import 'dart:async';
import 'package:tenthousandshotchallenge/widgets/ActivityCalendar.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/widgets/CrAvatarBadge.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatarCrPopover.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/widgets/UserStatsChipsRow.dart';

class Player extends StatefulWidget {
  const Player({super.key, this.uid});

  final String? uid;

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final user = FirebaseAuth.instance.currentUser;

  UserProfile? _userPlayer;
  bool _loadingPlayer = false;
  bool? _isFriend = false;
  bool _isSubscribedToFriendNotifications = false;
  List<DropdownMenuItem<dynamic>>? _attemptDropdownItems = [];
  String? _selectedIterationId;
  bool _isPlayersTeamPublic = false;
  String? _playerTeamName;

  @override
  void initState() {
    super.initState();

    setState(() {
      _loadingPlayer = true;
    });

    FirebaseFirestore.instance.collection('users').doc(widget.uid).get().then((uDoc) {
      _userPlayer = UserProfile.fromSnapshot(uDoc);
      _loadPlayerTeamVisibility();

      setState(() {
        _loadingPlayer = false;
      });
    });

    _loadIsFriend();
    _loadFriendSubscription();
    _getAttempts();
  }

  Future<void> _loadIsFriend() async {
    await FirebaseFirestore.instance.collection('teammates').doc(user!.uid).collection('teammates').doc(widget.uid).get().then((snapshot) {
      setState(() {
        _isFriend = snapshot.exists;
      });
    });
  }

  Future<void> _loadFriendSubscription() async {
    if (widget.uid == null || widget.uid == user!.uid) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('friend_subscriptions').doc(widget.uid).get();
    if (mounted) {
      setState(() {
        _isSubscribedToFriendNotifications = doc.exists;
      });
    }
  }

  Future<void> _toggleFriendSubscription() async {
    if (widget.uid == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('friend_subscriptions').doc(widget.uid);
    if (_isSubscribedToFriendNotifications) {
      await ref.delete();
    } else {
      await ref.set({'subscribed': true, 'subscribed_at': FieldValue.serverTimestamp()});
    }
    if (mounted) {
      setState(() {
        _isSubscribedToFriendNotifications = !_isSubscribedToFriendNotifications;
      });
    }
  }

  void _showFriendNotificationDialog() {
    if (_userPlayer == null) return;
    Feedback.forTap(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: Theme.of(ctx).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session Notifications',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get notified when ${_userPlayer!.notifName} finishes a shooting session.',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _isSubscribedToFriendNotifications,
                    activeColor: Theme.of(ctx).primaryColor,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isSubscribedToFriendNotifications ? 'Subscribed' : 'Not subscribed',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (v) async {
                      await _toggleFriendSubscription();
                      setDialogState(() {});
                    },
                  ),
                  if (_isSubscribedToFriendNotifications)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'You\'ll receive a push notification whenever they log a session.',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                  ),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadPlayerTeamVisibility() async {
    final teamId = _userPlayer?.teamId;
    if (teamId == null || teamId.isEmpty) {
      if (mounted) {
        setState(() {
          _isPlayersTeamPublic = false;
          _playerTeamName = null;
        });
      }
      return;
    }

    final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
    if (!mounted) return;
    if (!teamDoc.exists) {
      setState(() {
        _isPlayersTeamPublic = false;
        _playerTeamName = null;
      });
      return;
    }

    final data = teamDoc.data();
    setState(() {
      _isPlayersTeamPublic = data?['public'] == true;
      _playerTeamName = data?['name']?.toString();
    });
  }

  void _showInviteDialog() {
    if (_userPlayer == null || widget.uid == null) return;
    Feedback.forTap(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Invite ${_userPlayer!.notifName} to be your friend?",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Text(
            "They will receive an invite notification from you.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                inviteFriend(user!.uid, widget.uid!, Provider.of<FirebaseFirestore>(context, listen: false)).then((success) {
                  if (!mounted) return;
                  if (success == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Theme.of(context).cardTheme.color,
                        content: Text(
                          "${_userPlayer!.notifName} Invited!",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Theme.of(context).cardTheme.color,
                        content: Text(
                          "Failed to invite ${_userPlayer!.notifName} :(",
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
              child: Text(
                "Invite",
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveFriendDialog() {
    if (_userPlayer == null) return;
    Feedback.forTap(context);
    dialog(
      context,
      ConfirmDialog(
        "Remove Friend?",
        Text(
          "Are you sure you want to unfriend ${_userPlayer!.notifName}?",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        "Cancel",
        () {
          Navigator.of(context).pop();
        },
        "Continue",
        () {
          goToAppSection(
            context,
            AppSection.community,
            communitySection: CommunitySection.friends,
          );

          removePlayerFromFriends(
            _userPlayer!.reference!.id,
            Provider.of<FirebaseAuth>(context, listen: false),
            Provider.of<FirebaseFirestore>(context, listen: false),
          ).then((success) {
            if (!mounted) return;
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).cardTheme.color,
                  duration: const Duration(milliseconds: 2500),
                  content: Text(
                    '${_userPlayer!.notifName} was removed.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).cardTheme.color,
                  duration: const Duration(milliseconds: 4000),
                  content: Text(
                    'Error removing Player :(',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              );
              Navigator.of(context).pop();
            }
          });
        },
      ),
    );
  }

  List<UserAvatarPopoverAction> _buildPlayerPopoverActions() {
    final actions = <UserAvatarPopoverAction>[];
    final viewingOtherUser = widget.uid != null && widget.uid != user!.uid;
    if (!viewingOtherUser || widget.uid == null) return actions;

    actions.add(
      UserAvatarPopoverAction(
        label: 'Compare Stats',
        icon: Icons.compare_arrows_rounded,
        onTap: () {
          Feedback.forTap(context);
          context.push(AppRoutePaths.compareStatsPathFor(widget.uid!));
        },
      ),
    );

    if (_isFriend == true) {
      actions.add(
        UserAvatarPopoverAction(
          label: 'Remove Friend',
          icon: Icons.person_remove_rounded,
          onTap: _showRemoveFriendDialog,
        ),
      );
    } else {
      actions.add(
        UserAvatarPopoverAction(
          label: 'Add Friend',
          icon: Icons.person_add_alt_1_rounded,
          onTap: _showInviteDialog,
        ),
      );
    }

    if (_isPlayersTeamPublic) {
      actions.add(
        UserAvatarPopoverAction(
          label: _playerTeamName == null || _playerTeamName!.isEmpty ? 'View Team' : 'View Team (${_playerTeamName!})',
          icon: Icons.groups_rounded,
          onTap: () {
            Feedback.forTap(context);
            context.push(AppRoutePaths.joinTeam);
          },
        ),
      );
    }

    return actions;
  }

  Future<void> _getAttempts() async {
    await FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').orderBy('start_date', descending: false).get().then((snapshot) {
      List<DropdownMenuItem> iterations = [];
      snapshot.docs.asMap().forEach((i, iDoc) {
        iterations.add(DropdownMenuItem<String>(
          value: iDoc.reference.id,
          child: Text(
            "challenge ".toLowerCase() + (i + 1).toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 26,
              fontFamily: 'NovecentoSans',
            ),
          ),
        ));
      });

      setState(() {
        if (iterations.isNotEmpty) {
          _selectedIterationId = iterations[iterations.length - 1].value;
        }
        _attemptDropdownItems = iterations;
      });
    });
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
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 28,
                      ),
                      onPressed: () {
                        context.pop();
                      },
                    ),
                  ),
                  actions: [
                    if (widget.uid != null && widget.uid != user!.uid && _isFriend == true)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: IconButton(
                          tooltip: _isSubscribedToFriendNotifications ? 'Session notifications on' : 'Get session notifications',
                          icon: Icon(
                            _isSubscribedToFriendNotifications ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                            color: _isSubscribedToFriendNotifications ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onPrimary,
                            size: 26,
                          ),
                          onPressed: _showFriendNotificationDialog,
                        ),
                      ),
                    if (widget.uid != null && widget.uid != user!.uid)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: IconButton(
                          tooltip: 'Compare stats',
                          icon: Icon(
                            Icons.compare_arrows_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 26,
                          ),
                          onPressed: () {
                            Feedback.forTap(context);
                            context.push(AppRoutePaths.compareStatsPathFor(widget.uid!));
                          },
                        ),
                      ),
                    !_isFriend!
                        ? widget.uid == user!.uid
                            ? const SizedBox()
                            : Container(
                                margin: const EdgeInsets.only(top: 10),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Feedback.forTap(context);

                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text(
                                            "Invite ${_userPlayer!.notifName} to be your friend?",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontSize: 20,
                                            ),
                                          ),
                                          backgroundColor: Theme.of(context).colorScheme.surface,
                                          content: Text(
                                            "They will receive an invite notification from you.",
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                Navigator.of(context).pop();
                                                inviteFriend(user!.uid, widget.uid!, Provider.of<FirebaseFirestore>(context, listen: false)).then((success) {
                                                  if (success!) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor: Theme.of(context).cardTheme.color,
                                                        content: Text(
                                                          "${_userPlayer!.notifName} Invited!",
                                                          style: TextStyle(
                                                            color: Theme.of(context).colorScheme.onPrimary,
                                                          ),
                                                        ),
                                                        duration: const Duration(seconds: 4),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor: Theme.of(context).cardTheme.color,
                                                        content: Text(
                                                          "Failed to invite ${_userPlayer!.notifName} :(",
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
                                              child: Text(
                                                "Invite",
                                                style: TextStyle(color: Theme.of(context).primaryColor),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              )
                        : widget.uid == user!.uid
                            ? const SizedBox()
                            : Container(
                                margin: const EdgeInsets.only(top: 10),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Theme.of(context).primaryColor,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Feedback.forTap(context);
                                    dialog(
                                      context,
                                      ConfirmDialog(
                                        "Remove Friend?",
                                        Text(
                                          "Are you sure you want to unfriend ${_userPlayer!.notifName}?",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        "Cancel",
                                        () {
                                          Navigator.of(context).pop();
                                        },
                                        "Continue",
                                        () {
                                          // Use go_router for navigation instead of pushReplacement
                                          goToAppSection(
                                            context,
                                            AppSection.community,
                                            communitySection: CommunitySection.friends,
                                          );

                                          removePlayerFromFriends(
                                            _userPlayer!.reference!.id,
                                            Provider.of<FirebaseAuth>(context, listen: false),
                                            Provider.of<FirebaseFirestore>(context, listen: false),
                                          ).then((success) {
                                            if (success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Theme.of(context).cardTheme.color,
                                                  duration: const Duration(milliseconds: 2500),
                                                  content: Text(
                                                    '${_userPlayer!.notifName} was removed.',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: Theme.of(context).cardTheme.color,
                                                  duration: const Duration(milliseconds: 4000),
                                                  content: Text(
                                                    'Error removing Player :(',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              );

                                              Navigator.of(context).pop();
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ],
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      background: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: _loadingPlayer
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: CircularProgressIndicator(),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPlayerHeader(context),
                        const SizedBox(height: 8),
                        _buildProgressCard(context),
                        const SizedBox(height: 12),
                        _buildStatsChips(context),
                        const SizedBox(height: 12),
                        _buildAchievementsCard(context),
                        const SizedBox(height: 12),
                        _buildAccuracyCard(context),
                        const SizedBox(height: 12),
                        _buildActivityCalendarCard(context),
                        const SizedBox(height: 12),
                        _buildSessionsCard(context),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildCrHeaderSummary(BuildContext context) {
    if (widget.uid == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<ChallengerRoadUserSummary>(
      stream: ChallengerRoadService().watchUserSummary(widget.uid!),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final summary = snap.data!;
        final bool hasActivity = summary.totalAttempts > 0 || summary.badges.isNotEmpty;
        if (!hasActivity) return const SizedBox.shrink();

        final badges = summary.badges.toSet();
        final bool roadComplete = badges.contains('the_general') || badges.contains('playoff_mode');
        final int? shots = summary.allTimeBestLevelShots;
        String headline;
        if (roadComplete) {
          if (shots != null && shots == 10000) {
            headline = 'road complete - exactly\n10,000 shots';
          } else if (shots != null) {
            headline = 'road complete -\n${_fmtShots(shots)} shots';
          } else {
            headline = 'road complete!';
          }
        } else if (summary.allTimeBestLevel > 0) {
          final t = summary.totalAttempts;
          headline = 'level ${summary.allTimeBestLevel}\n$t attempt${t == 1 ? '' : 's'}';
        } else {
          headline = '${summary.badges.length} badge${summary.badges.length == 1 ? '' : 's'} earned';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_rounded, size: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                const SizedBox(width: 4),
                Text(
                  'CHALLENGER ROAD',
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              headline,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 15,
                color: roadComplete ? const Color(0xFFFFD700) : theme.colorScheme.onSurface,
                shadows: roadComplete ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 6)] : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isProForDisplay = _userPlayer?.isPro == true;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              width: 60,
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: UserAvatarCrPopover(
                        userId: widget.uid ?? '',
                        menuColor: theme.colorScheme.primary,
                        showAccomplishment: isProForDisplay,
                        showProFallback: isProForDisplay,
                        extraActions: _buildPlayerPopoverActions(),
                        child: UserAvatar(
                          user: _userPlayer,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: CrAvatarBadgeStream(
                      userId: widget.uid!,
                      size: 22,
                      enabled: isProForDisplay,
                      showProFallback: isProForDisplay,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 130) * 0.55,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                    builder: (context, snapshot) {
                      String name = _userPlayer?.displayName ?? 'Player';
                      if (snapshot.hasData) {
                        final p = UserProfile.fromSnapshot(snapshot.data as DocumentSnapshot);
                        if (p.displayName?.isNotEmpty == true) name = p.displayName!;
                      }
                      return AutoSizeText(name, maxLines: 1, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge!.color));
                    },
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(width: 120, height: 2, child: LinearProgressIndicator());
                    int total = 0;
                    for (final doc in snapshot.data!.docs) {
                      total += Iteration.fromSnapshot(doc).total!;
                    }
                    return Text('$total lifetime shots', style: TextStyle(fontSize: 16, fontFamily: 'NovecentoSans', color: theme.colorScheme.onPrimary));
                  },
                ),
              ],
            ),
          ],
        ),
        _buildCrHeaderSummary(context),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final theme = Theme.of(context);
    if (_selectedIterationId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').doc(_selectedIterationId).snapshots(),
      builder: (context, iterSnap) {
        if (!iterSnap.hasData || !iterSnap.data!.exists) {
          return Container(height: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: theme.cardTheme.color), child: const Center(child: CircularProgressIndicator()));
        }

        final iteration = Iteration.fromSnapshot(iterSnap.data!);
        final int iterTotal = (iteration.total ?? 0).clamp(0, 10000);
        final double progress = iterTotal / 10000.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [theme.colorScheme.primaryContainer.withValues(alpha: 0.94), theme.colorScheme.primary.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(iterTotal.toString(), style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 36, color: theme.colorScheme.onPrimary, height: 1.0)),
                      Text('/ 10,000 shots', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 16, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7))),
                    ],
                  ),
                  if (_attemptDropdownItems != null && _attemptDropdownItems!.length > 1)
                    DropdownButton<dynamic>(
                      value: _selectedIterationId,
                      items: _attemptDropdownItems,
                      dropdownColor: theme.colorScheme.primary,
                      underline: const SizedBox.shrink(),
                      onChanged: (v) => setState(() => _selectedIterationId = v),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildProgressBar(context, iteration, progress),
              const SizedBox(height: 10),
              _buildShotTypeRow(context, iteration),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, Iteration iteration, double progress) {
    final theme = Theme.of(context);
    final total = iteration.total ?? 0;
    return LayoutBuilder(builder: (context, constraints) {
      final barWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
      final seg = total == 0 ? 1.0 : total.toDouble();
      Widget seg_(int count, Color color) => Container(height: 8, width: count > 0 ? (count / seg) * barWidth : 0, color: color);
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(children: [
          Container(height: 8, width: constraints.maxWidth, color: theme.colorScheme.onPrimary.withValues(alpha: 0.12)),
          Row(children: [
            seg_(iteration.totalWrist ?? 0, wristShotColor),
            seg_(iteration.totalSnap ?? 0, snapShotColor),
            seg_(iteration.totalBackhand ?? 0, backhandShotColor),
            seg_(iteration.totalSlap ?? 0, slapShotColor),
          ]),
        ]),
      );
    });
  }

  Widget _buildShotTypeRow(BuildContext context, Iteration iteration) {
    final types = [
      ('Wrist', iteration.totalWrist ?? 0, wristShotColor),
      ('Snap', iteration.totalSnap ?? 0, snapShotColor),
      ('Backhand', iteration.totalBackhand ?? 0, backhandShotColor),
      ('Slap', iteration.totalSlap ?? 0, slapShotColor),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: types.map((t) {
        final (label, count, color) = t;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 14, fontFamily: 'NovecentoSans')),
          const SizedBox(height: 2),
          Container(width: 28, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 2),
          Text(count.toString(), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontFamily: 'NovecentoSans')),
        ]);
      }).toList(),
    );
  }

  Widget _buildStatsChips(BuildContext context) {
    return UserStatsChipsRow(userId: widget.uid!, showAchievementChips: false);
  }

  Widget _buildAchievementsCard(BuildContext context) {
    final theme = Theme.of(context);
    return _PlayerDashboardCard(
      onTap: () => context.push(
        AppRoutePaths.playerAchievementsPathFor(widget.uid!),
        extra: {'playerName': _userPlayer?.displayName ?? ''},
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text('Achievements'.toUpperCase(), style: theme.textTheme.headlineSmall)),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onPrimary.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }

  Widget _buildAccuracyCard(BuildContext context) {
    final theme = Theme.of(context);
    final playerIsPro = _userPlayer?.isPro ?? false;
    final playerName = _userPlayer?.notifName ?? 'This player';

    Widget cardContent = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.track_changes_rounded, color: theme.colorScheme.onPrimary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shot Accuracy'.toUpperCase(), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            _buildAccuracyGlanceChips(context),
          ]),
        ),
      ]),
    );

    if (!playerIsPro) {
      cardContent = Stack(
        children: [
          // Blurred / dimmed content underneath
          Opacity(opacity: 0.25, child: cardContent),
          // Lock overlay
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 28, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(height: 6),
                  Text(
                    "$playerName doesn't have pro access",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _PlayerDashboardCard(child: cardContent);
  }

  Widget _buildAccuracyGlanceChips(BuildContext context) {
    const shotTypes = ['wrist', 'snap', 'slap', 'backhand'];
    const shotTypeColors = {'wrist': wristShotColor, 'snap': snapShotColor, 'slap': slapShotColor, 'backhand': backhandShotColor};
    const shotTypeLabels = {'wrist': 'W', 'snap': 'SN', 'slap': 'SL', 'backhand': 'B'};

    if (_selectedIterationId == null) {
      return Row(children: shotTypes.map((t) => _accuracyChip(context, shotTypeLabels[t]!, 0, shotTypeColors[t]!, loading: true)).toList());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Row(children: shotTypes.map((t) => _accuracyChip(context, shotTypeLabels[t]!, 0, shotTypeColors[t]!, loading: true)).toList());
        }
        return FutureBuilder<Map<String, double>>(
          future: _computeAvgAccuracy(snap.data!.docs, shotTypes),
          builder: (context, asyncSnap) {
            final acc = asyncSnap.data ?? {for (var t in shotTypes) t: 0.0};
            return Row(children: shotTypes.map((type) => _accuracyChip(context, shotTypeLabels[type]!, acc[type] ?? 0, shotTypeColors[type]!)).toList());
          },
        );
      },
    );
  }

  Widget _accuracyChip(BuildContext context, String label, double pct, Color color, {bool loading = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'NovecentoSans', fontWeight: FontWeight.bold, fontSize: 12)),
        Stack(alignment: Alignment.center, children: [
          Container(width: 32, height: 26, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) else Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontFamily: 'NovecentoSans', fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ]),
    );
  }

  Future<Map<String, double>> _computeAvgAccuracy(List<QueryDocumentSnapshot> sessionDocs, List<String> shotTypes) async {
    final totalHits = {for (var t in shotTypes) t: 0};
    final totalShots = {for (var t in shotTypes) t: 0};
    for (final doc in sessionDocs) {
      try {
        final shotsSnap = await doc.reference.collection('shots').get();
        for (final shotDoc in shotsSnap.docs) {
          final shot = Shots.fromSnapshot(shotDoc);
          if (shot.type != null && shotTypes.contains(shot.type) && shot.targetsHit != null && shot.count != null && shot.count! > 0) {
            totalHits[shot.type!] = (totalHits[shot.type!] ?? 0) + (shot.targetsHit as num).toInt();
            totalShots[shot.type!] = (totalShots[shot.type!] ?? 0) + (shot.count as num).toInt();
          }
        }
      } catch (_) {}
    }
    return {for (var t in shotTypes) t: totalShots[t]! > 0 ? (totalHits[t]! / totalShots[t]!) * 100.0 : 0.0};
  }

  Widget _buildActivityCalendarCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.onPrimary, size: 24),
              ),
              const SizedBox(width: 14),
              Text('Training Activity'.toUpperCase(), style: theme.textTheme.headlineSmall),
            ]),
            const SizedBox(height: 10),
            ActivityCalendar(userId: widget.uid!),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsCard(BuildContext context) {
    final theme = Theme.of(context);
    return _PlayerDashboardCard(
      onTap: () => context.push(
        AppRoutePaths.playerSessionsPathFor(widget.uid!),
        extra: {'playerName': _userPlayer?.displayName ?? '', 'iterationId': _selectedIterationId},
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.history_rounded, color: theme.colorScheme.onPrimary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sessions'.toUpperCase(), style: theme.textTheme.headlineSmall),
              if (_selectedIterationId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('iterations').doc(widget.uid).collection('iterations').doc(_selectedIterationId).collection('sessions').orderBy('date', descending: true).limit(1).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Text('No sessions yet', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.6)));
                    }
                    final last = ShootingSession.fromSnapshot(snap.data!.docs.first);
                    return Text(
                      'Last: ${printDate(last.date!)}  ·  ${last.total} shots',
                      style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 14, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
                    );
                  },
                ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onPrimary.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}

// ── Shared dashboard card widget ─────────────────────────────────────────────

class _PlayerDashboardCard extends StatelessWidget {
  const _PlayerDashboardCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }
}

String _fmtShots(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
