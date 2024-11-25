import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BusTypeIcon extends StatelessWidget {
  const BusTypeIcon.double({
    super.key,
    required this.width,
    required this.height,
    required this.color,
  }) : assetPath = 'assets/images/bus-double-decker.svg';
  const BusTypeIcon.bendy({
    super.key,
    required this.width,
    required this.height,
    required this.color,
  }) : assetPath = 'assets/images/bus-articulated-front.svg';

  final String assetPath;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
