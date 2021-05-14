import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/Preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/services/firestore.dart';
import 'package:tenthousandshotchallenge/services/utility.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';

class StartShooting extends StatefulWidget {
  StartShooting({Key key, this.sessionPanelController}) : super(key: key);

  final PanelController sessionPanelController;

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
    _shots = [];
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
                    fontSize: 28,
                  ),
                ),
                SizedBox(height: 15),
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
                          setState(() {
                            _selectedShotType = 'wrist';
                          });
                        },
                      ),
                      ShotTypeButton(
                        type: 'snap',
                        active: _selectedShotType == 'snap',
                        onPressed: () {
                          setState(() {
                            _selectedShotType = 'snap';
                          });
                        },
                      ),
                      ShotTypeButton(
                        type: 'slap',
                        active: _selectedShotType == 'slap',
                        onPressed: () {
                          setState(() {
                            _selectedShotType = 'slap';
                          });
                        },
                      ),
                      ShotTypeButton(
                        type: 'backhand',
                        active: _selectedShotType == 'backhand',
                        onPressed: () {
                          setState(() {
                            _selectedShotType = 'backhand';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 15,
                ),
                Text(
                  "# of Shots".toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontFamily: 'NovecentoSans',
                    fontSize: 28,
                  ),
                ),
                SizedBox(height: 15),
                GestureDetector(
                  onTap: () async {
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
                      ),
                    );

                    Future.delayed(Duration(seconds: 1), () {
                      setState(() {
                        _puckCountUpdating = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: new Text('# of pucks updated successfully!'),
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
                              child: CircularProgressIndicator(),
                            )
                          : preferences.puckCount != _currentShotCount
                              ? Text(
                                  "Update # of pucks you have from ${preferences.puckCount} to $_currentShotCount",
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
                SizedBox(
                  height: 5,
                ),
                GestureDetector(
                  onLongPress: () async {
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
                  width: MediaQuery.of(context).size.width - 150,
                  child: TextButton(
                    onPressed: () {
                      Shots shots = Shots(DateTime.now(), _selectedShotType, _currentShotCount);
                      setState(() {
                        _shots.insert(0, shots);
                      });
                    },
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all(EdgeInsets.all(10)),
                      backgroundColor: MaterialStateProperty.all(Colors.green.shade600),
                    ),
                  ),
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
                SizedBox(
                  height: 5,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 15,
                      child: _shots.length < 1
                          ? Container()
                          : TextButton(
                              onPressed: () async {
                                if (_shots.length < 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: new Text('You haven\'t taken any shots yet.'),
                                      duration: Duration(milliseconds: 1500),
                                    ),
                                  );
                                } else {
                                  await saveShootingSession(_shots).then((success) {
                                    sessionService.reset();
                                    widget.sessionPanelController.close();
                                    this.reset();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: new Text('Shooting session saved!'),
                                        duration: Duration(milliseconds: 1200),
                                      ),
                                    );
                                  }).onError((error, stackTrace) {
                                    print(error);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: new Text('There was an error saving your shooting session :('),
                                        duration: Duration(milliseconds: 1500),
                                      ),
                                    );
                                  });
                                }
                              },
                              child: Text(
                                "Finish".toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'NovecentoSans',
                                  fontSize: 20,
                                ),
                              ),
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(Theme.of(context).primaryColor),
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

  List<ListTile> _buildShotsList(BuildContext context, List<Shots> shots) {
    List<ListTile> list = [];

    shots.asMap().forEach((i, s) {
      ListTile tile = ListTile(
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
        trailing: IconButton(
          onPressed: () {
            setState(() {
              _shots.removeAt(i);
            });
          },
          icon: Icon(
            Icons.remove,
            color: Theme.of(context).primaryColor,
          ),
        ),
      );

      list.add(tile);
    });

    return list;
  }
}
