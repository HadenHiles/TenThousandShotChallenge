import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTextField.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';

class EditPuckCount extends StatefulWidget {
  EditPuckCount({Key key}) : super(key: key);

  @override
  _EditPuckCountState createState() => _EditPuckCountState();
}

class _EditPuckCountState extends State<EditPuckCount> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController puckCountTextFieldController = TextEditingController();

  @override
  void initState() {
    setState(() {
      puckCountTextFieldController.text = preferences.puckCount != null ? preferences.puckCount.toString() : 25.toString();
    });

    super.initState();
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
                  title: BasicTitle(title: "How many pucks do you have?"),
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
                      size: 28,
                    ),
                    onPressed: () async {
                      if (_formKey.currentState.validate()) {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        setState(() {
                          prefs.setInt(
                            'puck_count',
                            int.parse(puckCountTextFieldController.text),
                          );
                        });
                        Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(
                          Preferences(
                            prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
                            int.parse(puckCountTextFieldController.text),
                          ),
                        );

                        new SnackBar(content: new Text('Puck count was saved successfully!'));
                        navigatorKey.currentState.pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ];
        },
        body: Container(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: BasicTextField(
                      keyboardType: TextInputType.number,
                      hintText: '# of Pucks',
                      controller: puckCountTextFieldController,
                      validator: (value) {
                        if (value.isEmpty) {
                          return 'Please enter how many pucks you have';
                        } else if (int.parse(value) <= 0) {
                          return 'Must have at least 1 puck';
                        }
                        return null;
                      },
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
}