import 'package:flutter/material.dart';

class HomePageContentSwitcher extends StatelessWidget {
  const HomePageContentSwitcher(
      {Key? key, required this.scrollController, required this.child})
      : super(key: key);
  final ScrollController scrollController;
  final Widget child;

  static const Duration animationDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: animationDuration,
      child: child,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
          alignment: Alignment.topCenter,
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool entering = child.key == this.child.key;
        if (entering) {
          late void Function() listener;
          listener = () {
            if (animation.value > 0.5) {
              try {
                scrollController.jumpTo(0.001);
              } catch (_) {} finally {
                animation.removeListener(listener);
              }
            }
          };
          animation.addListener(listener);
        }

        return SlideTransition(
          position: CurvedAnimation(
                  parent: animation,
                  curve: entering ? Curves.easeOutCubic : Curves.easeOutCubic)
              .drive(
                  Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)),
          child: FadeTransition(
            opacity: CurvedAnimation(
                parent: animation, curve: const Interval(0.5, 1)),
            child: child,
          ),
        );
      },
    );
  }
}
