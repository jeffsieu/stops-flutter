import 'package:flutter/material.dart';

class CardAppBar extends StatelessWidget {
  const CardAppBar({
    Key? key,
    this.onTap,
    this.leading,
    this.title,
    this.bottom,
    this.actions,
    this.elevation,
  }) : super(key: key);

  final Widget? leading;
  final Widget? title;
  final Widget? bottom;
  final void Function()? onTap;
  final List<Widget>? actions;
  final double? elevation;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (leading != null) leading!,
                Expanded(
                  child: title!,
                ),
                if (actions != null) ...actions!,
              ],
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}
