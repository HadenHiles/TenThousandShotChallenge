import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/services/LocalNotificationService.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/VersionCheck.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/widgets/GlobalTrophyBackfillSheet.dart';
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
import 'package:tenthousandshotchallenge/widgets/NotificationBell.dart';

import 'models/Preferences.dart';
import 'package:tenthousandshotchallenge/widgets/AccountSwitcherSheet.dart';

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

/// Incrementing this signal tells the app to switch to the Train tab and open
/// the Challenger Road map view (without resetting it). Notifications that
/// link to the road should increment this instead of pushing a standalone route.
final ValueNotifier<int> openChallengerRoadSignal = ValueNotifier<int>(0);

/// The Firestore document ID of the team currently displayed in the Team tab.
/// Updated by [_TeamPageState] whenever the active team changes. The nav bar
/// reads this so its Edit button always reflects the team the user is viewing.
final ValueNotifier<String?> activeTeamIdNotifier = ValueNotifier<String?>(null);

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
class _NavigationState extends State<Navigation> with WidgetsBindingObserver {
  final ValueNotifier<CommunitySection> _communitySectionNotifier = ValueNotifier(CommunitySection.team);

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
  /// Incremented each time the session panel is opened; StartShooting listens
  /// to this to show the accuracy-tracking dialog at the right moment.
  final ValueNotifier<int> _sessionPanelOpenSignal = ValueNotifier<int>(0);
  // State variables
  PanelState _sessionPanelState = PanelState.CLOSED;
  double _bottomNavOffsetPercentage = 0;
  Team? team;
  UserProfile? userProfile;
  bool _startTabHasChallengerRoadAccess = false;

  /// Periodic timer that ticks the active-session notification during a
  /// Challenger Road session (normal sessions are ticked via sessionService).
  Timer? _crSessionTimer;

  /// Tracks the timestamp of the last tap on the "Me" tab for manual
  /// double-tap detection (avoids the 300 ms delay that [GestureDetector.onDoubleTap] imposes).
  DateTime? _lastMeTapTime;

  // Remove the field initializer for _tabs
  late List<NavigationTab> _tabs;

  /// The UID that [_tabs] was most recently built for.  When the active user
  /// changes (account switch) we rebuild [_tabs] with new keys so every tab's
  /// StatefulWidget element is replaced and re-reads data for the new user.
  String? _tabsUid;

  /// Auth-state subscription used to trigger tab rebuilds on account switch.
  StreamSubscription<User?>? _authTabSub;

  /// Builds the list of [NavigationTab]s.  Each tab receives a key that
  /// incorporates [_tabsUid] so that changing the UID (account switch) causes
  /// Flutter to replace every tab's element and state from scratch.
  List<NavigationTab> _buildTabs() {
    final uid = _tabsUid ?? '';
    return [
      NavigationTab(
        key: ValueKey('train-$uid'),
        id: 'train',
        title: Container(
          height: 40,
          padding: const EdgeInsets.only(top: 6),
          child: Image.asset('assets/images/logo-text-only.png'),
        ),
        actions: const [],
        body: ValueListenableBuilder<int>(
          valueListenable: _trainResetSignal,
          builder: (context, resetSignal, _) => Shots(
            sessionPanelController: sessionPanelController,
            resetSignal: resetSignal,
            onChallengerRoadAvailabilityChanged: _onChallengerRoadAvailabilityChanged,
          ),
        ),
      ),
      NavigationTab(
        key: ValueKey('community-$uid'),
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
        key: ValueKey('learn-$uid'),
        id: 'learn',
        title: null,
        body: const Explore(),
      ),
      NavigationTab(
        key: ValueKey('me-$uid'),
        id: 'me',
        title: NavigationTitle(title: 'Me'.toUpperCase()),
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
          NotificationBell(color: HomeTheme.darkTheme.colorScheme.onPrimary),
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
  }

  /// Rebuilds [_tabs] when the active Firebase user changes so every mounted
  /// tab widget is replaced with a fresh instance keyed to the new user.
  void _onAuthUserChangedForTabs(User? newUser) {
    // When the user signs out (newUser == null) the router will navigate away
    // from the main app automatically.  Rebuilding tabs with a null user would
    // cause Community/Team widgets to crash on user!.uid, so skip it.
    if (!mounted || newUser == null) return;
    final newUid = newUser.uid;
    if (newUid == _tabsUid) return; // Same user – nothing to do.
    setState(() {
      _tabsUid = newUid;
      _tabs = _buildTabs();
    });
  }

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
          isProUser: Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false,
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
    if (sessionService.isRunning) {
      LocalNotificationService.tickActiveSession(sessionService.currentDuration);
    }
    if (mounted) setState(() {});
  }

  void _onChallengeSessionChanged() {
    final config = activeChallengeSession.value;
    if (config != null) {
      // Show the notification immediately when a CR session starts.
      final elapsed = DateTime.now().difference(config.startedAt);
      LocalNotificationService.showActiveSession(shotCount: 0, duration: elapsed);
      // Tick the elapsed time every second (shots are tracked inside the panel).
      _crSessionTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        final current = activeChallengeSession.value;
        if (current == null) {
          _cancelCRSessionTimer();
          return;
        }
        LocalNotificationService.tickActiveSession(DateTime.now().difference(current.startedAt));
      });
    } else {
      // Session ended - stop timer and dismiss the notification.
      _cancelCRSessionTimer();
      LocalNotificationService.cancelActiveSession();
    }
    if (mounted) setState(() {});
  }

  void _cancelCRSessionTimer() {
    _crSessionTimer?.cancel();
    _crSessionTimer = null;
  }

  void _onChallengerRoadAvailabilityChanged(bool hasAccess) {
    if (!mounted || _startTabHasChallengerRoadAccess == hasAccess) return;
    setState(() {
      _startTabHasChallengerRoadAccess = hasAccess;
    });
  }

  /// Responds to [openChallengerRoadSignal]: switches to the Train tab without
  /// resetting the Challenger Road state, then lets [_ShotsState] open the map.
  void _onOpenChallengerRoadSignal() {
    if (!mounted) return;
    final trainIndex = _tabs.indexWhere((t) => t.id == 'train');
    if (trainIndex == -1) return;
    // Switch tab without incrementing _trainResetSignal (which would close CR).
    setState(() {
      _selectedIndex = trainIndex;
      _leading = _tabs[trainIndex].leading;
      _actions = widget.actions ?? _tabs[trainIndex].actions;
    });
    if (sessionPanelController.isAttached && !sessionPanelController.isPanelClosed) {
      sessionPanelController.close();
      setState(() => _sessionPanelState = PanelState.CLOSED);
    }
  }

  CommunitySection _normalizeCommunitySection(String? rawSection) {
    return rawSection == CommunitySection.friends.name ? CommunitySection.friends : CommunitySection.team;
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
    // Team title is shown inside the Team page content - return empty so it
    // doesn't overlap the action icons in the AppBar.
    return const SizedBox.shrink();
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

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    sessionService.addListener(_onSessionChanged);
    activeChallengeSession.addListener(_onChallengeSessionChanged);
    openChallengerRoadSignal.addListener(_onOpenChallengerRoadSignal);
    _communitySectionNotifier.value = _normalizeCommunitySection(widget.communitySection);
    try {
      versionCheck(context);
    } catch (e) {
      print(e);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateLastSeenIfNeeded(context);
      _checkTrophyBackfill();
    });

    _loadPreferences();

    _tabsUid = FirebaseAuth.instance.currentUser?.uid;
    _tabs = _buildTabs();
    _authTabSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthUserChangedForTabs);

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
    _authTabSub?.cancel();
    sessionService.removeListener(_onSessionChanged);
    activeChallengeSession.removeListener(_onChallengeSessionChanged);
    openChallengerRoadSignal.removeListener(_onOpenChallengerRoadSignal);
    _cancelCRSessionTimer();
    WidgetsBinding.instance.removeObserver(this);
    _communitySectionNotifier.dispose();
    _trainResetSignal.dispose();
    _sessionPanelOpenSignal.dispose();
    super.dispose();
  }

  /// Cancel any stale active-session notification when the app returns to the
  /// foreground and no session is running (e.g. after the app was killed and
  /// restarted, or after a session completed while the device was locked).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!sessionService.isRunning && activeChallengeSession.value == null) {
        LocalNotificationService.cancelActiveSession();
      }
    }
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

  /// Shown for online-only tabs (Community, Learn, Me) when the device is offline.
  Widget _buildOfflinePlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Connection',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'NovecentoSans',
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This section requires internet. Tap Train below to log a shooting session offline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineContent() {
    // Explore owns its own NestedScrollView. Render it directly so it is never
    // a child (even offstage) of the outer NestedScrollView used by other tabs.
    if (_selectedIndex == 2) {
      return _tabs[2];
    }

    final nonLearnTabs = <Widget>[
      _tabs[0],
      _tabs[1],
      _tabs[3],
    ];
    final nonLearnIndex = _selectedIndex == 3 ? 2 : _selectedIndex;
    final hideMainHeaderForTab = _selectedIndex == 0 && _startTabHasChallengerRoadAccess;

    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return hideMainHeaderForTab
            ? []
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
                  actions: [
                    ...(_tabs[_selectedIndex].id == 'community' ? _buildCommunityActions(context) : (_actions ?? [])),
                    if (_tabs[_selectedIndex].id != 'me') NotificationBell(color: HomeTheme.darkTheme.colorScheme.onPrimary),
                  ],
                ),
              ];
      },
      body: Container(
        padding: const EdgeInsets.only(bottom: 0),
        // Keep non-Learn tab bodies mounted to avoid gesture-related disposal churn.
        child: IndexedStack(
          index: nonLearnIndex,
          children: nonLearnTabs,
        ),
      ),
    );
  }

  // ── Challenge session panel header ────────────────────────────────────────

  Future<void> _confirmCloseSession() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
          'This will end your current shooting session. You can still collapse the panel with the arrow icon.',
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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End session', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      sessionService.reset();
      sessionPanelController.close();
    }
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
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

  // ── One-time historical trophy backfill check ─────────────────────────────
  Future<void> _checkTrophyBackfill() async {
    // Small delay so the UI has settled before we start loading sessions.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final auth = Provider.of<FirebaseAuth>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final level = await subscriptionLevel(context);
    if (!mounted) return;

    await maybeShowBackfillSheet(
      context,
      userId: uid,
      isPro: level == 'pro',
    );
  }

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
              final userProfile = UserProfile.fromSnapshot(userSnap.data!);
              final teamId = userProfile.teamId; // handles both team_ids and legacy team_id
              if (teamId == null || teamId.isEmpty) {
                // No team: QR to scan/join + ‘+’ to browse teams
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        icon: Icon(Icons.group_add_rounded, color: HomeTheme.darkTheme.colorScheme.onPrimary, size: 26),
                        tooltip: 'Join a team',
                        onPressed: () => context.push(AppRoutePaths.joinTeam),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        icon: Icon(Icons.qr_code_2_rounded, color: HomeTheme.darkTheme.colorScheme.onPrimary, size: 28),
                        onPressed: () => _handleJoinTeamQRCode(context),
                      ),
                    ),
                  ],
                );
              }
              // Wrap in ValueListenableBuilder so the edit button updates whenever
              // Team.dart publishes a new active team (e.g. user switches teams).
              return ValueListenableBuilder<String?>(
                valueListenable: activeTeamIdNotifier,
                builder: (context, activeId, _) {
                  // Prefer the actively viewed team; fall back to the profile's primary team.
                  final resolvedTeamId = (activeId != null && activeId.isNotEmpty) ? activeId : teamId;
                  final teamStream = Provider.of<FirebaseFirestore>(context, listen: false).collection('teams').doc(resolvedTeamId).snapshots();
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: teamStream,
                    builder: (context, teamSnap) {
                      if (!teamSnap.hasData || !teamSnap.data!.exists) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: IconButton(
                                icon: Icon(Icons.group_add_rounded, color: HomeTheme.darkTheme.colorScheme.onPrimary, size: 26),
                                tooltip: 'Join a team',
                                onPressed: () => context.push(AppRoutePaths.joinTeam),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: IconButton(
                                icon: Icon(Icons.qr_code_2_rounded, color: HomeTheme.darkTheme.colorScheme.onPrimary, size: 28),
                                onPressed: () => _handleJoinTeamQRCode(context),
                              ),
                            ),
                          ],
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
                                icon: Icon(Icons.edit, color: HomeTheme.darkTheme.colorScheme.onPrimary, size: 28),
                                onPressed: () => context.push(AppRoutePaths.editTeam, extra: teamSnap.data!.id),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: IconButton(
                              icon: Icon(Icons.group_add_rounded, color: HomeTheme.darkTheme.colorScheme.onPrimary, size: 26),
                              tooltip: 'Join a team',
                              onPressed: () => context.push(AppRoutePaths.joinTeam),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: IconButton(
                              icon: Icon(Icons.qr_code_2_rounded, color: HomeTheme.darkTheme.colorScheme.onPrimary, size: 28),
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
          );
        },
      ),
    ];
  }

  // ── Custom bottom nav bar ─────────────────────────────────────────────────

  /// Builds a custom bottom nav bar that is visually identical to Flutter's
  /// [BottomNavigationBar] but adds long-press support on the "Me" tab so the
  /// account switcher sheet can be triggered without requiring a full log-out.
  Widget _buildCustomNavBar(BuildContext context) {
    final selectedColor = Theme.of(context).primaryColor;
    final unselectedColor = Theme.of(context).colorScheme.onPrimary;
    final bgColor = Theme.of(context).colorScheme.primary;

    Widget navItem(
      int index,
      IconData icon,
      String label, {
      VoidCallback? onLongPress,
      VoidCallback? onDoubleTap,
    }) {
      final isSelected = _selectedIndex == index;
      final color = isSelected ? selectedColor : unselectedColor;

      // When a double-tap handler is provided we detect it manually so that
      // single taps remain instant (GestureDetector.onDoubleTap adds ~300 ms).
      final tapHandler = onDoubleTap != null
          ? () {
              final now = DateTime.now();
              if (_lastMeTapTime != null && now.difference(_lastMeTapTime!) < const Duration(milliseconds: 350)) {
                _lastMeTapTime = null;
                onDoubleTap();
              } else {
                _lastMeTapTime = now;
                _onItemTapped(index);
              }
            }
          : () => _onItemTapped(index);

      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tapHandler,
          onLongPress: onLongPress,
          child: SizedBox(
            height: kBottomNavigationBarHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: Row(
        children: [
          navItem(0, Icons.play_arrow_rounded, 'Train'),
          navItem(1, Icons.groups_rounded, 'Community'),
          navItem(2, Icons.dashboard_rounded, 'Learn'),
          navItem(
            3,
            Icons.person,
            'Me',
            onLongPress: () => showAccountSwitcherSheet(context),
            onDoubleTap: () => showAccountSwitcherSheet(context),
          ),
        ],
      ),
    );
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
          maxHeight: () {
            final H = MediaQuery.of(context).size.height;
            final padTop = MediaQuery.of(context).padding.top;
            if (isThreeButtonAndroidNavigation(context)) {
              // On 3-btn Android, main.dart Padding(bottom: vp.bottom) shrinks
              // the available height by vp.bottom.  When the panel is fully open
              // the BottomNavigationBar's SizedOverflowBox reports 0 height, so
              // the Scaffold body grows to H - vp.top - vp.bottom.  maxHeight
              // must equal that grown body height so the panel top lands exactly
              // at the status-bar bottom when expanded.
              final vp = MediaQuery.of(context).viewPadding;
              return H - vp.top - vp.bottom;
            }
            return H - padTop;
          }(),
          minHeight: () {
            // Header height is 74dp (SizedBox(74)).  On 3-btn Android the panel
            // needs to sit 8dp lower to visually align with the top of the
            // BottomNavigationBar; the bottom 8dp of header padding is clipped
            // behind the nav bar but all visible content remains intact.
            final minH = isThreeButtonAndroidNavigation(context) ? 66.0 : 74.0;
            if (activeChallengeSession.value != null) return minH;
            if (sessionService.isRunning) return minH;
            return 0.0;
          }(),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          onPanelOpened: () {
            sessionService.resume();
            setState(() {
              _sessionPanelState = PanelState.OPEN;
            });
            _sessionPanelOpenSignal.value++;
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
                // Panel header - switches between challenge mode and normal shooting.
                activeChallengeSession.value != null
                    ? _buildChallengeSessionHeader(activeChallengeSession.value!)
                    : AnimatedBuilder(
                        animation: sessionService,
                        builder: (context, child) {
                          return Material(
                            color: Theme.of(context).primaryColor,
                            child: InkWell(
                              onTap: () {
                                if (sessionPanelController.isPanelClosed) {
                                  sessionPanelController.open();
                                  setState(() => _sessionPanelState = PanelState.OPEN);
                                } else {
                                  sessionPanelController.close();
                                  setState(() => _sessionPanelState = PanelState.CLOSED);
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
                                              '${printWeekday(DateTime.now())} Session'.toUpperCase(),
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
                                              'SESSION IN PROGRESS',
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
                                      // Pause/resume + timer pill
                                      InkWell(
                                        onTap: () {
                                          Feedback.forLongPress(context);
                                          if (!sessionService.isPaused) {
                                            sessionService.pause();
                                          } else {
                                            sessionService.resume();
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(999),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                sessionService.isPaused ? Icons.play_arrow : Icons.pause,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              SizedBox(
                                                width: 56,
                                                child: Text(
                                                  printDuration(sessionService.currentDuration, true),
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
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Close session
                                      InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _confirmCloseSession(),
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
                                            setState(() => _sessionPanelState = PanelState.OPEN);
                                          } else {
                                            sessionPanelController.close();
                                            setState(() => _sessionPanelState = PanelState.CLOSED);
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
                        },
                      ),
                // Panel body - challenge session or normal shooting.
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
                  StartShooting(
                    sessionPanelController: sessionPanelController,
                    panelOpenSignal: _sessionPanelOpenSignal,
                  ),
              ],
            ),
          ),
          body: StreamProvider<NetworkStatus>(
            create: (context) {
              return networkStatusService.networkStatusController.stream;
            },
            initialData: NetworkStatus.Online,
            child: Builder(
              builder: (context) {
                final isOffline = Provider.of<NetworkStatus>(context) == NetworkStatus.Offline;
                // Train tab (index 0) is offline-capable - sessions are queued locally.
                // Profile tab (index 3) is also accessible offline so users can reach Settings;
                // Firestore-dependent sections within the Profile are disabled when offline.
                if (!isOffline || _selectedIndex == 0 || _selectedIndex == 3) {
                  return _buildOnlineContent();
                }
                // Community and Learn tabs require an internet connection.
                return _buildOfflinePlaceholder(context);
              },
            ),
          ),
        ),
        bottomNavigationBar: Builder(
          builder: (context) {
            // Use SafeArea to handle the home indicator inset rather than
            // manually computing safeBottom - this is more reliable across
            // all iOS/Android device variants and navigation modes.
            // Three-button Android is already shifted up by main.dart so we
            // zero out the bottom safe area there to avoid double-counting.
            final isGestureNavAndroid = Theme.of(context).platform == TargetPlatform.android && !isThreeButtonAndroidNavigation(context);
            final safeBottom = isThreeButtonAndroidNavigation(context) ? 0.0 : MediaQuery.of(context).padding.bottom;
            final androidGestureExtra = isGestureNavAndroid ? 10.0 : 0.0;
            final bottomPadding = (safeBottom - 15).clamp(0.0, safeBottom) + androidGestureExtra;
            final fullNavHeight = kBottomNavigationBarHeight + bottomPadding;
            return SizedOverflowBox(
              alignment: AlignmentDirectional.topCenter,
              size: Size.fromHeight(fullNavHeight * (1 - _bottomNavOffsetPercentage)),
              child: Container(
                color: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: _buildCustomNavBar(context),
              ),
            );
          },
        ),
      ),
    );
  }
}
