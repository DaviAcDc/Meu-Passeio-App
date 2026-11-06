import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core.dart';
import '../theme.dart';
import 'geo.dart';
import 'map_flow.dart';
import 'models.dart';
import 'route_screen.dart';
import 'widgets.dart';

/// TELA 1 — Mapa 2D claro, limitado ao Centro Histórico, com busca, 3 filtros e prévia do local.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final flow = MapFlow();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  GoogleMapController? _map;
  double _zoom = 16.5;

  @override
  void initState() {
    super.initState();
    flow.addListener(_onFlow);
    appState.addListener(_consumeFocus);
    _searchFocus.addListener(() => setState(() {}));
    flow.init();
  }

  @override
  void dispose() {
    flow.removeListener(_onFlow);
    appState.removeListener(_consumeFocus);
    flow.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ reações
  Poi? _lastSelected;
  List<Poi>? _lastResults;

  void _onFlow() {
    if (!mounted) return;
    setState(() {});
    if (flow.selected != null && flow.selected != _lastSelected) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(flow.selected!.pos, math.max(_zoom, 17.5)));
    }
    _lastSelected = flow.selected;
    if (flow.results != null && flow.results != _lastResults) _fitResults(flow.results!);
    _lastResults = flow.results;
    _consumeFocus();
  }

  void _fitResults(List<Poi> r) {
    if (_map == null || r.isEmpty) return;
    if (r.length == 1) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(r.first.pos, 18));
    } else {
      _map!.animateCamera(CameraUpdate.newLatLngBounds(boundsOf(r.map((p) => p.pos)), 90));
    }
  }

  /// Outra aba pediu "ver no mapa": seleciona o ponto e leva a câmera até ele.
  void _consumeFocus() {
    final f = appState.focusedPoi;
    if (f == null || appState.tab != 0 || _map == null || flow.loading) return;
    appState.clearFocus();
    final poi = flow.find(f['type'] as String, f['id'] as int);
    if (poi != null) {
      _search.clear();
      flow.selectFromOutside(poi);
    } else {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng((f['lat'] as num).toDouble(), (f['lng'] as num).toDouble()), 18));
    }
  }

  void _runSearch(String q) {
    _searchFocus.unfocus();
    _search.text = q;
    flow.search(q);
  }

  void _clearSearch() {
    _search.clear();
    flow.clearSearch();
    flow.select(null);
  }

  Future<void> _recenter() async {
    if (flow.userInsideCentro) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(flow.userPos!, 17.5));
    } else {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(centroCenter, 16.5));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Você está fora do Centro Histórico. Mostrando o centro do mapa.'),
        ));
      }
    }
  }

  void _openRoute(Poi p) {
    _searchFocus.unfocus();
    Navigator.of(context).push(smoothRoute(RouteScreen(flow: flow, poi: p)));
  }

  // ------------------------------------------------------ contornos no mapa
  Color _stroke(Poi p) => switch (p.type) {
        'mansion' => AppColors.navy,
        'safe_zone' => AppColors.navySoft,
        _ => AppColors.orange,
      };

  Color _fill(Poi p) => switch (p.type) {
        'mansion' => AppColors.navyFill,
        'safe_zone' => AppColors.navySoftFill,
        _ => AppColors.orangeFill,
      };

  /// Em vez de pinos vermelhos: o prédio/área recebe uma outline elegante.
  Set<Polygon> _polygons() {
    // Mantém o contorno legível em qualquer zoom (cresce quando o zoom diminui).
    final half = math.max(9.0, 5 * math.pow(2, 17.5 - _zoom)).toDouble();
    return {
      for (final p in flow.visible)
        Polygon(
          polygonId: PolygonId(p.key),
          points: squareFootprint(p.pos, half),
          strokeColor: flow.selected?.key == p.key ? AppColors.navy : _stroke(p),
          strokeWidth: flow.selected?.key == p.key ? 4 : 2,
          fillColor: flow.selected?.key == p.key ? AppColors.orangeFillStrong : _fill(p),
          consumeTapEvents: true,
          onTap: () => flow.select(p),
        ),
    };
  }

  /// Área de toque maior e invisível, porque o contorno sozinho é pequeno para o dedo.
  Set<Circle> _tapTargets() => {
        for (final p in flow.visible)
          Circle(
            circleId: CircleId(p.key),
            center: p.pos,
            radius: 24,
            strokeWidth: 0,
            fillColor: AppColors.tapTarget,
            consumeTapEvents: true,
            onTap: () => flow.select(p),
          ),
      };

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final showSuggestions = _searchFocus.hasFocus && _search.text.isEmpty;
    final sel = flow.selected;

    return Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(target: centroCenter, zoom: 16.5),
        style: mapStyleLight,
        cameraTargetBounds: CameraTargetBounds(centroBounds),
        minMaxZoomPreference: const MinMaxZoomPreference(15, 19.5),
        myLocationEnabled: flow.hasLocationPermission,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        tiltGesturesEnabled: false,
        polygons: _polygons(),
        circles: _tapTargets(),
        onMapCreated: (c) {
          _map = c;
          _consumeFocus();
        },
        onCameraMove: (pos) {
          if ((pos.zoom - _zoom).abs() > 0.3) setState(() => _zoom = pos.zoom);
        },
        onTap: (_) {
          _searchFocus.unfocus();
          if (flow.selected != null) flow.select(null);
        },
      ),

      // Topo: busca + 3 botões
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SearchPill(
              controller: _search,
              focusNode: _searchFocus,
              busy: flow.searching,
              onSubmitted: _runSearch,
              onClear: _clearSearch,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: showSuggestions ? SearchSuggestions(onPick: _runSearch) : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 10),
            FilterPills(
              selected: flow.results == null ? flow.filter : null,
              onSelect: (f) {
                _search.clear();
                _searchFocus.unfocus();
                flow.setFilter(f);
              },
            ),
          ]),
        ),
      ),

      // Baixo: botão "centralizar" + prévia do local ou resultados
      Positioned(
        left: 16,
        right: 16,
        bottom: 16,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          RoundButton(icon: Icons.my_location, tooltip: 'Centralizar', onTap: _recenter),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: sel != null
                ? SizedBox(
                    key: ValueKey(sel.key),
                    width: double.infinity,
                    child: PoiCard(
                      poi: sel,
                      distanceM: flow.distanceM(sel),
                      onClose: () => flow.select(null),
                      onRoute: () => _openRoute(sel),
                      onMenu: sel.type == 'store' && sel.category != 'calcados' && sel.category != 'roupas'
                          ? () => appState.openStoreMenu(sel.id)
                          : null,
                    ),
                  )
                : flow.results != null
                    ? SizedBox(
                        key: const ValueKey('results'),
                        width: double.infinity,
                        child: ResultsCarousel(
                          results: flow.results!,
                          distanceOf: flow.distanceM,
                          onTap: flow.select,
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), width: double.infinity),
          ),
        ]),
      ),

      if (flow.loading) const Center(child: CircularProgressIndicator()),
      if (flow.error != null)
        Positioned(
          left: 16,
          right: 16,
          top: 150,
          child: Material(
            color: Colors.white,
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                const Icon(Icons.wifi_off, color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text(flow.error!, style: const TextStyle(fontSize: 13))),
                TextButton(onPressed: flow.load, child: const Text('Tentar de novo')),
              ]),
            ),
          ),
        ),

      // Deslizar da borda direita troca para a próxima aba (o mapa usa os gestos do centro).
      Positioned(
        right: 0,
        top: 190,
        bottom: 190,
        width: 18,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -250) appState.goTo(1);
          },
        ),
      ),
    ]);
  }
}
