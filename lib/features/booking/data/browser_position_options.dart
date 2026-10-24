/// W3C PositionOptions use milliseconds, including for watchPosition.
class BrowserPositionOptions {
  const BrowserPositionOptions({required this.timeout});
  final Duration timeout;
  int get timeoutMilliseconds => timeout.inMilliseconds;
  int get maximumAgeMilliseconds => 0;
}
