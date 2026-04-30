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
import 'package:tenthousandshotchallenge/models/ConfirmDialog.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/CustomDialogs.dart';
import 'package:tenthousandshotchallenge/tabs/team/TeamIdentityPicker.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class EditTeam extends StatefulWidget {
  const EditTeam({super.key});

  @override
  State<EditTeam> createState() => _EditTeamState();
}

class _EditTeamState extends State<EditTeam> {
  final _user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _nf = NumberFormat('###,###,###', 'en_US');

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _targetDateController = TextEditingController();

  int _goalTotal = 0;
  DateTime _startDate = DateTime.now();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 100));
  bool _public = false;
  bool _saving = false;
  bool _loading = true;
  Team? _team;

  // Team identity
  String? _logoAsset;
  String _primaryColor = '#CC3333';
  String _darkAccent = '#111111';
  String _lightAccent = '#FFFFFF';

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final uDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
    final userProfile = UserProfile.fromSnapshot(uDoc);
    final tDoc = await FirebaseFirestore.instance.collection('teams').doc(userProfile.teamId).get();
    if (!mounted) return;
    final t = Team.fromSnapshot(tDoc);
    setState(() {
      _team = t;
      _goalTotal = t.goalTotal ?? 0;
      _startDate = t.startDate ?? DateTime.now();
      _targetDate = t.targetDate ?? DateTime.now().add(const Duration(days: 100));
      _public = t.public ?? false;
      _nameController.text = t.name ?? '';
      _goalController.text = _goalTotal.toString();
      _startDateController.text = DateFormat('MMMM d, y').format(_startDate);
      _targetDateController.text = DateFormat('MMMM d, y').format(_targetDate);
      _logoAsset = t.logoAsset;
      _primaryColor = t.primaryColor ?? '#CC3333';
      _darkAccent = t.darkAccentColor ?? '#111111';
      _lightAccent = t.lightAccentColor ?? '#FFFFFF';
      _loading = false;
    });
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
    if (_nameController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('teams').doc(_team!.id).update({
        'name': _nameController.text.trim().toUpperCase(),
        'goal_total': _goalTotal,
        'start_date': _startDate,
        'target_date': _targetDate,
        'public': _public,
        'primary_color': _primaryColor,
        'dark_accent_color': _darkAccent,
        'light_accent_color': _lightAccent,
        if (_logoAsset != null) 'logo_asset': _logoAsset else 'logo_asset': FieldValue.delete(),
      });
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: 'Team saved!'.toLowerCase(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Theme.of(context).cardTheme.color,
        textColor: Theme.of(context).colorScheme.onPrimary,
        fontSize: 16.0,
      );
      goToAppSection(context, AppSection.community, communitySection: CommunitySection.team);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      Fluttertoast.showToast(
        msg: 'Failed to save team :('.toLowerCase(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        textColor: Colors.white70,
        fontSize: 16.0,
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
    return Builder(
      builder: (context) {
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
                        title: const BasicTitle(title: 'Edit Team'),
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
                                onPressed: _loading ? null : _saveTeam,
                              ),
                      ),
                    ],
                  ),
                ],
                body: _loading
                    ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                    : GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        behavior: HitTestBehavior.translucent,
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                            children: [
                              // ── Team Name ──────────────────────────────
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

                              // ── Shot Goal ──────────────────────────────
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

                              // ── Dates ──────────────────────────────────
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

                              // ── Visibility ─────────────────────────────
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

                              // ── Team Identity ───────────────────────────
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

                              // ── Delete Team ─────────────────────────────
                              TextButton.icon(
                                onPressed: () {
                                  dialog(
                                    context,
                                    ConfirmDialog(
                                      "Delete team \"${_team!.name}\"?".toLowerCase(),
                                      Text(
                                        "The team will be deleted and all its data will be lost.\n\nWould you like to continue?",
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                      "Cancel",
                                      () => Navigator.of(context).pop(),
                                      "Continue",
                                      () async {
                                        await deleteTeam(
                                          _team!.id!,
                                          Provider.of<FirebaseAuth>(context, listen: false),
                                          Provider.of<FirebaseFirestore>(context, listen: false),
                                        ).then((r) {
                                          if (r) {
                                            Fluttertoast.showToast(
                                              msg: 'Team deleted!'.toUpperCase(),
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.BOTTOM,
                                              backgroundColor: Theme.of(context).cardTheme.color,
                                              textColor: Theme.of(context).colorScheme.onPrimary,
                                              fontSize: 16.0,
                                            );
                                            if (context.mounted) {
                                              goToAppSection(context, AppSection.community, communitySection: CommunitySection.team);
                                            }
                                          } else {
                                            Fluttertoast.showToast(
                                              msg: 'Failed to delete team :('.toUpperCase(),
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.BOTTOM,
                                              backgroundColor: Colors.redAccent,
                                              textColor: Theme.of(context).colorScheme.onPrimary,
                                              fontSize: 16.0,
                                            );
                                            Navigator.of(context).pop();
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                                icon: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                                label: Text(
                                  'Delete Team'.toUpperCase(),
                                  style: TextStyle(fontFamily: 'NovecentoSans', fontSize: 18, color: Theme.of(context).colorScheme.error),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.error,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
      },
    );
  }
}
