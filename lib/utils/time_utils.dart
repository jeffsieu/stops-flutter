int getMinutesFromNow(DateTime time) {
  return (time.difference(DateTime.now()).inMilliseconds / 60000).round();
}