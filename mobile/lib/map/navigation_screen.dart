import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme.dart';
import 'geo.dart';
import 'map_flow.dart';
import 'models.dart';
import 'share_trip.dart';
import 'widgets.dart';

/// TELA 3 — Navegação. Modo 3D (câmera inclinada, vê ruas e prédios) ou 2D.
/// Clima no topo, painel flutuante com foto do destino embaixo.
///
/// Se o usuário estiver fora do Centro Histórico (ex.: testando de casa), a navegação
/// é SIMULADA ao longo da rota; dentro do Centro, usa o GPS de verdade.
class NavigationScreen extends StatefulWidget {
  final MapFlow flow;
  final Poi poi;
  final ModeRoute route;
  final TransportMode mode;
  final bool is3d;
  final bool simulate;

  const NavigationScreen({
    super.key,
    required this.flow,
    required this.poi,
    required this.route,
    required this.mode,
    required this.is3d,
    required this.simulate,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final RoutePath _path = RoutePath(widget.route.polyline);
  GoogleMapController? _map;
  Timer? _timer;
  StreamSubscription<Position>? _gps;
  Weather? _weather;

  late LatLng _pos = _path.isEmpty ? widget.flow.origin : _path.points.first;
  int _idx = 0;
  bool _arrived = false;
  DateTime _lastShared = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.flow.service.weather(_pos).then((w) {
      if (mounted) setState(() => _weather = w);
    });
    if (_path.isEmpty) return;
    if (widget.simulate) {
      // ~10 m/s para a demonstração ficar fluida (a pé de verdade seria bem mais lento).
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_arrived) return;
        _idx = (_idx + 2).clamp(0, _path.lastIndex).toInt();
        _onPosition(_path.points[_idx]);
      });
    } else {
      _gps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
      ).listen((p) {
        final ll = LatLng(p.latitude, p.longitude);
        _idx = _path.nearestIndex(ll);
        _onPosition(ll);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gps?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _onPosition(LatLng ll) {
    if (!mounted || _arrived) return;
    final remaining = _path.remainingM(_idx);
    final arrived = remaining < 20;
    setState(() {
      _pos = ll;
      _arrived = arrived;
    });

    _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: ll,
      zoom: widget.is3d ? 18.8 : 17.6,
      tilt: widget.is3d ? 62 : 0,
      bearing: widget.is3d ? _path.bearingAt(_idx) : 0,
    )));

    // Se o usuário compartilhou o trajeto, o amigo recebe a posição a cada ~5 s.
    final trip = widget.flow.activeTrip;
    final now = DateTime.now();
    if (trip != null && (arrived || now.difference(_lastShared).inSeconds >= 5)) {
      _lastShared = now;
      widget.flow.service.sendPosition(trip, ll, finished: arrived);
    }
  }

  double get _remainingM => _path.isEmpty ? 0 : _path.remainingM(_idx);

  double get _etaS {
    if (_path.totalM <= 0) return 0;
    return widget.route.durationS * (_remainingM / _path.totalM);
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final line = widget.route.polyline;
    final first = _path.isEmpty ? widget.flow.origin : _path.points.first;

    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: first,
            zoom: widget.is3d ? 18.8 : 17.6,
            tilt: widget.is3d ? 62 : 0,
          ),
          style: mapStyleLight,
          buildingsEnabled: true,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          polylines: {
            if (line.length >= 2) ...{
              Polyline(polylineId: const PolylineId('casing'), points: line, color: Colors.white, width: 14,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round),
              Polyline(polylineId: const PolylineId('route'), points: line, color: AppColors.orange, width: 8,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round),
            }
          },
          markers: {
            Marker(
              markerId: const MarkerId('dest'),
              position: poi.pos,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: poi.name),
            ),
          },
          onMapCreated: (c) => _map = c,
        ),

        // Seta de navegação (o mapa gira por baixo dela)
        const IgnorePointer(child: Center(child: _NavArrow())),

        // Topo: fechar + clima + compartilhar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              Row(children: [
                RoundButton(icon: Icons.close, tooltip: 'Encerrar', onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 12),
                Expanded(child: Center(child: _WeatherChip(weather: _weather))),
                const SizedBox(width: 12),
                RoundButton(
                  icon: Icons.ios_share,
                  tooltip: 'Compartilhar trajeto',
                  onTap: () => shareTrip(context, widget.flow, poi),
                ),
              ]),
              if (widget.simulate)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Simulação: você está fora do Centro Histórico',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
        ),

        // Painel flutuante inferior
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _arrived ? _ArrivedCard(poi: poi, onDone: () => Navigator.of(context).pop()) : _InfoPanel(
                poi: poi,
                distance: fmtDistance(_remainingM),
                eta: fmtDuration(_etaS),
                mode: widget.mode,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppColors.navy,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x660B2545), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: const Icon(Icons.navigation, color: AppColors.orange, size: 32),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  final Weather? weather;
  const _WeatherChip({required this.weather});

  @override
  Widget build(BuildContext context) {
    final w = weather;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: (w == null || !w.available)
          ? const SizedBox.shrink(key: ValueKey('no-weather'))
          : Container(
              key: const ValueKey('weather'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Color(0x330B2545), blurRadius: 14, offset: Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(weatherIcon(w.icon), color: AppColors.orange, size: 22),
                const SizedBox(width: 8),
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${w.tempC}°C / ${w.tempF}°F',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                  Text(w.label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
              ]),
            ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final Poi poi;
  final String distance;
  final String eta;
  final TransportMode mode;
  const _InfoPanel({required this.poi, required this.distance, required this.eta, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('info'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x4D0B2545), blurRadius: 26, offset: Offset(0, 8))],
      ),
      child: Row(children: [
        PoiPhoto(poi: poi, width: 72, height: 72, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(poi.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
            const SizedBox(height: 2),
            Text(poi.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.25)),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(distance, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.orange)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(modeIcon(mode), size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(eta, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13)),
          ]),
        ]),
      ]),
    );
  }
}

class _ArrivedCard extends StatelessWidget {
  final Poi poi;
  final VoidCallback onDone;
  const _ArrivedCard({required this.poi, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('arrived'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(children: [
        const Icon(Icons.flag, color: AppColors.orange, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Você chegou!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            Text(poi.name, style: const TextStyle(color: Color(0xFFC9D6E8))),
          ]),
        ),
        FilledButton(onPressed: onDone, child: const Text('Concluir')),
      ]),
    );
  }
}
