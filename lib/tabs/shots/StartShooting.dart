import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/widgets/NetworkAwareWidget.dart';
import 'package:url_launcher/url_launcher.dart';

class StartShooting extends StatefulWidget {
  StartShooting({Key key, this.sessionPanelController, this.shots}) : super(key: key);

  final PanelController sessionPanelController;
  final List<Shots> shots;

  @override
  _StartShootingState createState() => _StartShootingState();
}

class _StartShootingState extends State<StartShooting> {
  // Stateful variables
  String _selectedShotType = 'wrist';
  int _currentShotCount = preferences.puckCount;
  bool _puckCountUpdating = false;
  List<Shots> _shots = [];

  @override
  void initState() {
    _shots = widget.shots ?? [];
    _currentShotCount = preferences.puckCount;

    super.initState();
  }

  @override
  void dispose() {
    _shots = [];
    _currentShotCount = preferences.puckCount;
    super.dispose();
  }

  void reset() {
    _shots = [];
    _currentShotCount = preferences.puckCount;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 15),
                Text(
                  "Shot Type".toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontFamily: 'NovecentoSans',
                    fontSize: 24,
                  ),
                ),
                SizedBox(height: 5),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      ShotTypeButton(
                        type: 'wrist',
                        active: _selectedShotType == 'wrist',
                        onPressed: () {
                          Feedback.forLongPress(context);
                          setState(() {
                            _selectedShotType = 'wrist';
                          });
                        },
                      ),
                      ShotTypeButton(
                        type: 'snap',
                        active: _selectedShotType == 'snap',
                        onPressed: () {
                          Feedback.forLongPress(context);
                          setState(() {
                            _selectedShotType = 'snap';
                          });
                        },
                      ),
                      ShotTypeButton(
                        type: 'slap',
                        active: _selectedShotType == 'slap',
                        onPressed: () {
                          Feedback.forLongPress(context);
                          setState(() {
                            _selectedShotType = 'slap';
                          });
                        },
                      ),
                      ShotTypeButton(
                        type: 'backhand',
                        active: _selectedShotType == 'backhand',
                        onPressed: () {
                          Feedback.forLongPress(context);
                          setState(() {
                            _selectedShotType = 'backhand';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                preferences.puckCount != _currentShotCount
                    ? SizedBox(
                        height: 10,
                      )
                    : Container(),
                GestureDetector(
                  onTap: () async {
                    Feedback.forLongPress(context);

                    setState(() {
                      _puckCountUpdating = true;
                    });

                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    prefs.setInt(
                      'puck_count',
                      _currentShotCount,
                    );

                    Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(
                      Preferences(
                        prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
                        _currentShotCount,
                        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
                        prefs.getString('fcm_token'),
                      ),
                    );

                    Future.delayed(Duration(seconds: 1), () {
                      setState(() {
                        _puckCountUpdating = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Theme.of(context).cardTheme.color,
                          content: new Text(
                            '# of pucks updated successfully!',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          duration: Duration(milliseconds: 1200),
                        ),
                      );
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _puckCountUpdating
                          ? SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                          : preferences.puckCount != _currentShotCount
                              ? Text(
                                  "Tap to update # of pucks you have from ${preferences.puckCount} to $_currentShotCount",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Container(height: 14),
                      preferences.puckCount != _currentShotCount
                          ? Container(
                              margin: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 14,
                              ),
                            )
                          : Container(),
                    ],
                  ),
                ),
                preferences.puckCount != _currentShotCount
                    ? SizedBox(
                        height: 5,
                      )
                    : Container(),
                Text(
                  "# of Shots".toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontFamily: 'NovecentoSans',
                    fontSize: 24,
                  ),
                ),
                SizedBox(height: 15),
                GestureDetector(
                  onLongPress: () async {
                    Feedback.forLongPress(context);

                    await prompt(
                      context,
                      title: Text('Shots'),
                      initialValue: _currentShotCount.toString(),
                      textOK: Icon(
                        Icons.check,
                        color: Colors.green.shade700,
                      ),
                      textCancel: Icon(
                        Icons.close,
                        color: Colors.grey,
                      ),
                      minLines: 1,
                      maxLines: 1,
                      autoFocus: true,
                      obscureText: false,
                      obscuringCharacter: '•',
                      textCapitalization: TextCapitalization.words,
                      keyboardType: TextInputType.number,
                    ).then((value) {
                      if (value != null && int.parse(value) > 0 && int.parse(value) <= 500) {
                        setState(() {
                          _currentShotCount = int.parse(value);
                        });
                      }
                    });
                  },
                  child: NumberPicker(
                    value: _currentShotCount,
                    minValue: 1,
                    maxValue: 500,
                    step: 1,
                    itemHeight: 60,
                    textStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20),
                    axis: Axis.horizontal,
                    haptics: true,
                    infiniteLoop: true,
                    onChanged: (value) {
                      setState(() {
                        _currentShotCount = value;
                      });
                    },
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Text(
                  "Long press for numpad",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 15,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width - 200,
                  child: TextButton(
                    onPressed: () async {
                      Feedback.forLongPress(context);

                      Shots shots = Shots(DateTime.now(), _selectedShotType, _currentShotCount);
                      setState(() {
                        _shots.insert(0, shots);
                      });
                    },
                    child: Icon(
                      Icons.check,
                      size: 40,
                      color: Colors.white,
                    ),
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: 10, horizontal: 5)),
                      backgroundColor: MaterialStateProperty.all(Colors.green.shade600),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Tap",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        Icons.check,
                        color: Colors.green.shade600,
                        size: 14,
                      ),
                    ),
                    Text(
                      "to save below",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 15,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(0),
                    children: _buildShotsList(context, _shots),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 60,
                      width: MediaQuery.of(context).size.width,
                      child: StreamProvider<NetworkStatus>(
                        create: (context) {
                          return NetworkStatusService().networkStatusController.stream;
                        },
                        initialData: NetworkStatus.Online,
                        child: NetworkAwareWidget(
                          onlineChild: _shots.length < 1
                              ? TextButton(
                                  onPressed: () {
                                    Feedback.forLongPress(context);

                                    sessionService.reset();
                                    widget.sessionPanelController.close();
                                    this.reset();
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Cancel".toUpperCase(),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 24,
                                        ),
                                      ),
                                      Container(
                                        margin: EdgeInsets.only(top: 3, left: 4),
                                        child: Icon(
                                          Icons.delete_forever,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextButton.styleFrom(
                                    primary: Theme.of(context).cardTheme.color,
                                    backgroundColor: Theme.of(context).cardTheme.color,
                                    onSurface: Theme.of(context).colorScheme.onPrimary,
                                    shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0))),
                                  ),
                                )
                              : TextButton(
                                  onPressed: () async {
                                    Feedback.forLongPress(context);

                                    int totalShots = 0;
                                    _shots.forEach((s) {
                                      totalShots += s.count;
                                    });

                                    await saveShootingSession(_shots).then((success) async {
                                      sessionService.reset();
                                      widget.sessionPanelController.close();
                                      this.reset();

                                      await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) {
                                        if (snapshot.docs.isNotEmpty) {
                                          Iteration i = Iteration.fromSnapshot(snapshot.docs[0]);

                                          if ((i.total + totalShots) < 10000) {
                                            Fluttertoast.showToast(
                                              msg: 'Shooting session saved!',
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.BOTTOM,
                                              timeInSecForIosWeb: 1,
                                              backgroundColor: Theme.of(context).cardTheme.color,
                                              textColor: Theme.of(context).colorScheme.onPrimary,
                                              fontSize: 16.0,
                                            );
                                          } else {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return Dialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                                                  child: SingleChildScrollView(
                                                    clipBehavior: Clip.none,
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      alignment: Alignment.topCenter,
                                                      children: [
                                                        Container(
                                                          height: 530,
                                                          child: Padding(
                                                            padding: const EdgeInsets.fromLTRB(10, 70, 10, 10),
                                                            child: Column(
                                                              children: [
                                                                Text(
                                                                  "Challenge Complete!".toUpperCase(),
                                                                  textAlign: TextAlign.center,
                                                                  style: TextStyle(
                                                                    color: Theme.of(context).primaryColor,
                                                                    fontFamily: "NovecentoSans",
                                                                    fontSize: 32,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Text(
                                                                  "Nice job, ya beauty!\n10,000 shots isn\'t easy.",
                                                                  textAlign: TextAlign.center,
                                                                  style: TextStyle(
                                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                                    fontFamily: "NovecentoSans",
                                                                    fontSize: 22,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Opacity(
                                                                  opacity: 0.8,
                                                                  child: Text(
                                                                    "To celebrate, here\'s a coupon code for our special snapback only available to snipers like yourself.",
                                                                    textAlign: TextAlign.center,
                                                                    style: TextStyle(
                                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                                      fontFamily: "NovecentoSans",
                                                                      fontSize: 18,
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 15,
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () async {
                                                                    String link = "https://teespring.com/sniper-snapback?pr=TENKSNIPER";
                                                                    await canLaunch(link).then((can) {
                                                                      launch(link).catchError((err) {
                                                                        print(err);
                                                                      });
                                                                    });
                                                                  },
                                                                  child: Card(
                                                                    color: Theme.of(context).cardTheme.color,
                                                                    elevation: 4,
                                                                    child: Container(
                                                                      width: 125,
                                                                      height: 180,
                                                                      child: Column(
                                                                        mainAxisAlignment: MainAxisAlignment.start,
                                                                        children: [
                                                                          Image(
                                                                            image: NetworkImage(
                                                                              "https://mockup-api.teespring.com/static.jpg?height=560&image_url=https%3A%2F%2Fteespring-pub-custom.s3.amazonaws.com%2F4a4_110354429_product_762_103363_front.png&padded=false&signature=BiR0YcAkTV7e48t07B2zTnZ4HoEQRz5u3s50Y2hIaXw%3D&version=2021-06-13-21-51-49&width=480",
                                                                            ),
                                                                            width: 150,
                                                                          ),
                                                                          Expanded(
                                                                            child: Column(
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                Container(
                                                                                  padding: EdgeInsets.all(5),
                                                                                  child: AutoSizeText(
                                                                                    "10,000 Shot Sniper Snapback".toUpperCase(),
                                                                                    maxLines: 2,
                                                                                    maxFontSize: 20,
                                                                                    textAlign: TextAlign.center,
                                                                                    style: TextStyle(
                                                                                      fontFamily: "NovecentoSans",
                                                                                      fontSize: 18,
                                                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                    color: Theme.of(context).colorScheme.primaryVariant,
                                                                  ),
                                                                  padding: EdgeInsets.all(5),
                                                                  child: SelectableText(
                                                                    "TENKSNIPER",
                                                                    style: TextStyle(
                                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                                      fontFamily: "NovecentoSans",
                                                                      fontSize: 24,
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                TextButton(
                                                                  onPressed: () {
                                                                    Navigator.of(context).pop();
                                                                  },
                                                                  style: ButtonStyle(
                                                                    backgroundColor: MaterialStateProperty.all(
                                                                      Theme.of(context).primaryColor,
                                                                    ),
                                                                    padding: MaterialStateProperty.all(EdgeInsets.all(4)),
                                                                  ),
                                                                  child: Text(
                                                                    "OK",
                                                                    style: TextStyle(
                                                                      fontFamily: "NovecentoSans",
                                                                      fontSize: 30,
                                                                      color: Colors.white,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: -40,
                                                          child: Container(
                                                            width: 100,
                                                            height: 100,
                                                            child: Image(
                                                              image: AssetImage("assets/images/GoalLight.gif"),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          }
                                        }
                                      });
                                    }).onError((error, stackTrace) {
                                      print(error);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Theme.of(context).cardTheme.color,
                                          content: new Text(
                                            'There was an error saving your shooting session :(',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                          duration: Duration(milliseconds: 1500),
                                        ),
                                      );
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Finish".toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'NovecentoSans',
                                          fontSize: 24,
                                        ),
                                      ),
                                      Container(
                                        margin: EdgeInsets.only(top: 3, left: 4),
                                        child: Icon(
                                          Icons.save_alt_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextButton.styleFrom(
                                    primary: Theme.of(context).primaryColor,
                                    backgroundColor: Theme.of(context).primaryColor,
                                    onSurface: Colors.white,
                                    shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0))),
                                  ),
                                ),
                          offlineChild: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "You need wifi to save, bud.".toLowerCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontFamily: "NovecentoSans",
                                    fontSize: 24,
                                  ),
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Container(
                                  width: 16,
                                  height: 16,
                                  margin: EdgeInsets.only(top: 5),
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Dismissible> _buildShotsList(BuildContext context, List<Shots> shots) {
    List<Dismissible> list = [];

    shots.asMap().forEach((i, s) {
      Dismissible tile = Dismissible(
        key: UniqueKey(),
        onDismissed: (direction) {
          Fluttertoast.showToast(
            msg: '${s.count} ${s.type} shots deleted',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Theme.of(context).cardTheme.color,
            textColor: Theme.of(context).colorScheme.onPrimary,
            fontSize: 16.0,
          );
          setState(() {
            _shots.remove(s);
          });
        },
        background: Container(
          color: Theme.of(context).primaryColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                margin: EdgeInsets.only(left: 15),
                child: Text(
                  "Delete".toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(right: 15),
                child: Icon(
                  Icons.delete,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        child: ListTile(
          tileColor: (i % 2 == 0) ? Theme.of(context).cardTheme.color : Theme.of(context).colorScheme.primary,
          leading: Container(
            margin: EdgeInsets.only(bottom: 4),
            child: Text(
              s.count.toString(),
              style: TextStyle(fontSize: 24, fontFamily: 'NovecentoSans'),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                s.type.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontFamily: 'NovecentoSans',
                ),
              ),
              Text(
                printTime(s.date),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontFamily: 'NovecentoSans',
                ),
              ),
            ],
          ),
          // trailing: IconButton(
          //   onPressed: () {
          //     setState(() {
          //       _shots.removeAt(i);
          //     });
          //   },
          //   icon: Icon(
          //     Icons.delete,
          //     color: i % 2 == 0 ? Theme.of(context).colorScheme.primaryVariant : Theme.of(context).cardTheme.color,
          //   ),
          // ),
        ),
      );

      list.add(tile);
    });

    return list;
  }
}
