import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  const InfoCard(
      {super.key, required this.icon, required this.title, this.color});

  final Widget icon;
  final Widget title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [icon, const SizedBox(width: 16.0), title],
      ),
    );
  }
}
