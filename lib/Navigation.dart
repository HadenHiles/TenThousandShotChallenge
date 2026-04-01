import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/VersionCheck.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/session.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/Community.dart';
import 'package:tenthousandshotchallenge/tabs/Explore.dart';
import 'package:tenthousandshotchallenge/tabs/Shots.dart';
import 'package:tenthousandshotchallenge/tabs/Profile.dart';
import 'package:tenthousandshotchallenge/tabs/profile/QR.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/tabs/shots/StartShooting.dart';
import 'package:tenthousandshotchallenge/tabs/shots/challenger_road/StartChallengeScreen.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/NavigationTab.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/MobileScanner/barcode_scanner_simple.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'models/Preferences.dart';

final PanelController sessionPanelController = PanelController();

/// Configuration for an active challenge session shown in the sliding panel.
/// Set to non-null to activate challenge mode; null = normal shooting.
class ChallengeSessionConfig {
  final ChallengerRoadChallenge challenge;
  final ChallengerRoadLevel levelDoc;
  final ChallengerRoadAttempt attempt;
  final String userId;
  final DateTime startedAt;
  final VoidCallback? onSessionComplete;
  final bool isPreviewMode;
  final int previewMaxLevel;
  final VoidCallback? onPreviewLevelUnlockAttempted;

  const ChallengeSessionConfig({
    required this.challenge,
    required this.levelDoc,
    required this.attempt,
    required this.userId,
    required this.startedAt,
    this.onSessionComplete,
    this.isPreviewMode = false,
    this.previewMaxLevel = 1,
    this.onPreviewLevelUnlockAttempted,
  });
}

/// Active challenge session; non-null activates challenge mode in the panel.
final ValueNotifier<ChallengeSessionConfig?> activeChallengeSession = ValueNotifier(null);

// This is the stateful widget that the main application instantiates.
class Navigation extends StatefulWidget {
  const Navigation({super.key, this.selectedIndex, this.tabId, this.communitySection, this.actions});

  final int? selectedIndex;
  final String? tabId;
  final String? communitySection;
  final List<Widget>? actions;

  @override
  State<Navigation> createState() => _NavigationState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _NavigationState extends State<Navigation> {
  final ValueNotifier<CommunitySection> _communitySectionNotifier = ValueNotifier(CommunitySection.friends);

  // Update last_seen in Firestore if not already set to today
  Future<void> updateLastSeenIfNeeded(BuildContext context) async {
    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;
    final docRef = firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (doc.exists) {
      final lastSeen = doc.data()?['last_seen'];
      if (lastSeen != null) {
        DateTime lastSeenDate;
        if (lastSeen is Timestamp) {
          lastSeenDate = lastSeen.toDate();
        } else if (lastSeen is DateTime) {
          lastSeenDate = lastSeen;
        } else {
          lastSeenDate = DateTime.tryParse(lastSeen.toString()) ?? DateTime(2000);
        }
        final lastSeenDay = DateTime(lastSeenDate.year, lastSeenDate.month, lastSeenDate.day);
        if (lastSeenDay == today) {
          return; // Already updated today
        }
      }
    }
    await docRef.update({'last_seen': now}).catchError((_) async {
      // If doc doesn't exist, create it
      await docRef.set({'last_seen': now}, SetOptions(merge: true));
    });
  }

  // State variables
  Widget? _leading;
  List<Widget>? _actions;
  int _selectedIndex = 0;
  final ValueNotifier<int> _trainResetSignal = ValueNotifier<int>(0);
  // State variables
  PanelState _sessionPanelState = PanelState.CLOSED;
  double _bottomNavOffsetPercentage = 0;
  Team? team;
  UserProfile? userProfile;
  bool _startTabHasChallengerRoadAccess = false;
  bool _startHeaderVisibleForRoad = true;

  // Remove the field initializer for _tabs
  late List<NavigationTab> _tabs;

  // Add this method to handle the Team QR code join logic
  Future<void> _handleJoinTeamQRCode(BuildContext context) async {
    await showTeamQRCode(context).then((hasTeam) async {
      if (!hasTeam) {
        final barcodeScanRes = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BarcodeScannerSimple(title: "Scan Team QR Code"),
          ),
        );

        joinTeam(
          barcodeScanRes,
          Provider.of<FirebaseAuth>(context, listen: false),
          Provider.of<FirebaseFirestore>(context, listen: false),
        ).then((success) {
          if (success == true && mounted) {
            _communitySectionNotifier.value = CommunitySection.team;
            setState(() {
              _selectedIndex = 1;
              _leading = _tabs[1].leading;
              _actions = widget.actions ?? _tabs[1].actions;
            });
          }
        });
      }
    });
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _onChallengeSessionChanged() {
    if (mounted) setState(() {});
  }

  void _onChallengerRoadAvailabilityChanged(bool hasAccess) {
    if (!mounted) return;
    setState(() {
      _startTabHasChallengerRoadAccess = hasAccess;
      if (!hasAccess) {
        // Ensure header is visible when Road mode is not active.
        _startHeaderVisibleForRoad = true;
      }
    });
  }

  void _onMainHeaderVisibilityChanged(bool visible) {
    if (!mounted || _startHeaderVisibleForRoad == visible) return;
    setState(() => _startHeaderVisibleForRoad = visible);
  }

  CommunitySection _normalizeCommunitySection(String? rawSection) {
    return rawSection == CommunitySection.team.name ? CommunitySection.team : CommunitySection.friends;
  }

  void _onCommunitySectionChanged(CommunitySection section) {
    if (_communitySectionNotifier.value == section) return;
    _communitySectionNotifier.value = section;
    if (mounted) {
      setState(() {
        _actions = _selectedIndex == 1 ? _buildCommunityActions(context) : _actions;
      });
    }
  }

  Widget _buildCommunityTitle(BuildContext context) {
    if (_communitySectionNotifier.value == CommunitySection.friends) {
      return NavigationTitle(title: 'Friends');
    }

    final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (user == null) {
      return NavigationTitle(title: 'Team');
    }

    final userProfileStream = Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(user.uid).snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userProfileStream,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return NavigationTitle(title: 'Team');
        }
        final userProfile = userSnapshot.data!.data();
        final teamId = userProfile != null ? userProfile['team_id'] as String? : null;
        if (teamId == null || teamId.isEmpty) {
          return NavigationTitle(title: 'Team');
        }
        final teamStream = Provider.of<FirebaseFirestore>(context, listen: false).collection('teams').doc(teamId).snapshots();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: teamStream,
          builder: (context, teamSnapshot) {
            if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
              return NavigationTitle(title: 'Team');
            }
            final teamData = teamSnapshot.data!.data();
            final teamName = teamData != null && teamData['name'] != null ? teamData['name'] as String : 'Team';
            return NavigationTitle(title: teamName);
          },
        );
      },
    );
  }

  List<Widget> _buildCommunityActions(BuildContext context) {
    if (_communitySectionNotifier.value == CommunitySection.friends) {
      return [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: Icon(
              Icons.add,
              color: HomeTheme.darkTheme.colorScheme.onPrimary,
              size: 28,
            ),
            onPressed: () => context.push(AppRoutePaths.addFriend),
          ),
        ),
      ];
    }

    return _buildDynamicTeamActions(context);
  }

  Widget _buildAnimatedRoadDrivenMainHeader(BuildContext context) {
    final isVisible = _startHeaderVisibleForRoad;
    final actions = _tabs[_selectedIndex].id == 'community' ? _buildCommunityActions(context) : _actions;
    final topInset = MediaQuery.of(context).padding.top;
    const toolbarHeight = 85.0;
    final visibleHeight = topInset + toolbarHeight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      height: isVisible ? visibleHeight : 0,
      color: isVisible ? HomeTheme.darkTheme.colorScheme.primaryContainer : HomeTheme.darkTheme.colorScheme.primaryContainer.withOpacity(0),
      child: ClipRect(
        child: IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, -0.2),
              duration: const Duration(milliseconds: 360),
              curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
              child: AppBar(
                primary: true,
                toolbarHeight: toolbarHeight,
                automaticallyImplyLeading: [3].contains(_selectedIndex) ? true : false,
                backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                iconTheme: Theme.of(context).iconTheme,
                actionsIconTheme: Theme.of(context).iconTheme,
                centerTitle: true,
                elevation: 0,
                title: _tabs[_selectedIndex].title ??
                    const SizedBox(
                      height: 15,
                    ),
                leading: _leading,
                actions: actions,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    sessionService.addListener(_onSessionChanged);
    activeChallengeSession.addListener(_onChallengeSessionChanged);
    _communitySectionNotifier.value = _normalizeCommunitySection(widget.communitySection);
    try {
      versionCheck(context);
    } catch (e) {
      print(e);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateLastSeenIfNeeded(context);
    });

    _loadPreferences();

    _tabs = [
      NavigationTab(
        id: 'train',
        title: Container(
          height: 40,
          padding: const EdgeInsets.only(top: 6),
          child: Image.asset('assets/images/logo-text-only.png'), // Use the correct logo asset
        ),
        actions: const [],
        body: ValueListenableBuilder<int>(
          valueListenable: _trainResetSignal,
          builder: (context, resetSignal, _) => Shots(
            sessionPanelController: sessionPanelController,
            resetSignal: resetSignal,
            onChallengerRoadAvailabilityChanged: _onChallengerRoadAvailabilityChanged,
            onMainHeaderVisibilityChanged: _onMainHeaderVisibilityChanged,
          ),
        ),
      ),
      NavigationTab(
        id: 'community',
        title: Builder(
          builder: (context) => ValueListenableBuilder<CommunitySection>(
            valueListenable: _communitySectionNotifier,
            builder: (context, _, __) => _buildCommunityTitle(context),
          ),
        ),
        actions: const [],
        body: ValueListenableBuilder<CommunitySection>(
          valueListenable: _communitySectionNotifier,
          builder: (context, section, _) => Community(
            selectedSection: section,
            onSectionChanged: _onCommunitySectionChanged,
          ),
        ),
      ),
      NavigationTab(
        id: 'learn',
        title: null,
        body: const Explore(),
      ),
      NavigationTab(
        id: 'me',
        title: NavigationTitle(title: "Me".toUpperCase()),
        leading: Container(
          margin: const EdgeInsets.only(top: 10),
          child: Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.qr_code_2_rounded,
                color: HomeTheme.darkTheme.colorScheme.onPrimary,
                size: 28,
              ),
              onPressed: () {
                final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
                showQRCode(context, user);
              },
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            child: Builder(
              builder: (context) => IconButton(
                icon: Icon(
                  Icons.settings,
                  color: HomeTheme.darkTheme.colorScheme.onPrimary,
                  size: 28,
                ),
                onPressed: () {
                  context.push(AppRoutePaths.settings);
                },
              ),
            ),
          ),
        ],
        body: const Profile(),
      ),
    ];

    int initialIndex = 0;
    if (widget.tabId != null) {
      final normalized = _normalizeTabId(widget.tabId);
      final idx = _tabs.indexWhere((tab) => tab.id == normalized);
      if (idx != -1) initialIndex = idx;
    } else if (widget.selectedIndex != null) {
      initialIndex = widget.selectedIndex!;
    }

    setState(() {
      _leading = Container();
      _actions = widget.actions ?? _tabs[initialIndex].actions;
      _selectedIndex = initialIndex;
    });

    _onItemTapped(initialIndex);

    super.initState();
  }

  @override
  void didUpdateWidget(covariant Navigation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.communitySection != widget.communitySection) {
      final nextSection = _normalizeCommunitySection(widget.communitySection);
      _communitySectionNotifier.value = nextSection;
      if (_selectedIndex == 1) {
        setState(() {
          _actions = _buildCommunityActions(context);
        });
      }
    }
  }

  @override
  void dispose() {
    sessionService.removeListener(_onSessionChanged);
    activeChallengeSession.removeListener(_onChallengeSessionChanged);
    _communitySectionNotifier.dispose();
    _trainResetSignal.dispose();
    super.dispose();
  }

  // Helper to select a tab by id
  void selectTabById(String id) {
    final normalized = _normalizeTabId(id);
    final index = _tabs.indexWhere((tab) => tab.id == normalized);
    if (index != -1) {
      _onItemTapped(index);
    }
  }

  String _normalizeTabId(String? rawId) {
    switch (rawId) {
      case 'start':
      case 'train':
        return 'train';
      case 'friends':
      case 'team':
      case 'community':
        return 'community';
      case 'explore':
      case 'learn':
        return 'learn';
      case 'profile':
      case 'me':
        return 'me';
      default:
        return 'train';
    }
  }

  void _onItemTapped(int index) async {
    final isTrainTab = _tabs[index].id == 'train';
    if (isTrainTab) {
      // Always reset inline Challenger Road when user navigates to/reselects Train.
      _trainResetSignal.value++;
    }

    if (_tabs[index].id == 'community') {
      // Legacy manual load retained for other side-effects; actions now stream-driven.
      _loadTeam();
    }
    setState(() {
      _selectedIndex = index;
      _leading = _tabs[index].leading;
      _actions = widget.actions ?? (_tabs[index].id == 'community' ? _buildCommunityActions(context) : _tabs[index].actions);
    });
    if (sessionPanelController.isAttached) {
      if (!sessionPanelController.isPanelClosed) {
        sessionPanelController.close();
        setState(() {
          _sessionPanelState = PanelState.CLOSED;
        });
      }
    }
  }

  // ── Challenge session panel header ────────────────────────────────────────

  Future<void> _confirmCloseChallengeSession() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End challenge session?'),
        content: const Text(
          'This will discard your current in-progress challenge session. You can still collapse the panel with the arrow icon.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onSurface,
              backgroundColor: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep session'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End session', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      activeChallengeSession.value = null;
      sessionPanelController.close();
    }
  }

  Widget _buildChallengeSessionHeader(ChallengeSessionConfig config) {
    return Material(
      color: Theme.of(context).primaryColor,
      child: InkWell(
        onTap: () {
          if (sessionPanelController.isPanelClosed) {
            sessionPanelController.open();
          } else {
            sessionPanelController.close();
          }
        },
        child: SizedBox(
          height: 74,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.sports_hockey, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        config.challenge.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'NovecentoSans',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'LEVEL ${config.levelDoc.level}  •  CHALLENGE IN PROGRESS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontFamily: 'NovecentoSans',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                  initialData: 0,
                  builder: (context, _) {
                    final elapsed = DateTime.now().difference(config.startedAt);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 56,
                            child: Text(
                              printDuration(elapsed, true),
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'NovecentoSans',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // Cancel challenge session
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _confirmCloseChallengeSession,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
                // Collapse/expand panel
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (sessionPanelController.isPanelClosed) {
                      sessionPanelController.open();
                    } else {
                      sessionPanelController.close();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _sessionPanelState == PanelState.CLOSED ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to get FirebaseFirestore from Provider
  FirebaseFirestore getFirestore(BuildContext context) => Provider.of<FirebaseFirestore>(context, listen: false);
  FirebaseAuth getAuth(BuildContext context) => Provider.of<FirebaseAuth>(context, listen: false);

  // Load shared preferences
  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool darkMode = prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark;
    int puckCount = prefs.getInt('puck_count') ?? 25;
    bool friendNotifications = prefs.getBool('friend_notifications') ?? true;
    DateTime targetDate = prefs.getString('target_date') != null ? DateTime.parse(prefs.getString('target_date')!) : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100);
    String fcmToken = prefs.getString('fcm_token') ?? '';

    final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (user != null && preferences!.fcmToken != fcmToken) {
      await getFirestore(context).collection('users').doc(user.uid).update({'fcm_token': fcmToken}).then((_) => null);
    }

    preferences = Preferences(darkMode, puckCount, friendNotifications, targetDate, fcmToken);
    if (mounted) {
      Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(preferences);
    }
  }

  Future<Null> _loadTeam() async {
    final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    await getFirestore(context).collection('users').doc(user?.uid).get().then((uDoc) async {
      if (uDoc.exists) {
        UserProfile userProfile = UserProfile.fromSnapshot(uDoc);

        if (userProfile.teamId != null) {
          await getFirestore(context).collection('teams').doc(userProfile.teamId).get().then((tSnap) async {
            if (tSnap.exists) {
              Team t = Team.fromSnapshot(tSnap);

              setState(() {
                team = t; // Title handled by existing StreamBuilder; actions now dynamic.
              });
            }
          });
        }
      }
    });
  }

  // Dynamically build Team tab actions using live streams so UI reflects membership/ownership changes immediately.
  List<Widget> _buildDynamicTeamActions(BuildContext context) {
    final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    if (user == null) {
      return [];
    }
    final userDocStream = Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(user.uid).snapshots();
    return [
      // Wrap in Builder so each rebuild scope is isolated
      Builder(
        builder: (context) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userDocStream,
            builder: (context, userSnap) {
              if (!userSnap.hasData || !userSnap.data!.exists) {
                return const SizedBox();
              }
              final data = userSnap.data!.data();
              final teamId = data != null ? data['team_id'] as String? : null;
              if (teamId == null || teamId.isEmpty) {
                // No team: show QR code join action only
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: IconButton(
                    icon: Icon(
                      Icons.qr_code_2_rounded,
                      color: HomeTheme.darkTheme.colorScheme.onPrimary,
                      size: 28,
                    ),
                    onPressed: () => _handleJoinTeamQRCode(context),
                  ),
                );
              }
              final teamStream = Provider.of<FirebaseFirestore>(context, listen: false).collection('teams').doc(teamId).snapshots();
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: teamStream,
                builder: (context, teamSnap) {
                  if (!teamSnap.hasData || !teamSnap.data!.exists) {
                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_2_rounded,
                          color: HomeTheme.darkTheme.colorScheme.onPrimary,
                          size: 28,
                        ),
                        onPressed: () => _handleJoinTeamQRCode(context),
                      ),
                    );
                  }
                  final teamData = teamSnap.data!.data();
                  final ownerId = teamData != null ? teamData['owner_id'] as String? : null;
                  final isOwner = ownerId == user.uid;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOwner)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          child: IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: HomeTheme.darkTheme.colorScheme.onPrimary,
                              size: 28,
                            ),
                            onPressed: () => context.push(AppRoutePaths.editTeam),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: IconButton(
                          icon: Icon(
                            Icons.qr_code_2_rounded,
                            color: HomeTheme.darkTheme.colorScheme.onPrimary,
                            size: 28,
                          ),
                          onPressed: () => _handleJoinTeamQRCode(context),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Require NetworkStatusService to be provided via Provider (no fallback)
    final networkStatusService = Provider.of<NetworkStatusService>(context, listen: false);

    return SessionServiceProvider(
      service: sessionService,
      child: Scaffold(
        body: SlidingUpPanel(
          backdropEnabled: true,
          controller: sessionPanelController,
          maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
          minHeight: sessionService.isRunning || activeChallengeSession.value != null ? 65 : 0,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          onPanelOpened: () {
            sessionService.resume();
            setState(() {
              _sessionPanelState = PanelState.OPEN;
            });
          },
          onPanelClosed: () {
            sessionService.pause();
            setState(() {
              _sessionPanelState = PanelState.CLOSED;
            });
          },
          onPanelSlide: (double offset) {
            setState(() {
              _bottomNavOffsetPercentage = offset;
            });
          },
          panel: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                // Panel header — switches between challenge mode and normal shooting.
                activeChallengeSession.value != null
                    ? _buildChallengeSessionHeader(activeChallengeSession.value!)
                    : AnimatedBuilder(
                        animation: sessionService,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                            ),
                            child: ListTile(
                              tileColor: Theme.of(context).primaryColor,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${printWeekday(DateTime.now())} Session",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSecondary,
                                      fontFamily: "NovecentoSans",
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          Feedback.forLongPress(context);
                                          if (!sessionService.isPaused) {
                                            sessionService.pause();
                                          } else {
                                            sessionService.resume();
                                          }
                                        },
                                        focusColor: darken(Theme.of(context).primaryColor, 0.2),
                                        enableFeedback: true,
                                        borderRadius: BorderRadius.circular(30),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Icon(
                                            sessionService.isPaused ? Icons.play_arrow : Icons.pause,
                                            size: 30,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Text(
                                            printDuration(sessionService.currentDuration, true),
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSecondary,
                                              fontFamily: "NovecentoSans",
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: InkWell(
                                focusColor: darken(Theme.of(context).primaryColor, 0.6),
                                enableFeedback: true,
                                borderRadius: BorderRadius.circular(30),
                                child: Icon(
                                  _sessionPanelState == PanelState.CLOSED ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: Theme.of(context).colorScheme.onSecondary,
                                ),
                                onTap: () {
                                  Feedback.forLongPress(context);
                                  if (sessionPanelController.isPanelClosed) {
                                    sessionPanelController.open();
                                    setState(() => _sessionPanelState = PanelState.OPEN);
                                  } else {
                                    sessionPanelController.close();
                                    setState(() => _sessionPanelState = PanelState.CLOSED);
                                  }
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                              onTap: () {
                                if (sessionPanelController.isPanelClosed) {
                                  sessionPanelController.open();
                                  setState(() => _sessionPanelState = PanelState.OPEN);
                                } else {
                                  sessionPanelController.close();
                                  setState(() => _sessionPanelState = PanelState.CLOSED);
                                }
                              },
                            ),
                          );
                        },
                      ),
                // Panel body — challenge session or normal shooting.
                if (activeChallengeSession.value != null)
                  Expanded(
                    child: StartChallengeScreen(
                      challenge: activeChallengeSession.value!.challenge,
                      levelDoc: activeChallengeSession.value!.levelDoc,
                      attempt: activeChallengeSession.value!.attempt,
                      userId: activeChallengeSession.value!.userId,
                      onDismiss: () {
                        final cb = activeChallengeSession.value?.onSessionComplete;
                        activeChallengeSession.value = null;
                        sessionPanelController.close();
                        cb?.call();
                      },
                    ),
                  )
                else
                  StartShooting(sessionPanelController: sessionPanelController),
              ],
            ),
          ),
          body: StreamProvider<NetworkStatus>(
            create: (context) {
              return networkStatusService.networkStatusController.stream;
            },
            initialData: NetworkStatus.Online,
            child: NetworkAwareWidget(
              onlineChild: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  final roadControlsHeader = _selectedIndex == 0 && _startTabHasChallengerRoadAccess;
                  return [2].contains(_selectedIndex)
                      ? []
                      : roadControlsHeader
                          ? [
                              SliverToBoxAdapter(
                                child: _buildAnimatedRoadDrivenMainHeader(context),
                              ),
                            ]
                          : [
                              SliverAppBar(
                                collapsedHeight: 65,
                                expandedHeight: 85,
                                automaticallyImplyLeading: [3].contains(_selectedIndex) ? true : false,
                                backgroundColor: HomeTheme.darkTheme.colorScheme.primary,
                                iconTheme: Theme.of(context).iconTheme,
                                actionsIconTheme: Theme.of(context).iconTheme,
                                centerTitle: true,
                                floating: true,
                                pinned: true,
                                snap: false,
                                flexibleSpace: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: HomeTheme.darkTheme.colorScheme.primaryContainer,
                                  ),
                                  child: FlexibleSpaceBar(
                                    collapseMode: CollapseMode.parallax,
                                    centerTitle: true,
                                    titlePadding: const EdgeInsets.symmetric(vertical: 15),
                                    title: _tabs[_selectedIndex].title ??
                                        const SizedBox(
                                          height: 15,
                                        ),
                                    background: Container(
                                      color: HomeTheme.darkTheme.colorScheme.primaryContainer,
                                    ),
                                  ),
                                ),
                                leading: _leading,
                                actions: _tabs[_selectedIndex].id == 'community' ? _buildCommunityActions(context) : _actions,
                              ),
                            ];
                },
                body: Container(
                  padding: const EdgeInsets.only(bottom: 0),
                  // Use an IndexedStack so tab bodies remain mounted when not visible.
                  // This prevents disposing scroll controllers (e.g. Explore's NestedScrollView)
                  // while a user begins a gesture then quickly switches tabs, which was
                  // triggering disposed RenderObject / semantics assertions.
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _tabs,
                  ),
                ),
              ),
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
            ),
          ),
        ),
        bottomNavigationBar: SizedOverflowBox(
          alignment: AlignmentDirectional.topCenter,
          size: Size.fromHeight(AppBar().preferredSize.height - (AppBar().preferredSize.height * _bottomNavOffsetPercentage)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.play_arrow_rounded),
                label: 'Train',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups_rounded),
                label: 'Community',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Learn',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Me',
              ),
            ],
            currentIndex: _selectedIndex,
            backgroundColor: Theme.of(context).colorScheme.primary,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Theme.of(context).colorScheme.onPrimary,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
