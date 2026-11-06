import 'package:flutter/material.dart';

import '../core.dart';
import '../theme.dart';
import 'map_flow.dart';
import 'models.dart';

/// Transição suave padrão (fade + leve subida) entre as telas do mapa.
Route<T> smoothRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

IconData poiIcon(Poi p) {
  if (p.type == 'mansion') return Icons.account_balance;
  if (p.type == 'safe_zone') return Icons.shield;
  return categoryIcon(p.category);
}

IconData modeIcon(TransportMode m) => switch (m) {
      TransportMode.walk => Icons.directions_walk,
      TransportMode.car => Icons.directions_car,
      TransportMode.moto => Icons.two_wheeler,
    };

IconData weatherIcon(String key) => switch (key) {
      'sunny' => Icons.wb_sunny,
      'night' => Icons.nightlight_round,
      'partly' => Icons.cloud_queue,
      'rain' => Icons.umbrella,
      'storm' => Icons.thunderstorm,
      'fog' => Icons.blur_on,
      _ => Icons.cloud,
    };

/// Foto do local. Sem foto cadastrada, mostra um placeholder da marca (honesto: "foto em breve").
class PoiPhoto extends StatelessWidget {
  final Poi poi;
  final double width;
  final double height;
  final double radius;
  const PoiPhoto({super.key, required this.poi, this.width = 88, this.height = 88, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy2, AppColors.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(poiIcon(poi), color: AppColors.orange, size: (height < width ? height : width) * 0.42),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: poi.imageUrl == null
            ? placeholder
            : Image.network(poi.imageUrl!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, p) => p == null ? child : placeholder,
                errorBuilder: (_, __, ___) => placeholder),
      ),
    );
  }
}

class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool accent;
  const RoundButton({super.key, required this.icon, this.onTap, this.tooltip, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.orange : Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: const Color(0x330B2545),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Icon(icon, size: 22, color: accent ? Colors.white : AppColors.navy, semanticLabel: tooltip),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Busca
class SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  const SearchPill({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x330B2545),
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 56,
        child: Row(children: [
          const Padding(
            padding: EdgeInsets.only(left: 18, right: 10),
            child: Icon(Icons.search, color: AppColors.orange),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Loja de calçados, restaurantes, casarões...',
                hintStyle: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400),
                border: InputBorder.none,
              ),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, __) => v.text.isEmpty
                  ? const SizedBox(width: 12)
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close, color: AppColors.muted),
                      onPressed: onClear,
                    ),
            ),
        ]),
      ),
    );
  }
}

class SearchSuggestions extends StatelessWidget {
  final ValueChanged<String> onPick;
  const SearchSuggestions({super.key, required this.onPick});

  static const items = ['Restaurantes', 'Loja de calçados', 'Roupas', 'Cafés', 'Artesanato', 'Casarões'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in items)
          ActionChip(
            label: Text(s),
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.line),
            labelStyle: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
            onPressed: () => onPick(s),
          ),
      ]),
    );
  }
}

// ----------------------------------------------------- Os 3 botões de filtro
class FilterPills extends StatelessWidget {
  final MapFilter? selected; // null enquanto há busca ativa
  final ValueChanged<MapFilter> onSelect;
  const FilterPills({super.key, required this.selected, required this.onSelect});

  static const _defs = [
    (MapFilter.shops, 'Lojas', Icons.storefront),
    (MapFilter.commerce, 'Comércio', Icons.shopping_bag_outlined),
    (MapFilter.support, 'Apoio', Icons.shield_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final d in _defs) ...[
        Expanded(child: _Pill(label: d.$2, icon: d.$3, active: selected == d.$1, onTap: () => onSelect(d.$1))),
        if (d != _defs.last) const SizedBox(width: 8),
      ],
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 44,
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x230B2545), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: active ? AppColors.orange : AppColors.navy),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: active ? Colors.white : AppColors.navy)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------- Prévia do local (card)
class PoiCard extends StatelessWidget {
  final Poi poi;
  final double? distanceM;
  final VoidCallback onClose;
  final VoidCallback onRoute;
  final VoidCallback? onMenu;
  const PoiCard({
    super.key,
    required this.poi,
    required this.distanceM,
    required this.onClose,
    required this.onRoute,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x330B2545), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PoiPhoto(poi: poi),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(poi.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 20, color: AppColors.muted, semanticLabel: 'Fechar'),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(poi.categoryLabel,
                    style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 12)),
                if (poi.isOpen != null) OpenBadge(open: poi.isOpen!),
                if (distanceM != null)
                  Text(fmtDistance(distanceM!), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Text(poi.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.3)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (onMenu != null) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMenu,
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: const Text('Cardápio'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onRoute,
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('Como chegar'),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ----------------------------------------------- Resultados da busca (carrossel)
class ResultsCarousel extends StatelessWidget {
  final List<Poi> results;
  final double? Function(Poi) distanceOf;
  final ValueChanged<Poi> onTap;
  const ResultsCarousel({super.key, required this.results, required this.distanceOf, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: const Row(children: [
          Icon(Icons.search_off, color: AppColors.muted),
          SizedBox(width: 10),
          Expanded(child: Text('Nada encontrado. Tente "restaurantes" ou "roupas".')),
        ]),
      );
    }
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = results[i];
          final d = distanceOf(p);
          return GestureDetector(
            onTap: () => onTap(p),
            child: Container(
              width: 270,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Color(0x290B2545), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Row(children: [
                PoiPhoto(poi: p, width: 80, height: 84, radius: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text(p.categoryLabel,
                        style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 12)),
                    if (d != null)
                      Text(fmtDistance(d), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ]),
            ),
          );
        },
      ),
    );
  }
}
