import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SipanIcon extends StatelessWidget {
  const SipanIcon(this.name, {super.key, this.size = 22, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ??
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
    );
  }
}
