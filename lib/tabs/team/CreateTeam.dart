import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/navigation/AppSectionNavigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class CreateTeam extends StatefulWidget {
  const CreateTeam({super.key});

  @override
  State<CreateTeam> createState() => _CreateTeamState();
}

class _CreateTeamState extends State<CreateTeam> {
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _nf = NumberFormat('###,###,###', 'en_US');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController(text: '100000');
  final TextEditingController _startDateController = TextEditingController(
    text: DateFormat('MMMM d, y').format(DateTime.now()),
  );
  final TextEditingController _targetDateController = TextEditingController(
    text: DateFormat('MMMM d, y').format(DateTime.now().add(const Duration(days: 100))),
  );
  int _goalTotal = 100000;
  DateTime _startDate = DateTime.now();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 100));
  bool _public = true;
  bool _saving = false;

  /// True while we’re checking whether the user already owns a team.
  bool _checkingProGate = true;

  /// True when the user owns ≥1 team AND is not a Pro subscriber.
  /// In that case the form is replaced by an upgrade prompt.
  bool _requiresProUpgrade = false;
  Team? _team;
  // Team identity
  String? _logoAsset;
  String _primaryColor = '#CC3333';
  String _darkAccent = '#111111';
  String _lightAccent = '#FFFFFF';

  @override
  void initState() {
    super.initState();
    _team = Team(
      '',
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
      100000,
      user?.uid ?? '',
      true,
      true,
      [],
    );
    _checkOwnershipGate();
  }

  /// Checks whether the user actively owns a team. All three conditions must
  /// be true - this prevents stale/orphaned Firestore data from gating users
  /// who only joined (not created) teams:
  ///   1. The team document has `owner_id == uid`
  ///   2. uid is in the team's `players` array
  ///   3. The team ID is in the user's own `team_ids` profile field
  Future<void> _checkOwnershipGate() async {
    final uid = user?.uid;
    if (uid == null) {
      if (mounted) setState(() => _checkingProGate = false);
      return;
    }
    try {
      // Load the user's profile first - this is the source of truth for team membership.
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final List<String> profileTeamIds = userDoc.exists ? _parseProfileTeamIds(userDoc.data()!) : [];

      if (profileTeamIds.isEmpty) {
        // User has no teams in their profile - definitely not an owner.
        if (mounted) setState(() => _checkingProGate = false);
        return;
      }

      final ownedSnap = await FirebaseFirestore.instance.collection('teams').where('owner_id', isEqualTo: uid).get();

      // All three conditions must hold to count as actively owning a team.
      final confirmedOwned = ownedSnap.docs.where((doc) {
        final players = List<String>.from(doc.data()['players'] ?? []);
        return players.contains(uid) && profileTeamIds.contains(doc.id);
      }).toList();

      if (confirmedOwned.isNotEmpty && mounted) {
        final isPro = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false;
        setState(() {
          _requiresProUpgrade = !isPro;
          _checkingProGate = false;
        });
      } else if (mounted) {
        setState(() => _checkingProGate = false);
      }
    } catch (_) {
      // On error, don't gate the user - let them proceed.
      if (mounted) setState(() => _checkingProGate = false);
    }
  }

  /// Parses team IDs from a raw Firestore user document map, handling both
  /// the new `team_ids` list and the legacy `team_id` string field.
  static List<String> _parseProfileTeamIds(Map<String, dynamic> data) {
    final raw = data['team_ids'];
    if (raw != null) return List<String>.from(raw);
    final legacy = data['team_id'] as String?;
    return legacy != null && legacy.isNotEmpty ? [legacy] : [];
  }

  Future<DateTime> _pickDate(TextEditingController ctrl, DateTime current, DateTime min, DateTime max) async {
    DateTime result = current;
    await DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: min,
      maxTime: max,
      onChanged: (_) {},
      onConfirm: (date) {
        ctrl.text = DateFormat('MMMM d, y').format(date);
        result = date;
      },
      currentTime: current,
      locale: LocaleType.en,
    );
    return result;
  }

  Future<void> _saveTeam() async {
    // Re-check the pro gate at save time (subscription may have changed
    // between screen open and save tap). Apply the same active-membership
    // guard as _checkOwnershipGate to avoid stale owner_id false-positives.
    try {
      final uid = user!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final List<String> profileTeamIds = userDoc.exists ? _parseProfileTeamIds(userDoc.data()!) : [];

      if (profileTeamIds.isNotEmpty) {
        final ownedSnap = await FirebaseFirestore.instance.collection('teams').where('owner_id', isEqualTo: uid).get();
        final confirmedOwned = ownedSnap.docs.where((doc) {
          final players = List<String>.from(doc.data()['players'] ?? []);
          return players.contains(uid) && profileTeamIds.contains(doc.id);
        }).toList();
        if (confirmedOwned.isNotEmpty) {
          final isPro = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false;
          if (!isPro) {
            await presentPaywallIfNeeded(context);
            if (mounted) {
              final nowPro = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false;
              setState(() => _requiresProUpgrade = !nowPro);
            }
            return;
          }
        }
      }
    } catch (_) {
      // On error, allow save to proceed.
    }
    if (_nameController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    _team!
      ..name = _nameController.text.toUpperCase()
      ..goalTotal = _goalTotal
      ..startDate = _startDate
      ..targetDate = _targetDate
      ..public = _public
      ..ownerId = user!.uid
      ..ownerParticipating = true
      ..primaryColor = _primaryColor
      ..darkAccentColor = _darkAccent
      ..lightAccentColor = _lightAccent
      ..logoAsset = _logoAsset;

    try {
      final ref = await FirebaseFirestore.instance.collection('teams').add(_team!.toMap());
      _team!.id = ref.id;
      await ref.update({'id': ref.id});

      if (!mounted) return;
      Fluttertoast.showToast(
        msg: 'Team "${_team!.name}" was created!'.toLowerCase(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Theme.of(context).cardTheme.color,
        textColor: Theme.of(context).colorScheme.onPrimary,
        fontSize: 16,
      );

      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userProfile = UserProfile.fromSnapshot(uDoc);
      userProfile.id = user!.uid;
      if (!userProfile.teamIds.contains(_team!.id)) {
        userProfile.teamIds.add(_team!.id!);
      }
      await uDoc.reference.set(userProfile.toMap());
      await FirebaseFirestore.instance.collection('teams').doc(_team!.id).update({
        'players': [user!.uid]
      });

      if (!mounted) return;
      goToAppSection(context, AppSection.community, communitySection: CommunitySection.team);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      Fluttertoast.showToast(
        msg: 'There was an error creating the team :('.toLowerCase(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        textColor: Colors.white70,
        fontSize: 16,
      );
    }
  }

  InputDecoration _fieldDecoration({String? hint, Widget? suffix}) {
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
      suffixIcon: suffix,
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
    return Builder(builder: (context) {
      return StreamProvider<NetworkStatus>(
        create: (_) => NetworkStatusService().networkStatusController.stream,
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
              headerSliverBuilder: (_, __) => [
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: null,
                      centerTitle: false,
                      title: const BasicTitle(title: 'Create Team'),
                      background: Container(color: Theme.of(context).scaffoldBackgroundColor),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: _saving
                          ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))
                          : IconButton(
                              icon: Icon(Icons.check_rounded, color: Colors.green.shade500, size: 28),
                              onPressed: _saveTeam,
                            ),
                    ),
                  ],
                ),
              ],
              body: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: _checkingProGate
                    ? const Center(child: CircularProgressIndicator())
                    : _requiresProUpgrade
                        ? _buildProGateBody()
                        : Form(
                            key: _formKey,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                              children: [
                                // ── Team Name ──────────────────────────────────────
                                _card(children: [
                                  _sectionLabel('Team Name'),
                                  TextFormField(
                                    controller: _nameController,
                                    keyboardType: TextInputType.text,
                                    textCapitalization: TextCapitalization.words,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onPrimary),
                                    cursorColor: Theme.of(context).colorScheme.onPrimary,
                                    inputFormatters: [LengthLimitingTextInputFormatter(52)],
                                    decoration: _fieldDecoration(hint: 'e.g. Rink Rats'),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a team name' : null,
                                  ),
                                ]),

                                const SizedBox(height: 12),

                                // ── Shot Goal ──────────────────────────────────────
                                _card(children: [
                                  _sectionLabel('Team Shot Goal'),
                                  Text(
                                    'Combined shots the whole team aims to reach.',
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _goalController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onPrimary),
                                    cursorColor: Theme.of(context).colorScheme.onPrimary,
                                    decoration: _fieldDecoration(hint: '100000'),
                                    onChanged: (v) {
                                      final parsed = int.tryParse(v);
                                      if (parsed != null) setState(() => _goalTotal = parsed);
                                    },
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Please enter a shot goal';
                                      if (int.tryParse(v) == null) return 'Enter a valid number';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _goalTotal > 0
                                        ? Text(
                                            '${_nf.format(_goalTotal)} shots',
                                            key: ValueKey(_goalTotal),
                                            style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Theme.of(context).primaryColor),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ]),

                                const SizedBox(height: 12),

                                // ── Dates ──────────────────────────────────────────
                                _card(children: [
                                  _sectionLabel('Challenge Window'),
                                  Text(
                                    'Set when the team challenge starts and ends.',
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
                                  ),
                                  const SizedBox(height: 12),
                                  _sectionLabel('Start Date'),
                                  AutoSizeTextField(
                                    controller: _startDateController,
                                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary),
                                    maxLines: 1,
                                    maxFontSize: 18,
                                    decoration: _fieldDecoration(suffix: Icon(Icons.calendar_today_outlined, size: 18, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45))),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await _pickDate(
                                        _startDateController,
                                        _startDate,
                                        DateTime(DateTime.now().year - 5),
                                        DateTime.now(),
                                      );
                                      setState(() => _startDate = date);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _sectionLabel('Target Completion Date'),
                                  AutoSizeTextField(
                                    controller: _targetDateController,
                                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary),
                                    maxLines: 1,
                                    maxFontSize: 18,
                                    decoration: _fieldDecoration(suffix: Icon(Icons.calendar_today_outlined, size: 18, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45))),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await _pickDate(
                                        _targetDateController,
                                        _targetDate,
                                        _startDate,
                                        DateTime(DateTime.now().year + 5),
                                      );
                                      setState(() => _targetDate = date);
                                    },
                                  ),
                                ]),

                                const SizedBox(height: 12),

                                // ── Visibility ─────────────────────────────────────
                                _card(children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Public Team', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.onPrimary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _public ? 'Anyone can search for and join your team.' : 'Only players with your team code can join.',
                                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _public,
                                        onChanged: (v) => setState(() => _public = v),
                                      ),
                                    ],
                                  ),
                                ]),

                                const SizedBox(height: 12),

                                // ── Team Identity ──────────────────────────────────
                                TeamIdentityPicker(
                                  initialLogoAsset: _logoAsset,
                                  initialPrimaryColor: _primaryColor,
                                  initialDarkAccent: _darkAccent,
                                  initialLightAccent: _lightAccent,
                                  onLogoChanged: (v) => setState(() => _logoAsset = v),
                                  onPrimaryColorChanged: (v) => setState(() => _primaryColor = v),
                                  onDarkAccentChanged: (v) => setState(() => _darkAccent = v),
                                  onLightAccentChanged: (v) => setState(() => _lightAccent = v),
                                ),

                                const SizedBox(height: 28),

                                // ── Create button ──────────────────────────────────
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveTeam,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Create Team', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Colors.white)),
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
    });
  }

  /// Shown when the user already owns a team and hasn't subscribed to Pro.
  Widget _buildProGateBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 64, color: Theme.of(context).primaryColor.withValues(alpha: 0.85)),
            const SizedBox(height: 20),
            Text(
              'Pro Required'.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 28, color: Theme.of(context).colorScheme.onPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'You already own a team. Managing more than one team is a Pro feature - upgrade to create and run multiple teams simultaneously.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await presentPaywallIfNeeded(context);
                  // After paywall closes, re-check status and update the gate flag
                  if (mounted) {
                    final nowPro = Provider.of<CustomerInfoNotifier?>(context, listen: false)?.isPro ?? false;
                    setState(() => _requiresProUpgrade = !nowPro);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Upgrade to Pro', style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 20, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
