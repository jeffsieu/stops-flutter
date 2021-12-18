import 'package:flutter/material.dart';

class CrossedIcon extends StatelessWidget {
  const CrossedIcon({Key? key, required this.icon}) : super(key: key);

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        icon,
        Positioned(
          right: 0.0,
          bottom: 0.0,
          child: Icon(Icons.clear_rounded,
              size: 16.0, color: Theme.of(context).errorColor),
        ),
      ],
    );
  }
}
