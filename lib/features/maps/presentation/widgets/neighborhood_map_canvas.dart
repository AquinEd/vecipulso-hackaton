import 'package:flutter/material.dart';

import '../../../../shared/widgets/common/illustrated_streets_painter.dart';
import '../../models/community_map_marker.dart';

class NeighborhoodMapCanvas extends StatelessWidget {
  const NeighborhoodMapCanvas({
    super.key,
    required this.markers,
    required this.onSelect,
  });
  final List<CommunityMapMarker> markers;
  final ValueChanged<CommunityMapMarker> onSelect;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: AspectRatio(
      aspectRatio: 740 / 920,
      child: LayoutBuilder(
        builder: (context, size) => Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: IllustratedStreetsPainter()),
            for (final marker in markers)
              Positioned(
                left: (size.maxWidth * marker.relativeX - 24).clamp(
                  0,
                  size.maxWidth - 48,
                ),
                top: (size.maxHeight * marker.relativeY - 24).clamp(
                  0,
                  size.maxHeight - 48,
                ),
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: '${marker.title} · ${marker.category.label}',
                  padding: EdgeInsets.zero,
                  icon: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: marker.category.color,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        marker.category.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  onPressed: () => onSelect(marker),
                ),
              ),
            if (markers.isEmpty)
              Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      liveRegion: true,
                      child: const Text(
                        'No hay coincidencias. Cambia la búsqueda o los filtros.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
