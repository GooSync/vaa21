import 'package:flutter/material.dart';
import 'package:page_transition_cube/view_pager/transformer_page_view.dart';
import 'package:vector_math/vector_math_64.dart';

class CubeTransformer extends PageTransformer {
  final double _scale;
  final double _fade;

  CubeTransformer({double fade: 0.4, double scale: 0.85})
      : _fade = fade,
        _scale = scale;

  @override
  Widget transform(Widget item, TransformInfo info) {
    double position = info.position;
    double pivotX = 0.0;
    if (position < 0 && position >= -1) pivotX = info.width;

    return Transform(
      transform: _calcMatrix(position),
      origin: Offset(pivotX, info.height / 2),
      child: Opacity(opacity: _calcArgument(position, _fade), child: Transform.scale(scale: _calcArgument(position, _scale), child: item)),
    );
  }

  Matrix4 _calcMatrix(double position) => Matrix4.identity()
    ..setEntry(3, 2, -0.001)
    ..rotate(Vector3(0.0, 2.0, 0.0), position * 1.5);

  double _calcArgument(double position, double arg) => arg + (1 - position.abs()) * (1 - arg);
}
