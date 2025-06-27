import 'package:flutter/material.dart';

class CardAppBar extends StatelessWidget {
  const CardAppBar({
    super.key,
    this.onTap,
    this.leading,
    this.title,
    this.bottom,
    this.actions,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? bottom;
  final void Function()? onTap;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceBright,
      clipBehavior: Clip.antiAlias,
      shape: Theme.of(context).cardTheme.shape,
      child: InkWell(
        customBorder: Theme.of(context).cardTheme.shape,
        onTap: onTap,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
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
      ),
    );
  }
}
