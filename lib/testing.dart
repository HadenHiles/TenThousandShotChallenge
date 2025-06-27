/// Set this to true in widget tests to disable timers and async code.
bool isTesting = false;

class TestEnv {
  final bool isTesting;
  const TestEnv({this.isTesting = false});
}
