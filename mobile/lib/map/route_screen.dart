import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme.dart';
import 'geo.dart';
import 'map_flow.dart';
import 'models.dart';
import 'navigation_screen.dart';
import 'share_trip.dart';
import 'widgets.dart';

/// TELA 2 — Detalhes do trajeto: foto do destino, distância, tempo por meio de transporte,
/// de onde sai / para onde vai, e os botões Iniciar e Compartilhar.
class RouteScreen extends StatefulWidget {
  final MapFlow flow;
  final Poi poi;
  const RouteScreen({super.key, required this.flow, required this.poi});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  RouteInfo? _route;
  String? _error;
  TransportMode _mode = TransportMode.walk;
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    widget.flow.activeTrip = null; // um link de acompanhamento por destino
    _load();
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _route = null;
    });
    try {
      final r = await widget.flow.service.route(widget.flow.origin, widget.poi.pos);
      if (!mounted) return;
      setState(() => _route = r);
      _fit();
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível calcular a rota. Verifique a conexão.');
    }
  }

  void _fit() {
    final r = _route;
    if (_map == null || r == null) return;
    final pts = [widget.flow.origin, widget.poi.pos, ...r.of(_mode).polyline];
    final b = boundsOf(pts);
    if (b.southwest == b.northeast) return;
    _map!.animateCamera(CameraUpdate.newLatLngBounds(b, 110));
  }

  void _pickMode(TransportMode m) {
    setState(() => _mode = m);
    _fit();
  }

  Future<void> _start() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Como você quer se guiar?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 14),
            _ViewChoice(
              icon: Icons.map_outlined,
              title: 'Mapa 2D',
              subtitle: 'Visão de cima, leve e limitada ao Centro Histórico.',
              onTap: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 10),
            _ViewChoice(
              icon: Icons.view_in_ar_outlined,
              title: 'Mapa 3D (guia avançado)',
              subtitle: 'Câmera inclinada para enxergar ruas e prédios, com o clima no topo.',
              highlight: true,
              onTap: () => Navigator.pop(ctx, true),
            ),
          ]),
        ),
      ),
    );
    if (choice == null || !mounted || _route == null) return;
    Navigator.of(context).push(smoothRoute(NavigationScreen(
      flow: widget.flow,
      poi: widget.poi,
      route: _route!.of(_mode),
      mode: _mode,
      is3d: choice,
      simulate: widget.flow.originIsDefault,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final flow = widget.flow;
    final line = _route?.of(_mode).polyline ?? const <LatLng>[];

    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: poi.pos, zoom: 16.5),
          style: mapStyleLight,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: flow.userInsideCentro,
          compassEnabled: false,
          tiltGesturesEnabled: false,
          padding: const EdgeInsets.only(bottom: 300, top: 120),
          polylines: {
            if (line.length >= 2) ...{
              Polyline(polylineId: const PolylineId('casing'), points: line, color: Colors.white, width: 11,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round),
              Polyline(polylineId: const PolylineId('route'), points: line, color: AppColors.navy, width: 6,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round),
            }
          },
          markers: {
            Marker(
              markerId: const MarkerId('origin'),
              position: flow.origin,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: flow.originName),
            ),
            Marker(
              markerId: const MarkerId('dest'),
              position: poi.pos,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(title: poi.name),
            ),
          },
          onMapCreated: (c) {
            _map = c;
            _fit();
          },
        ),

        // Topo: voltar + foto e resumo do destino
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              RoundButton(icon: Icons.arrow_back, tooltip: 'Voltar', onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Color(0x330B2545), blurRadius: 18, offset: Offset(0, 6))],
                  ),
                  child: Row(children: [
                    PoiPhoto(poi: poi, width: 56, height: 56, radius: 14),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(poi.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 16)),
                        Text(poi.address.isNotEmpty ? '${poi.categoryLabel} · ${poi.address}' : poi.categoryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // Painel inferior
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x330B2545), blurRadius: 30, offset: Offset(0, -6))],
            ),
            child: SafeArea(
              top: false,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: _error != null
                      ? _ErrorBox(message: _error!, onRetry: _load)
                      : _route == null
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _panelContent(_route!),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _panelContent(RouteInfo r) {
    final cur = r.of(_mode);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)),
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _BigStat(label: 'DISTÂNCIA', value: fmtDistance(cur.distanceM))),
        Expanded(child: _BigStat(label: 'TEMPO DE VIAGEM', value: fmtDuration(cur.durationS), accent: true)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        for (final m in TransportMode.values) ...[
          Expanded(
            child: _ModeTile(
              mode: m,
              duration: fmtDuration(r.of(m).durationS),
              selected: m == _mode,
              onTap: () => _pickMode(m),
            ),
          ),
          if (m != TransportMode.values.last) const SizedBox(width: 8),
        ],
      ]),
      const SizedBox(height: 16),
      _FromTo(from: widget.flow.originName, to: widget.poi.name, fromIsDefault: widget.flow.originIsDefault),
      if (r.isEstimate)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Tempo e distância estimados. Configure a chave do Google Maps no servidor para a rota real pelas ruas.',
              style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
        ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.navigation),
              label: const Text('INICIAR', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => shareTrip(context, widget.flow, widget.poi),
            child: const Icon(Icons.ios_share, semanticLabel: 'Compartilhar trajeto'),
          ),
        ),
      ]),
    ]);
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  const _BigStat({required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Text(value,
            key: ValueKey(value),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: accent ? AppColors.orange : AppColors.navy)),
      ),
    ]);
  }
}

class _ModeTile extends StatelessWidget {
  final TransportMode mode;
  final String duration;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTile({required this.mode, required this.duration, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeSoft : AppColors.mist,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.orange : Colors.transparent, width: 1.6),
        ),
        child: Column(children: [
          Icon(modeIcon(mode), color: selected ? AppColors.orange : AppColors.navy),
          const SizedBox(height: 4),
          Text(duration, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 14)),
          Text(mode.label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

class _FromTo extends StatelessWidget {
  final String from;
  final String to;
  final bool fromIsDefault;
  const _FromTo({required this.from, required this.to, required this.fromIsDefault});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color color, String caption, String text) => Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(caption, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
            ]),
          ),
        ]);
    return Column(children: [
      row(Icons.radio_button_checked, AppColors.navy, 'De onde você está saindo', from),
      Padding(
        padding: const EdgeInsets.only(left: 9),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(width: 2, height: 14, color: AppColors.line),
        ),
      ),
      row(Icons.location_on, AppColors.orange, 'Destino', to),
    ]);
  }
}

class _ViewChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;
  const _ViewChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? AppColors.navy : AppColors.mist,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Icon(icon, size: 28, color: AppColors.orange),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w800, color: highlight ? Colors.white : AppColors.navy)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12.5, color: highlight ? const Color(0xFFC9D6E8) : AppColors.muted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: highlight ? Colors.white : AppColors.muted),
        ]),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      const Icon(Icons.wifi_off, color: AppColors.orange, size: 32),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
    ]);
  }
}
