int getMinutesFromNow(String time) {
  return (DateTime.parse(time).difference(DateTime.now()).inMilliseconds / 60000).round();
}