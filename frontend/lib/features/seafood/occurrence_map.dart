import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/seafood.dart';

/// Geographic map of retrieved OBIS points. Tiles are Carto/OSM; dots are not
/// invented.
class OccurrenceMap extends StatelessWidget {
  const OccurrenceMap({super.key, required this.points});

  final List<OccurrencePoint> points;

  static const String _tileUrl = AppConstants.cartoBasemapsKey.isEmpty
      ? 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'
      : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'
            '?key=${AppConstants.cartoBasemapsKey}';

  @override
  Widget build(BuildContext context) {
    final List<LatLng> coords = <LatLng>[
      for (final OccurrencePoint point in points)
        LatLng(point.latitude, point.longitude),
    ];
    if (coords.isEmpty) {
      return const SizedBox.shrink();
    }

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: _bounds(coords),
          padding: const EdgeInsets.all(28),
          maxZoom: 5,
          minZoom: 2,
        ),
        minZoom: 2,
        maxZoom: 8,
        backgroundColor: const Color(0xFFE8F4F6),
        interactionOptions: const InteractionOptions(
          flags:
              InteractiveFlag.drag |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.scrollWheelZoom |
              InteractiveFlag.doubleTapZoom,
        ),
        keepAlive: true,
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: _tileUrl,
          userAgentPackageName: 'sukaseafood',
        ),
        CircleLayer<Object>(
          circles: <CircleMarker<Object>>[
            for (final LatLng point in coords)
              CircleMarker<Object>(
                point: point,
                radius: 4,
                color: const Color(0xFF1AA37A),
                borderStrokeWidth: 1,
                borderColor: Colors.white,
              ),
          ],
        ),
      ],
    );
  }

  static LatLngBounds _bounds(List<LatLng> coords) {
    if (coords.length == 1) {
      final LatLng center = coords.first;
      return LatLngBounds(
        LatLng(center.latitude - 8, center.longitude - 10),
        LatLng(center.latitude + 8, center.longitude + 10),
      );
    }
    return LatLngBounds.fromPoints(coords);
  }
}

/// Legend row used under the map.
class OccurrenceMapLegend extends StatelessWidget {
  const OccurrenceMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.circle, size: 10, color: AppColors.tealDark),
            SizedBox(width: 6),
            Text('Species observed', style: TextStyle(fontSize: 12)),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Map © OpenStreetMap, © CARTO. Points from OBIS.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
