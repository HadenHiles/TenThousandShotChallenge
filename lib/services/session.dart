import 'dart:async';
import 'package:flutter/material.dart';

class SessionService extends ChangeNotifier {
  Stopwatch? _watch;
  Timer? _timer;

  Duration get currentDuration => _currentDuration;
  Duration _currentDuration = Duration.zero;

  bool get isRunning => _timer != null;
  bool get isPaused => !_watch!.isRunning;

  SessionService() {
    _watch = Stopwatch();
  }

  void _onTick(Timer timer) {
    _currentDuration = _watch!.elapsed;

    // notify all listening widgets
    notifyListeners();
  }

  void start() {
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    _watch!.start();

    notifyListeners();
  }

  void resume() {
    if (isPaused) {
      _watch!.start();
      _currentDuration = _watch!.elapsed;
      notifyListeners();
    }
  }

  void pause() {
    if (!isPaused) {
      _watch!.stop();
      _currentDuration = _watch!.elapsed;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _watch!.stop();
    _currentDuration = _watch!.elapsed;

    notifyListeners();
  }

  void reset() {
    stop();
    _watch!.reset();
    _currentDuration = Duration.zero;

    notifyListeners();
  }

  static SessionService? of(BuildContext context) {
    var provider = context.dependOnInheritedWidgetOfExactType(aspect: SessionServiceProvider) as SessionServiceProvider;
    return provider.service;
  }
}

class SessionServiceProvider extends InheritedWidget {
  const SessionServiceProvider({super.key, this.service, required super.child});

  final SessionService? service;

  @override
  bool updateShouldNotify(SessionServiceProvider oldWidget) => service != oldWidget.service;
}
