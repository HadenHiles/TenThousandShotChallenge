import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTextField.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/widgets/NavigationTitle.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({Key? key}) : super(key: key);

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController displayNameTextFieldController = TextEditingController();

  final List<String> _avatars = [];
  String _avatar = "";

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user!.uid).get().then((uDoc) {
      UserProfile userProfile = UserProfile.fromSnapshot(uDoc);

      _avatar = userProfile.photoUrl!;

      displayNameTextFieldController.text = userProfile.displayName != null ? userProfile.displayName! : user!.displayName!;
    });

    _loadAvatars();

    super.initState();
  }

  Future<Null> _loadAvatars() async {
    final manifestJson = await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
    final List<String> avatars = jsonDecode(manifestJson).keys.where((String key) => key.startsWith('assets/images/avatars')).toList();

    setState(() {
      _avatars.addAll(avatars);
    });
  }

  void _saveProfile() {
    FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'display_name': displayNameTextFieldController.text.toString(),
      'display_name_lowercase': displayNameTextFieldController.text.toString().toLowerCase(),
      'photo_url': _avatar,
    }).then((value) {});

    Fluttertoast.showToast(
      msg: 'Avatar saved!'.toLowerCase(),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Theme.of(context).cardTheme.color,
      textColor: Theme.of(context).colorScheme.onPrimary,
      fontSize: 16.0,
    );
    navigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (context) {
      return const Navigation(selectedIndex: 4, title: NavigationTitle(title: "Profile"));
    }));
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
                        navigatorKey.currentState!.pushReplacement(MaterialPageRoute(builder: (context) {
                          return const Navigation(selectedIndex: 4, title: NavigationTitle(title: "Profile"));
                        }));
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
                      title: const BasicTitle(title: "Edit Profile"),
                      background: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        icon: Icon(
                          Icons.check,
                          color: Colors.green.shade600,
                          size: 28,
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _saveProfile();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ];
            },
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: BasicTextField(
                              keyboardType: TextInputType.text,
                              hintText: 'Enter a display name',
                              controller: displayNameTextFieldController,
                              validator: (value) {
                                if (value.isEmpty) {
                                  return 'Please enter a display name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Choose an Avatar".toUpperCase(),
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                        Wrap(
                          children: _buildAvatars(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAvatars() {
    List<Widget> avatars = [
      GestureDetector(
        onTap: () {
          Feedback.forTap(context);

          setState(() {
            _avatar = user!.photoURL!;
          });

          _saveProfile();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, right: 4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(55),
            border: _avatar == user!.photoURL
                ? Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  )
                : Border.all(width: 0),
          ),
          width: 70,
          height: 70,
          child: UserAvatar(
            user: UserProfile(user!.displayName, user!.email, user!.photoURL, true, null, false, preferences!.fcmToken),
            backgroundColor: _avatar == user!.photoURL ? Theme.of(context).cardTheme.color : Colors.transparent,
          ),
        ),
      ),
    ];
    for (var a in _avatars) {
      avatars.add(
        GestureDetector(
          onTap: () {
            Feedback.forTap(context);

            setState(() {
              _avatar = a;
            });

            _saveProfile();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, right: 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(55),
              border: _avatar == a
                  ? Border.all(
                      color: Colors.transparent,
                      width: 2,
                    )
                  : Border.all(
                      width: 1,
                      color: Colors.transparent,
                    ),
            ),
            width: 70,
            height: 70,
            child: UserAvatar(
              user: UserProfile(user!.displayName, user!.email, a, true, null, false, preferences!.fcmToken),
              backgroundColor: _avatar == a ? Theme.of(context).cardTheme.color : Colors.transparent,
            ),
          ),
        ),
      );
    }

    return avatars;
  }
}
