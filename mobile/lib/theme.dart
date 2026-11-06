import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Identidade visual: azul-marinho + laranja + branco.
class AppColors {
  static const navy = Color(0xFF0B2545);
  static const navy2 = Color(0xFF13315C);
  static const navySoft = Color(0xFF3A5A85); // tom claro do marinho (apoio / textos secundários)
  static const orange = Color(0xFFFF7A1A);
  static const orangeSoft = Color(0xFFFFEAD9);
  static const white = Colors.white;
  static const mist = Color(0xFFF3F6FA);
  static const line = Color(0xFFE3E8EF);
  static const muted = Color(0xFF5B6B7F);

  // Preenchimentos translúcidos (sem withOpacity, que está deprecado em Flutter novos)
  static const orangeFill = Color(0x1FFF7A1A);
  static const orangeFillStrong = Color(0x59FF7A1A);
  static const navyFill = Color(0x1F0B2545);
  static const navySoftFill = Color(0x1F3A5A85);
  static const tapTarget = Color(0x01FF7A1A); // quase invisível, só para capturar toques
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.orange,
    onSecondary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.mist,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.orangeSoft,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? AppColors.orange : AppColors.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? AppColors.navy : AppColors.muted)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// Limites do mapa: só o Centro Histórico de São Luís (valores aproximados, ajuste no campo).
final LatLngBounds centroBounds = LatLngBounds(
  southwest: const LatLng(-2.5370, -44.3110),
  northeast: const LatLng(-2.5230, -44.2920),
);
const LatLng centroCenter = LatLng(-2.5297, -44.3028);

/// Ponto inicial usado quando o usuário está fora do Centro (Praça Benedito Leite).
const LatLng defaultOrigin = LatLng(-2.5283, -44.3022);
const String defaultOriginName = 'Praça Benedito Leite (ponto inicial)';

/// Estilo do Google Maps: claro, limpo, sem POIs do Google (evita poluição visual).
const String mapStyleLight = r'''
[
  {"elementType":"geometry","stylers":[{"color":"#f4f6f9"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#5b6b7f"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#eceff4"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e3e8ef"}]},
  {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#0b2545"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cfe3f4"}]}
]
''';
