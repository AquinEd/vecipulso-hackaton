import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppAssetImage extends StatelessWidget {
  const AppAssetImage({
    super.key,
    required this.path,
    this.label,
    this.width,
    this.height,
  });
  final String path;
  final String? label;
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) => path.endsWith('.svg')
      ? SvgPicture.asset(
          path,
          width: width,
          height: height,
          semanticsLabel: label,
          excludeFromSemantics: label == null,
        )
      : Image.asset(
          path,
          width: width,
          height: height,
          fit: BoxFit.contain,
          semanticLabel: label,
          excludeFromSemantics: label == null,
        );
}
