import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

const _earthR = 6371000.0;

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

double haversineM(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthR * math.asin(math.sqrt(h));
}

/// Rumo (0–360°) de a para b.
double bearingDeg(LatLng a, LatLng b) {
  final dLng = _rad(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(_rad(b.latitude));
  final x = math.cos(_rad(a.latitude)) * math.sin(_rad(b.latitude)) -
      math.sin(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

LatLng lerpLatLng(LatLng a, LatLng b, double t) =>
    LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);

bool insideBounds(LatLng p, LatLng sw, LatLng ne) =>
    p.latitude >= sw.latitude &&
    p.latitude <= ne.latitude &&
    p.longitude >= sw.longitude &&
    p.longitude <= ne.longitude;

/// Quadrado ao redor de [c] (≈ "pegada" do prédio), com meia-lateral em metros.
/// É uma aproximação visual; pegadas reais viriam de dados do OpenStreetMap/IPHAN.
List<LatLng> squareFootprint(LatLng c, double halfM) {
  final dLat = halfM / 111320;
  final dLng = halfM / (111320 * math.cos(_rad(c.latitude)));
  return [
    LatLng(c.latitude - dLat, c.longitude - dLng),
    LatLng(c.latitude - dLat, c.longitude + dLng),
    LatLng(c.latitude + dLat, c.longitude + dLng),
    LatLng(c.latitude + dLat, c.longitude - dLng),
  ];
}

LatLngBounds boundsOf(Iterable<LatLng> pts) {
  var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
  for (final p in pts) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
}

/// Trajeto "densificado" (um ponto a cada ~[stepM] metros) para simular e acompanhar a navegação.
class RoutePath {
  final List<LatLng> points;
  final List<double> cumulative; // metros acumulados até cada ponto

  RoutePath._(this.points, this.cumulative);

  factory RoutePath(List<LatLng> raw, {double stepM = 5}) {
    if (raw.isEmpty) return RoutePath._(const [], const []);
    final pts = <LatLng>[raw.first];
    for (var i = 1; i < raw.length; i++) {
      final a = raw[i - 1], b = raw[i];
      final d = haversineM(a, b);
      final n = math.max(1, (d / stepM).ceil());
      for (var k = 1; k <= n; k++) {
        pts.add(lerpLatLng(a, b, k / n));
      }
    }
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum[i - 1] + haversineM(pts[i - 1], pts[i]));
    }
    return RoutePath._(pts, cum);
  }

  bool get isEmpty => points.isEmpty;
  int get lastIndex => points.length - 1;
  double get totalM => cumulative.isEmpty ? 0 : cumulative.last;

  int nearestIndex(LatLng p) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = haversineM(points[i], p);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  double remainingM(int idx) => totalM - cumulative[idx.clamp(0, lastIndex).toInt()];

  /// Rumo olhando alguns pontos à frente, para a câmera não "tremer".
  double bearingAt(int idx, {int lookAhead = 4}) {
    final a = points[idx.clamp(0, lastIndex).toInt()];
    final b = points[(idx + lookAhead).clamp(0, lastIndex).toInt()];
    if (a == b) return 0;
    return bearingDeg(a, b);
  }
}
