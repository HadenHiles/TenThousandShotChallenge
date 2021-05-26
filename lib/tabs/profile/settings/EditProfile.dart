import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTextField.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';

class EditProfile extends StatefulWidget {
  EditProfile({Key key}) : super(key: key);

  @override
  _EditProfileState createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController displayNameTextFieldController = TextEditingController();

  List<String> _avatars = [];
  String _avatar = "";

  @override
  void initState() {
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((uDoc) {
      UserProfile userProfile = UserProfile.fromSnapshot(uDoc);

      _avatar = userProfile.photoUrl;

      displayNameTextFieldController.text = userProfile.displayName != null ? userProfile.displayName : user.displayName;
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
    FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'display_name': displayNameTextFieldController.text.toString(),
      'display_name_lowercase': displayNameTextFieldController.text.toString().toLowerCase(),
      'photo_url': _avatar,
    }).then((value) {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Avatar saved!'),
      ),
    );
    navigatorKey.currentState.pushReplacement(MaterialPageRoute(builder: (context) {
      return Navigation(selectedIndex: 2);
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
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
                margin: EdgeInsets.only(top: 10),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                  onPressed: () {
                    navigatorKey.currentState.pop();
                  },
                ),
              ),
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).backgroundColor,
                ),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: null,
                  centerTitle: false,
                  title: BasicTitle(title: "Edit Profile"),
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: IconButton(
                    icon: Icon(
                      Icons.check,
                      color: Colors.green.shade600,
                      size: 28,
                    ),
                    onPressed: () {
                      if (_formKey.currentState.validate()) {
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
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
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
                margin: EdgeInsets.symmetric(horizontal: 10),
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
                    SizedBox(
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
    );
  }

  List<Widget> _buildAvatars() {
    List<Widget> avatars = [
      GestureDetector(
        onTap: () {
          Feedback.forTap(context);

          setState(() {
            _avatar = user.photoURL;
          });

          _saveProfile();
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 10, right: 4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(55),
            border: _avatar == user.photoURL
                ? Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  )
                : Border.all(width: 0),
          ),
          width: 70,
          height: 70,
          child: UserAvatar(
            user: UserProfile(user.displayName, user.email, user.photoURL, true, preferences.fcmToken),
            backgroundColor: _avatar == user.photoURL ? Theme.of(context).cardTheme.color : Colors.transparent,
          ),
        ),
      ),
    ];
    _avatars.forEach((a) {
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
            margin: EdgeInsets.only(bottom: 10, right: 4),
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
              user: UserProfile(user.displayName, user.email, a, true, preferences.fcmToken),
              backgroundColor: _avatar == a ? Theme.of(context).cardTheme.color : Colors.transparent,
            ),
          ),
        ),
      );
    });

    return avatars;
  }
}
