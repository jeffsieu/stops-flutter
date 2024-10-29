import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/routes/initial_fetch_data_route.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/routes/saved_route.dart';

part 'router.g.dart';

@riverpod
Future<bool> isFullyCached(IsFullyCachedRef ref) async {
  final cacheProgress = await ref.read(cachedDataProgressProvider.future);
  final isFullyCached = cacheProgress == 1.0;

  return isFullyCached;
}

@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    routes: $appRoutes,
    redirect: (context, state) async {
      final isFullyCached = await ref.watch(isFullyCachedProvider.future);

      if (!isFullyCached) {
        return InitialFetchDataRoute().location;
      }

      return null;
    },
    initialLocation: SavedRoute().location,
  );
}
