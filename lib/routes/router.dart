import 'package:go_router/go_router.dart';
import 'package:stops_sg/routes/routes.dart';

final router = GoRouter(
  routes: $appRoutes,
  initialLocation: '/search',
);
