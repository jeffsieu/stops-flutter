import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/models/bus.dart';
import '../database.dart';

import 'notification_utils.dart';

part 'followed_buses.g.dart';

const String _isBusFollowedKey = 'BUS_FOLLOW';

final _database = StopsDatabase();

@riverpod
class FollowedBuses extends _$FollowedBuses {
  @override
  Future<List<Bus>> build() async {
    return await _getFollowedBuses();
  }

  Future<void> followBus(
      {required String busStopCode, required String busServiceNumber}) async {
    await _followBus(
        busStopCode: busStopCode, busServiceNumber: busServiceNumber);
    ref.invalidateSelf();
  }

  Future<void> unfollowBus(
      {required String busStopCode, required String busServiceNumber}) async {
    await _unfollowBus(
        busStopCode: busStopCode, busServiceNumber: busServiceNumber);
    ref.invalidateSelf();
  }

  Future<void> unfollowAllBuses() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_isBusFollowedKey);
    ref.invalidateSelf();
  }
}

Future<List<Bus>> _getFollowedBuses() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    return <Bus>[];
  }
  final followedBuses = <Bus>[];
  final followedBusesRaw = prefs.getStringList(_isBusFollowedKey)!;

  for (var i = 0; i < followedBusesRaw.length; i++) {
    final tokens = followedBusesRaw[i].split(' ');
    final busStop = await _database.getCachedBusStopWithCode(tokens[0]);
    final busService = await _database.getCachedBusService(tokens[1]);
    followedBuses.add(Bus(busStop: busStop, busService: busService));
  }

  return followedBuses;
}

Future<void> _followBus(
    {required String busStopCode, required String busServiceNumber}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    prefs.setStringList(_isBusFollowedKey, <String>[]);
  }
  final followedBuses = prefs.getStringList(_isBusFollowedKey)!;

  final key = _followerKey(busStopCode, busServiceNumber);
  followedBuses.add(key);

  prefs.setStringList(_isBusFollowedKey, followedBuses);

  // updateNotifications();
}

Future<void> _unfollowBus(
    {required String busStopCode, required String busServiceNumber}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    prefs.setStringList(_isBusFollowedKey, <String>[]);
  }

  final followedBuses = prefs.getStringList(_isBusFollowedKey)!;

  final key = _followerKey(busStopCode, busServiceNumber);
  followedBuses.remove(key);

  prefs.setStringList(_isBusFollowedKey, followedBuses);

  // Update followed buses stream
  // updateNotifications();
}

@riverpod
Future<bool> isBusFollowed(IsBusFollowedRef ref,
    {required String busStopCode, required String busServiceNumber}) async {
  final followedBuses = await ref.watch(followedBusesProvider.future);

  return followedBuses.any((bus) =>
      bus.busStop.code == busStopCode &&
      bus.busService.number == busServiceNumber);
}

String _followerKey(String stop, String bus) => '$stop $bus';
