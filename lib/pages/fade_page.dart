import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FadePage<T> extends CustomTransitionPage<T> {
  const FadePage({
    required super.child,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
  }) : super(
          transitionsBuilder: _transitionsBuilder,
          transitionDuration: const Duration(milliseconds: 250),
          maintainState: true,
          barrierColor: null,
          barrierLabel: null,
        );

  static Widget _transitionsBuilder(
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      FadeTransition(
        opacity: CurvedAnimation(
            parent: animation,
            curve: animation.status == AnimationStatus.forward
                ? const Interval(0, 0.75)
                : const Interval(0.9, 1)),
        child: child,
      );
}
