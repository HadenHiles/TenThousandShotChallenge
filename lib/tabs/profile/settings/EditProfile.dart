import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/theme/Theme.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  User? get user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  final List<String> _mascotAvatars = [];
  final List<String> _characterAvatars = [];
  final List<String> _playerAvatars = [];
  final List<String> _teamAvatars = [];
  String _avatar = '';

  @override
  void initState() {
    super.initState();
    Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(user!.uid).get().then((uDoc) {
      if (!mounted) return;
      final userProfile = UserProfile.fromSnapshot(uDoc);
      setState(() {
        _avatar = userProfile.photoUrl ?? user!.photoURL ?? '';
        _displayNameController.text = userProfile.displayName ?? user!.displayName ?? '';
        _nicknameController.text = userProfile.nickname ?? '';
      });
    });
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    final manifest = await AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context));
    final all = manifest.listAssets();
    final mascots = all.where((k) => k.startsWith('assets/images/avatars/mascots/')).toList()..sort();
    final characters = all.where((k) => k.startsWith('assets/images/avatars/characters/')).toList()..sort();
    final players = all.where((k) => k.startsWith('assets/images/avatars/players/')).toList()..sort();
    final teams = all.where((k) => k.startsWith('assets/images/avatars/teams/')).toList()..sort();
    if (!mounted) return;
    setState(() {
      _mascotAvatars
        ..clear()
        ..addAll(mascots);
      _characterAvatars
        ..clear()
        ..addAll(characters);
      _playerAvatars
        ..clear()
        ..addAll(players);
      _teamAvatars
        ..clear()
        ..addAll(teams);
    });
  }

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

  void _saveProfile() {
    Provider.of<FirebaseFirestore>(context, listen: false).collection('users').doc(user!.uid).update({
      'display_name': _displayNameController.text.trim(),
      'display_name_lowercase': _displayNameController.text.trim().toLowerCase(),
      'nickname': _nicknameController.text.trim(),
      'photo_url': _avatar,
    });

    Fluttertoast.showToast(
      msg: 'Profile saved!'.toLowerCase(),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Theme.of(context).cardTheme.color,
      textColor: Theme.of(context).colorScheme.onPrimary,
      fontSize: 16.0,
    );
    context.pop();
  }

  void _selectAvatar(String avatarValue) {
    setState(() => _avatar = avatarValue);
    _saveProfile();
  }

  @override
  Widget build(BuildContext context) {
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
                    title: const BasicTitle(title: 'Edit Profile'),
                    background: Container(color: Theme.of(context).scaffoldBackgroundColor),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: IconButton(
                      icon: Icon(Icons.check_rounded, color: Colors.green.shade500, size: 28),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _saveProfile();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    // ── Display Name ─────────────────────────────────
                    _card(children: [
                      _sectionLabel('Display Name'),
                      TextFormField(
                        controller: _displayNameController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onPrimary),
                        inputFormatters: [LengthLimitingTextInputFormatter(26)],
                        decoration: _fieldDecoration(hint: 'Enter a display name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a display name' : null,
                      ),
                    ]),

                    const SizedBox(height: 12),

                    // ── Nickname ──────────────────────────────────────
                    _card(children: [
                      _sectionLabel('Nickname'),
                      Text(
                        'Used in notifications.',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nicknameController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onPrimary),
                        decoration: _fieldDecoration(hint: 'Nickname (optional)'),
                      ),
                    ]),

                    const SizedBox(height: 12),

                    // ── Avatar ────────────────────────────────────────
                    _card(children: [
                      _sectionLabel('Profile Avatar'),
                      Text(
                        'Choose your Google account photo or pick an avatar below.',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 14),
                      _buildAvatarSections(),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSections() {
    final String googlePhoto = user!.photoURL ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Google account photo
        if (googlePhoto.isNotEmpty)
          ..._avatarSection(
            context,
            label: 'Google Account',
            items: [googlePhoto],
            isNetwork: true,
          ),

        // Mascots
        if (_mascotAvatars.isNotEmpty)
          ..._avatarSection(
            context,
            label: 'Mascots',
            items: _mascotAvatars,
          ),

        // Characters
        if (_characterAvatars.isNotEmpty)
          ..._avatarSection(
            context,
            label: 'Characters',
            items: _characterAvatars,
          ),

        // Players
        if (_playerAvatars.isNotEmpty)
          ..._avatarSection(
            context,
            label: 'Players',
            items: _playerAvatars,
          ),

        // NHL Teams
        if (_teamAvatars.isNotEmpty)
          ..._avatarSection(
            context,
            label: 'NHL Teams',
            items: _teamAvatars,
          ),
      ],
    );
  }

  List<Widget> _avatarSection(
    BuildContext context, {
    required String label,
    required List<String> items,
    bool isNetwork = false,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 11,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38),
          ),
        ),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items.map((a) {
          final bool selected = _avatar == a;
          return GestureDetector(
            onTap: () {
              Feedback.forTap(context);
              _selectAvatar(a);
            },
            child: SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    backgroundImage: isNetwork ? NetworkImage(a) : null,
                    child: isNetwork
                        ? null
                        : ClipOval(
                            child: Image(
                              image: AssetImage(a),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  if (selected)
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }
}
