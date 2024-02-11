import 'package:flutter/material.dart';

class OutlineTitledContainer extends StatelessWidget {
  OutlineTitledContainer({
    super.key,
    this.title,
    this.body,
    this.collapsedTitlePadding = EdgeInsets.zero,
    this.titlePadding = 4,
    this.titleBorderGap = 4,
    this.buildBody = true,
    this.backgroundColor = Colors.transparent,
    required this.topOffset,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.linear,
    this.showGap = true,
    List<Widget>? childrenBelowTitle,
  })  : childrenBelowTitle = childrenBelowTitle ?? [];

  final double titlePadding;
  final double titleBorderGap;
  final double topOffset;
  final Widget? title;
  final Widget? body;
  final List<Widget> childrenBelowTitle;
  final bool buildBody;
  final EdgeInsetsGeometry collapsedTitlePadding;
  final Color backgroundColor;
  final Duration duration;
  final Curve curve;
  final bool showGap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: Stack(
        children: [
          AnimatedContainer(
            alignment: Alignment.topCenter,
            duration: duration,
            curve: curve,
            padding: EdgeInsets.only(top: buildBody ? topOffset : 0),
            child: Ink(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: const BorderRadius.all(
                  Radius.circular(8.0),
                ),
              ),
              child: AnimatedSize(
                alignment: Alignment.topCenter,
                duration: duration,
                curve: curve,
                child: Stack(
                  children: [
                    if (body != null)
                      Visibility(
                        visible: buildBody,
                        maintainState: true,
                        child: body!,
                      ),
                    Visibility(
                      maintainState: true,
                      visible: !buildBody,
                      child: Padding(
                        padding: collapsedTitlePadding,
                        child: Opacity(
                          opacity: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (title != null) title!,
                              ...childrenBelowTitle,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedContainer(
              duration: duration,
              curve: curve,
              padding: buildBody ? EdgeInsets.zero : collapsedTitlePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: titlePadding - titleBorderGap),
                    child: Ink(
                      color: showGap
                          ? Theme.of(context).scaffoldBackgroundColor
                          : Colors.transparent,
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: titleBorderGap),
                        child: title,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: titlePadding),
                    child: Column(
                      children: [
                        ...childrenBelowTitle,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
