import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme.dart';
import 'geo.dart';
import 'map_service.dart';
import 'models.dart';

/// Os 3 botões do topo do mapa (círculos azuis 1, 2 e 3 do rascunho).
enum MapFilter { shops, commerce, support }

const _commerceCategories = {'calcados', 'roupas'};

/// Estado e regras do mapa. A tela só desenha; quem decide é este controlador.
class MapFlow extends ChangeNotifier {
  final MapService service;
  MapFlow({MapService? service}) : service = service ?? MapService();

  LatLng? userPos;
  bool hasLocationPermission = false;

  List<Poi> all = [];
  MapFilter filter = MapFilter.shops;

  String query = '';
  List<Poi>? results; // null = sem busca ativa
  bool searching = false;

  Poi? selected;
  Trip? activeTrip;

  bool loading = true;
  String? error;

  // ----------------------------------------------------------- origem da rota
  bool get userInsideCentro => userPos != null && insideBounds(userPos!, centroBounds.southwest, centroBounds.northeast);

  /// Se o usuário está fora do Centro (ou sem GPS), a rota parte do ponto inicial padrão.
  LatLng get origin => userInsideCentro ? userPos! : defaultOrigin;
  bool get originIsDefault => !userInsideCentro;
  String get originName => userInsideCentro ? 'Seu local' : defaultOriginName;

  double? distanceM(Poi p) => userInsideCentro ? haversineM(userPos!, p.pos) : null;

  // ---------------------------------------------------------------- listagem
  bool _matchesFilter(Poi p) => switch (filter) {
        MapFilter.shops => p.type == 'store' && !_commerceCategories.contains(p.category),
        MapFilter.commerce => (p.type == 'store' && _commerceCategories.contains(p.category)) || p.type == 'mansion',
        MapFilter.support => p.type == 'safe_zone',
      };

  MapFilter filterFor(Poi p) {
    if (p.type == 'safe_zone') return MapFilter.support;
    if (p.type == 'mansion' || _commerceCategories.contains(p.category)) return MapFilter.commerce;
    return MapFilter.shops;
  }

  /// O que aparece com contorno no mapa agora.
  List<Poi> get visible => results ?? all.where(_matchesFilter).toList();

  Poi? find(String type, int id) {
    for (final p in all) {
      if (p.type == type && p.id == id) return p;
    }
    return null;
  }

  // ------------------------------------------------------------------ ações
  Future<void> init() async {
    await Future.wait([load(), locate()]);
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      all = await service.pois();
    } catch (_) {
      error = 'Não foi possível carregar o mapa. Verifique a conexão com a API.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      hasLocationPermission = true;
      final p = await Geolocator.getCurrentPosition();
      userPos = LatLng(p.latitude, p.longitude);
      notifyListeners();
    } catch (_) {
      // Sem GPS: o app continua funcionando a partir do ponto inicial padrão.
    }
  }

  void setFilter(MapFilter f) {
    filter = f;
    results = null;
    query = '';
    selected = null;
    notifyListeners();
  }

  Future<void> search(String text) async {
    final q = text.trim();
    if (q.isEmpty) {
      clearSearch();
      return;
    }
    query = q;
    searching = true;
    selected = null;
    notifyListeners();
    try {
      results = await service.search(q, origin);
      error = null;
    } catch (_) {
      error = 'Falha na busca. Tente novamente.';
    }
    searching = false;
    notifyListeners();
  }

  void clearSearch() {
    query = '';
    results = null;
    notifyListeners();
  }

  void select(Poi? p) {
    selected = p;
    notifyListeners();
  }

  /// Usado quando outra aba pede "ver no mapa": troca o filtro se o ponto não estiver visível.
  void selectFromOutside(Poi p) {
    results = null;
    query = '';
    filter = filterFor(p);
    selected = p;
    notifyListeners();
  }
}
