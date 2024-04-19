import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTextField.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';

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
                Image(
                  image: AssetImage('assets/images/logo.png'),
                ),
                Text(
                  "Where's the wifi bud?".toUpperCase(),
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: "NovecentoSans",
                    fontSize: 24,
                  ),
                ),
                SizedBox(
                  height: 25,
                ),
                CircularProgressIndicator(
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
                      color: Theme.of(context).colorScheme.background,
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
                          color: Colors.green.shade600,
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
                                DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
                                prefs.getString('fcm_token'),
                              ),
                            );

                            SnackBar(
                                backgroundColor: Theme.of(context).cardTheme.color,
                                content: new Text(
                                  'Puck count was saved successfully!',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ));
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
        ),
      ),
    );
  }
}
