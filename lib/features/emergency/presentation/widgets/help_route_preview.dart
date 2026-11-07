import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/common/illustrated_streets_painter.dart';

const _origin = Offset(.21, .73);
const _destination = Offset(.78, .24);

class HelpRoutePreview extends StatelessWidget {
  const HelpRoutePreview({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Mapa ilustrativo del recorrido entre dos puntos ficticios',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AspectRatio(
        aspectRatio: 1.55,
        child: LayoutBuilder(
          builder: (context, bounds) => Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: IllustratedStreetsPainter()),
              const CustomPaint(painter: _RouteLine()),
              for (final (point, label, icon, color) in const [
                (
                  _origin,
                  'Origen de ejemplo',
                  Icons.trip_origin,
                  AppColors.map,
                ),
                (_destination, 'Destino de ejemplo', Icons.flag, AppColors.sos),
              ])
                Positioned(
                  left: bounds.maxWidth * point.dx - 24,
                  top: bounds.maxHeight * point.dy - 24,
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: label,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(label),
                        content: const Text(
                          'Punto ficticio del recorrido ilustrativo.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                    icon: CircleAvatar(
                      backgroundColor: color,
                      child: Icon(icon, color: Colors.white, size: 19),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RouteLine extends CustomPainter {
  const _RouteLine();
  @override
  void paint(Canvas canvas, Size size) {
    const points = [
      _origin,
      Offset(.34, .65),
      Offset(.38, .5),
      Offset(.52, .49),
      Offset(.64, .34),
      _destination,
    ];
    final path = Path()
      ..addPolygon([
        for (final p in points) Offset(p.dx * size.width, p.dy * size.height),
      ], false);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.map
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RouteLine oldDelegate) => false;
}
