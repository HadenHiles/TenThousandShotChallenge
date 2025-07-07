import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();
  final TextEditingController _puckCountTextFieldController = TextEditingController(text: preferences?.puckCount.toString());
  final TextEditingController _targetDateTextFieldController = TextEditingController(text: DateFormat('MMMM d, y').format(preferences!.targetDate!));

  bool? _darkMode = preferences?.darkMode;

  DateTime? _targetDate;
  int? _shotsPerDay;

  Future<void> _onIntroEnd(dynamic context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('intro_shown', true);
    // Save all intro preferences at once
    prefs.setBool('dark_mode', _darkMode ?? false);
    prefs.setInt('puck_count', int.tryParse(_puckCountTextFieldController.text) ?? 25);
    prefs.setString('target_date', DateFormat('yyyy-MM-dd').format(_targetDate ?? DateTime.now().add(const Duration(days: 100))));
    preferences?.darkMode = _darkMode;
    preferences?.puckCount = int.tryParse(_puckCountTextFieldController.text) ?? 25;
    preferences?.targetDate = _targetDate;
    if (context.mounted) {
      Provider.of<PreferencesStateNotifier>(context, listen: false).updateSettings(preferences);
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) {
        return user != null
            ? const Navigation(
                tabId: 'team',
              )
            : const Login();
      }),
    );
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset('assets/images/$assetName', width: width);
  }

  @override
  void initState() {
    super.initState();

    _shotsPerDay = 100;
    _targetDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100);
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 22.0, color: Color.fromRGBO(255, 255, 255, 0.9));

    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 32.0,
        fontFamily: 'NovecentoSans',
        color: Colors.white,
      ),
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Color(0xffCC3333),
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: introKey,
      globalBackgroundColor: const Color(0xffcc3333),
      pages: [
        PageViewModel(
          title: "Take the 10,000 shot challenge".toUpperCase(),
          body: "See how much you can improve",
          image: _buildImage('logo-small.png', MediaQuery.of(context).size.width * 0.7),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Track your progress".toUpperCase(),
          body: "It's important to work on all different types of shots!",
          image: _buildImage('progress.png', MediaQuery.of(context).size.width * 0.9),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Challenge your teammates".toUpperCase(),
          body: "View eachother's shooting sessions, and see who can reach 10,000 first!",
          image: Icon(
            Icons.people_rounded,
            size: MediaQuery.of(context).size.width * 0.5,
            color: Colors.white,
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Light or Dark theme?".toUpperCase(),
          bodyWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Transform.scale(
                          scale: _darkMode! ? 1 : 1.2,
                          child: TextButton(
                            onPressed: () async {
                              setState(() {
                                _darkMode = false;
                              });
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(Colors.white),
                            ),
                            child: Text(
                              "Light".toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 24,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _darkMode! ? 1.2 : 1,
                          child: TextButton(
                            onPressed: () async {
                              setState(() {
                                _darkMode = true;
                              });
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(const Color(0xff1A1A1A)),
                            ),
                            child: Text(
                              "Dark".toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 24,
                                color: Color.fromRGBO(255, 255, 255, 0.75),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    const Text(
                      'You can change this later',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          image: Icon(
            Icons.brightness_4,
            size: MediaQuery.of(context).size.width * 0.5,
            color: preferences!.darkMode! ? Colors.black : Colors.white,
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "How many pucks do you have?".toUpperCase(),
          bodyWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _puckCountTextFieldController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 28,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (value) async {
                        setState(() {}); // Just update local state
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    const Text(
                      'You can change this later',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          image: Container(
            margin: const EdgeInsets.only(bottom: 30),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  FontAwesomeIcons.hockeyPuck,
                  size: MediaQuery.of(context).size.width * 0.25,
                  color: Colors.white,
                ),
                // Top Left
                const Positioned(
                  left: -25,
                  top: -25.0,
                  child: Icon(
                    FontAwesomeIcons.hockeyPuck,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                // Bottom Left
                const Positioned(
                  left: -35,
                  bottom: -30.0,
                  child: Icon(
                    FontAwesomeIcons.hockeyPuck,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                // Top right
                const Positioned(
                  right: -30,
                  top: -35.0,
                  child: Icon(
                    FontAwesomeIcons.hockeyPuck,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                // Bottom right
                const Positioned(
                  right: -30,
                  bottom: -25.0,
                  child: Icon(
                    FontAwesomeIcons.hockeyPuck,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "I will take $_shotsPerDay shots per day to complete 10,000 shots by".toUpperCase(),
          bodyWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    TextFormField(
                      controller: _targetDateTextFieldController,
                      style: const TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 28,
                        color: Colors.white,
                      ),
                      readOnly: true,
                      textAlign: TextAlign.center,
                      onTap: () {
                        DatePicker.showDatePicker(
                          context,
                          showTitleActions: true,
                          minTime: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1),
                          maxTime: DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day),
                          onChanged: (date) {
                            _targetDateTextFieldController.text = DateFormat('MMMM d, y').format(date);

                            int daysRemaining = date.difference(DateTime.now()).inDays;

                            if (daysRemaining <= 1) {
                              setState(() {
                                _shotsPerDay = 10000;
                              });
                            } else {
                              setState(() {
                                _shotsPerDay = (10000 / daysRemaining).round();
                              });
                            }
                          },
                          onConfirm: (date) async {
                            setState(() {
                              _targetDate = date;
                            });
                            _targetDateTextFieldController.text = DateFormat('MMMM d, y').format(date);
                            int daysRemaining = date.difference(DateTime.now()).inDays;
                            if (daysRemaining <= 1) {
                              setState(() {
                                _shotsPerDay = 10000;
                              });
                            } else {
                              setState(() {
                                _shotsPerDay = (10000 / daysRemaining).round();
                              });
                            }
                          },
                          currentTime: _targetDate,
                          locale: LocaleType.en,
                        );
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    const Text(
                      'You can change this later',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          image: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AutoSizeText(
                "Set your goal".toUpperCase(),
                maxFontSize: 44,
                maxLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontFamily: "NovecentoSans",
                ),
              ),
              const SizedBox(
                height: 40,
              ),
              Icon(
                FontAwesomeIcons.calendarCheck,
                size: MediaQuery.of(context).size.width * 0.5,
                color: Colors.white,
              ),
            ],
          ),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      //onSkip: () => _onIntroEnd(context), // You can override onSkip callback
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      //rtl: true, // Display as right-to-left
      skip: Text(
        'Skip'.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      next: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white,
      ),
      done: Text(
        'Done'.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: kIsWeb ? const EdgeInsets.all(12.0) : const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        color: Color(0xFFBDBDBD),
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
      dotsContainerDecorator: const ShapeDecoration(
        color: Color(0xffa32929),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
    );
  }
}
