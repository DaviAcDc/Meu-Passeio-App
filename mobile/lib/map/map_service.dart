import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core.dart';
import 'models.dart';

/// Única camada que fala com a API do mapa. As telas nunca montam URL na mão.
class MapService {
  Future<List<Poi>> pois() async {
    final data = await Api.get('/map/pois', {'types': 'store,mansion,safe_zone'}) as List;
    return [for (final j in data) Poi.fromJson(j as Map<String, dynamic>)];
  }

  Future<List<Poi>> search(String q, LatLng from) async {
    final data = await Api.get('/map/search', {
      'q': q,
      'lat': '${from.latitude}',
      'lng': '${from.longitude}',
    }) as List;
    return [for (final j in data) Poi.fromJson(j as Map<String, dynamic>)];
  }

  Future<RouteInfo> route(LatLng from, LatLng to) async {
    final j = await Api.get('/route', {
      'from_lat': '${from.latitude}',
      'from_lng': '${from.longitude}',
      'to_lat': '${to.latitude}',
      'to_lng': '${to.longitude}',
    });
    return RouteInfo.fromJson(j as Map<String, dynamic>);
  }

  Future<Weather> weather(LatLng at) async {
    try {
      final j = await Api.get('/weather', {'lat': '${at.latitude}', 'lng': '${at.longitude}'});
      return Weather.fromJson(j as Map<String, dynamic>);
    } catch (_) {
      return const Weather(); // clima é opcional: nunca derruba a navegação
    }
  }

  Future<Trip> createTrip({required Poi dest, required LatLng origin}) async {
    final j = await Api.post('/trips', {
      'dest_name': dest.name,
      'dest_lat': dest.lat,
      'dest_lng': dest.lng,
      'origin_lat': origin.latitude,
      'origin_lng': origin.longitude,
    });
    return Trip(j['id'] as String, j['update_token'] as String);
  }

  Future<void> sendPosition(Trip t, LatLng p, {bool finished = false}) async {
    try {
      await Api.post('/trips/${t.id}/position', {
        'update_token': t.updateToken,
        'lat': p.latitude,
        'lng': p.longitude,
        'finished': finished,
      });
    } catch (_) {
      // Falha pontual de rede: a próxima atualização tenta de novo.
    }
  }
}
