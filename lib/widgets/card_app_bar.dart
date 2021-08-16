// @dart=2.9

import 'package:flutter/material.dart';

class CardAppBar extends StatelessWidget {
  const CardAppBar({
    this.onTap,
    this.leading,
    this.title,
    this.actions,
    this.elevation,
  });

  final Widget leading;
  final Widget title;
  final void Function() onTap;
  final List<Widget> actions;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      type: MaterialType.card,
      elevation: elevation ?? 0,
      shape: Theme.of(context).cardTheme.shape,
      child: InkWell(
        customBorder: Theme.of(context).cardTheme.shape,
        onTap: onTap,
        child: Row(
          children: <Widget>[
            if (leading != null) leading,
            Expanded(
              child: title,
            ),
            if (actions != null) ...actions,
          ],
        ),
      ),
    );
  }
}
