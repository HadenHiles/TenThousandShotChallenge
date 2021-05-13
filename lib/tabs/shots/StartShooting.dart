import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/tabs/shots/widgets/ShotButton.dart';
import 'package:tenthousandshotchallenge/widgets/BasicTitle.dart';

class StartShooting extends StatefulWidget {
  StartShooting({Key key}) : super(key: key);

  @override
  _StartShootingState createState() => _StartShootingState();
}

class _StartShootingState extends State<StartShooting> {
  // Static variables
  final _shotCountFormKey = GlobalKey<FormState>();
  final TextEditingController shotCountTextField = TextEditingController(text: preferences.puckCount.toString());

  // Stateful variables
  String _selectedShotType = 'wrist';
  int _currentShotCount = preferences.puckCount;

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
                  title: BasicTitle(title: "Start Shooting!"),
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              actions: [],
            ),
          ];
        },
        body: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "# of Shots".toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontFamily: 'NovecentoSans',
                        fontSize: 28,
                      ),
                    ),
                    SizedBox(height: 25),
                    Text(
                      "Long press for numpad",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Divider(
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
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          minLines: 1,
                          maxLines: 1,
                          autoFocus: true,
                          obscureText: false,
                          obscuringCharacter: '•',
                          textCapitalization: TextCapitalization.words,
                          keyboardType: TextInputType.number,
                        ).then((value) {
                          if (value != null && int.parse(value) > 0) {
                            setState(() {
                              _currentShotCount = int.parse(value);
                            });
                          }
                        });
                      },
                      child: NumberPicker(
                        value: _currentShotCount,
                        minValue: 1,
                        maxValue: 1000,
                        step: 1,
                        itemHeight: 100,
                        axis: Axis.horizontal,
                        haptics: true,
                        infiniteLoop: true,
                        onChanged: (value) {
                          setState(() {
                            _currentShotCount = value;
                            shotCountTextField.text = value.toString();
                          });
                        },
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 2),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    Text(
                      "Shot Type".toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontFamily: 'NovecentoSans',
                        fontSize: 28,
                      ),
                    ),
                    SizedBox(height: 25),
                    Row(
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
                    SizedBox(
                      height: 25,
                    ),
                    SizedBox(
                      height: 35,
                      width: 150,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          primary: Colors.white,
                          backgroundColor: Theme.of(context).buttonColor,
                        ),
                        onPressed: () {
                          if (_shotCountFormKey.currentState.validate()) {}
                        },
                        child: Text('Save'.toUpperCase()),
                      ),
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
}
