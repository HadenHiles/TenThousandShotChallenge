import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';

class IntroScreen extends StatefulWidget {
  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();
  final TextEditingController puckCountTextFieldController = TextEditingController(text: preferences.puckCount.toString());

  bool _darkMode = preferences.darkMode;

  Future<void> _onIntroEnd(context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('intro_shown', true);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) {
        return user != null ? Navigation() : Login();
      }),
    );
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset('assets/images/$assetName', width: width);
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 22.0, color: Color.fromRGBO(255, 255, 255, 0.9));

    const pageDecoration = const PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 32.0,
        fontFamily: 'NovecentoSans',
        color: Colors.white,
      ),
      bodyTextStyle: bodyStyle,
      descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Color(0xffCC3333),
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: introKey,
      globalBackgroundColor: Color(0xffCC33333),
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
          body: "View eachothers shooting sessions, and see who can reach 10,000 first!",
          image: Icon(
            Icons.people_rounded,
            size: MediaQuery.of(context).size.width * 0.5,
            color: Colors.white,
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
                      controller: puckCountTextFieldController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 28,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (value) async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        prefs.setInt('puck_count', int.parse(value));
                        preferences.puckCount = int.parse(value);
                      },
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Text(
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
            margin: EdgeInsets.only(bottom: 30),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  FontAwesomeIcons.hockeyPuck,
                  size: MediaQuery.of(context).size.width * 0.25,
                  color: Colors.white,
                ),
                // Top Left
                Positioned(
                  left: -25,
                  top: -25.0,
                  child: Icon(
                    FontAwesomeIcons.hockeyPuck,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                // Bottom Left
                Positioned(
                  left: -35,
                  bottom: -30.0,
                  child: Icon(
                    FontAwesomeIcons.hockeyPuck,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                // Top right
                Positioned(
                  right: -30,
                  top: -35.0,
                  child: Icon(
                    FontAwesomeIcons.hockeyPuck,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                // Bottom right
                Positioned(
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
                          scale: _darkMode ? 1 : 1.2,
                          child: TextButton(
                            onPressed: () async {
                              setState(() {
                                _darkMode = false;
                              });

                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              prefs.setBool('dark_mode', false);
                              preferences.darkMode = false;
                            },
                            child: Text(
                              "Light".toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 24,
                                color: Colors.black54,
                              ),
                            ),
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Colors.white),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _darkMode ? 1.2 : 1,
                          child: TextButton(
                            onPressed: () async {
                              setState(() {
                                _darkMode = true;
                              });

                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              prefs.setBool('dark_mode', true);
                              preferences.darkMode = true;
                            },
                            child: Text(
                              "Dark".toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 24,
                                color: Color.fromRGBO(255, 255, 255, 0.75),
                              ),
                            ),
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Color(0xff1A1A1A)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Text(
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
            color: Colors.white,
          ),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      //onSkip: () => _onIntroEnd(context), // You can override onSkip callback
      showSkipButton: true,
      skipFlex: 0,
      nextFlex: 0,
      //rtl: true, // Display as right-to-left
      skip: Text(
        'Skip'.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
        ),
      ),
      next: Icon(Icons.arrow_forward_ios),
      done: Text(
        'Done'.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NovecentoSans',
          fontSize: 20,
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
