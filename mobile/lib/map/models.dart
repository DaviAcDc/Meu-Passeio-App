import 'package:google_maps_flutter/google_maps_flutter.dart';

enum TransportMode { walk, car, moto }

extension TransportModeX on TransportMode {
  String get label => switch (this) {
        TransportMode.walk => 'A pé',
        TransportMode.car => 'Carro',
        TransportMode.moto => 'Moto',
      };
}

const _categoryLabels = {
  'restaurante': 'Restaurante',
  'cafe': 'Café',
  'artesanato': 'Artesanato',
  'hotel': 'Hospedagem',
  'calcados': 'Calçados',
  'roupas': 'Roupas',
  'casarao': 'Casarão histórico',
  'apoio': 'Apoio ao turista',
};

/// Ponto de interesse (loja, casarão ou ponto de apoio).
class Poi {
  final String type; // store | mansion | safe_zone
  final int id;
  final String name;
  final double lat;
  final double lng;
  final String category;
  final String description;
  final String address;
  final String? imageUrl;
  final bool? isOpen;
  final String? hours;
  final bool sponsored;

  const Poi({
    required this.type,
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.category,
    required this.description,
    required this.address,
    this.imageUrl,
    this.isOpen,
    this.hours,
    this.sponsored = false,
  });

  factory Poi.fromJson(Map<String, dynamic> j) => Poi(
        type: j['type'] as String,
        id: j['id'] as int,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        category: (j['category'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        imageUrl: j['image_url'] as String?,
        isOpen: j['is_open'] as bool?,
        hours: j['hours'] as String?,
        sponsored: j['is_sponsored'] == true,
      );

  LatLng get pos => LatLng(lat, lng);
  String get key => '$type-$id';
  String get categoryLabel => _categoryLabels[category] ?? 'Local';
}

class ModeRoute {
  final int distanceM;
  final int durationS;
  final List<LatLng> polyline;

  const ModeRoute({required this.distanceM, required this.durationS, required this.polyline});

  factory ModeRoute.fromJson(Map<String, dynamic> j) => ModeRoute(
        distanceM: (j['distance_m'] as num).round(),
        durationS: (j['duration_s'] as num).round(),
        polyline: [
          for (final p in j['polyline'] as List)
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())
        ],
      );
}

class RouteInfo {
  final String source; // google | estimate
  final ModeRoute walk;
  final ModeRoute car;
  final ModeRoute moto;

  const RouteInfo({required this.source, required this.walk, required this.car, required this.moto});

  bool get isEstimate => source != 'google';

  ModeRoute of(TransportMode m) => switch (m) {
        TransportMode.walk => walk,
        TransportMode.car => car,
        TransportMode.moto => moto,
      };

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
        source: j['source'] as String,
        walk: ModeRoute.fromJson(j['walk'] as Map<String, dynamic>),
        car: ModeRoute.fromJson(j['car'] as Map<String, dynamic>),
        moto: ModeRoute.fromJson(j['moto'] as Map<String, dynamic>),
      );
}

class Weather {
  final bool available;
  final int tempC;
  final int tempF;
  final String label;
  final String icon;

  const Weather({this.available = false, this.tempC = 0, this.tempF = 0, this.label = '', this.icon = ''});

  factory Weather.fromJson(Map<String, dynamic> j) => j['available'] == true
      ? Weather(
          available: true,
          tempC: j['temp_c'] as int,
          tempF: j['temp_f'] as int,
          label: j['label'] as String,
          icon: j['icon'] as String,
        )
      : const Weather();
}

class Trip {
  final String id;
  final String updateToken;
  const Trip(this.id, this.updateToken);
}

String fmtDistance(num meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}

String fmtDuration(num seconds) {
  final min = (seconds / 60).round();
  if (min < 1) return '< 1 min';
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}min';
}
