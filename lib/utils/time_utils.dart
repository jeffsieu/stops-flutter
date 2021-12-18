

extension TimeUtils on DateTime {
  int getMinutesFromNow() {
    return (difference(DateTime.now()).inMilliseconds / 60000).ceil();
  }

  int getMinutesUntil(DateTime time) {
    return (time.difference(this).inMilliseconds / 60000).ceil();
  }
}
