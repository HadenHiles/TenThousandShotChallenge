import 'package:flutter/material.dart';
import 'package:intro_slider/dot_animation_enum.dart';
import 'package:intro_slider/intro_slider.dart';
import 'package:intro_slider/slide_object.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/main.dart';

class IntroScreen extends StatefulWidget {
  IntroScreen({Key key}) : super(key: key);

  @override
  IntroScreenState createState() => new IntroScreenState();
}

class IntroScreenState extends State<IntroScreen> {
  final TextEditingController puckCountTextFieldController = TextEditingController(text: preferences.puckCount.toString());

  // bool _darkMode = preferences.darkMode;

  List<Slide> slides = [];

  Function goToTab;

  @override
  void initState() {
    slides.add(
      Slide(
        widgetTitle: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              width: 360,
              child: Text(
                "Take the 10,000 shot challenge!".toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 32,
                  color: Colors.white,
                ),
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xffCC3333),
        widgetDescription: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: Text(
                "See how much you can improve",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        pathImage: "assets/images/logo.png",
      ),
    );

    slides.add(
      Slide(
        widgetTitle: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              width: 360,
              child: Text(
                "Track your progress".toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 32,
                  color: Colors.white,
                ),
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xffCC3333),
        widgetDescription: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: Text(
                "It's important to work on all different types of shots!",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        pathImage: "assets/images/progress.png",
      ),
    );

    slides.add(
      Slide(
        widgetTitle: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              width: 360,
              child: Text(
                "How many pucks do you have?".toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 32,
                  color: Colors.white,
                ),
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xffCC3333),
        widgetDescription: Column(
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
      ),
    );

    // slides.add(
    //   Slide(
    //     widgetTitle: Row(
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       mainAxisSize: MainAxisSize.max,
    //       children: [
    //         SizedBox(
    //           width: 360,
    //           child: Text(
    //             "Light or Dark Theme?".toUpperCase(),
    //             style: TextStyle(
    //               fontFamily: 'NovecentoSans',
    //               fontSize: 32,
    //               color: Colors.white,
    //             ),
    //             overflow: TextOverflow.clip,
    //             textAlign: TextAlign.center,
    //           ),
    //         ),
    //       ],
    //     ),
    //     backgroundColor: Color(0xffCC3333),
    //     widgetDescription: Column(
    //       crossAxisAlignment: CrossAxisAlignment.center,
    //       children: [
    //         SizedBox(
    //           width: 200,
    //           child: Column(
    //             children: [
    //               Row(
    //                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    //                 children: [
    //                   Transform.scale(
    //                     scale: _darkMode ? 1 : 1.2,
    //                     child: TextButton(
    //                       onPressed: () async {
    //                         setState(() {
    //                           _darkMode = false;
    //                         });

    //                         SharedPreferences prefs = await SharedPreferences.getInstance();
    //                         prefs.setBool('dark_mode', false);
    //                         preferences.darkMode = false;
    //                       },
    //                       child: Text(
    //                         "Light".toUpperCase(),
    //                         style: TextStyle(
    //                           fontFamily: 'NovecentoSans',
    //                           fontSize: 24,
    //                           color: Colors.black54,
    //                         ),
    //                       ),
    //                       style: ButtonStyle(
    //                         backgroundColor: MaterialStateProperty.all(Colors.white),
    //                       ),
    //                     ),
    //                   ),
    //                   Transform.scale(
    //                     scale: _darkMode ? 1.2 : 1,
    //                     child: TextButton(
    //                       onPressed: () async {
    //                         setState(() {
    //                           _darkMode = true;
    //                         });

    //                         SharedPreferences prefs = await SharedPreferences.getInstance();
    //                         prefs.setBool('dark_mode', true);
    //                         preferences.darkMode = true;
    //                       },
    //                       child: Text(
    //                         "Dark".toUpperCase(),
    //                         style: TextStyle(
    //                           fontFamily: 'NovecentoSans',
    //                           fontSize: 24,
    //                           color: Color.fromRGBO(255, 255, 255, 0.75),
    //                         ),
    //                       ),
    //                       style: ButtonStyle(
    //                         backgroundColor: MaterialStateProperty.all(Color(0xff1A1A1A)),
    //                       ),
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //               SizedBox(
    //                 height: 10,
    //               ),
    //               Text(
    //                 'You can change this later',
    //                 style: TextStyle(
    //                   fontFamily: 'NovecentoSans',
    //                   fontSize: 18,
    //                   color: Colors.white70,
    //                 ),
    //                 textAlign: TextAlign.center,
    //               ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //   ),
    // );

    super.initState();
  }

  void onDonePress() {
    // Back to the first tab
    navigatorKey.currentState.pushReplacement(
      MaterialPageRoute(builder: (context) {
        return user != null ? Navigation() : Login();
      }),
    );
  }

  void onTabChangeCompleted(index) {
    // Index of current tab is focused
  }

  Widget renderNextBtn() {
    return Icon(
      Icons.navigate_next,
      color: Color(0xffffffff),
      size: 35.0,
    );
  }

  Widget renderDoneBtn() {
    return Icon(
      Icons.done,
      color: Color(0xffffffff),
    );
  }

  Widget renderSkipBtn() {
    return Icon(
      Icons.skip_next,
      color: Color(0xffffffff),
    );
  }

  List<Widget> renderListCustomTabs() {
    List<Widget> tabs = [];
    for (int i = 0; i < slides.length; i++) {
      Slide currentSlide = slides[i];
      tabs.add(
        Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.only(top: 150),
          decoration: BoxDecoration(
            color: currentSlide.backgroundColor,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              currentSlide.pathImage == null
                  ? Container()
                  : GestureDetector(
                      child: Image.asset(
                        currentSlide.pathImage,
                        width: 320.0,
                        height: 320.0,
                        fit: BoxFit.contain,
                      ),
                    ),
              Container(
                child: currentSlide.widgetTitle,
                margin: EdgeInsets.only(top: 20.0),
              ),
              Container(
                child: currentSlide.widgetDescription,
                margin: EdgeInsets.only(top: 20.0),
              ),
            ],
          ),
        ),
      );
    }
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    return IntroSlider(
      // Skip button
      renderSkipBtn: this.renderSkipBtn(),
      colorSkipBtn: Color(0x33ffffff),
      highlightColorSkipBtn: Color(0xffffffff),

      // Next button
      renderNextBtn: this.renderNextBtn(),

      // Done button
      renderDoneBtn: this.renderDoneBtn(),
      onDonePress: this.onDonePress,
      colorDoneBtn: Color(0x33ffffff),
      highlightColorDoneBtn: Color(0xffffffff),

      // Dot indicator
      colorDot: Color(0xffffffff),
      sizeDot: 13.0,
      typeDotAnimation: dotSliderAnimation.SIZE_TRANSITION,

      // Tabs
      listCustomTabs: this.renderListCustomTabs(),
      backgroundColorAllSlides: Colors.white,
      refFuncGoToTab: (refFunc) {
        this.goToTab = refFunc;
      },

      // Behavior
      scrollPhysics: BouncingScrollPhysics(),

      // Show or hide status bar
      hideStatusBar: true,

      // On tab change completed
      onTabChangeCompleted: this.onTabChangeCompleted,
    );
  }
}
