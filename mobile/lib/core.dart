import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'theme.dart';

/// URL da API. Emulador Android -> 10.0.2.2. Dispositivo real -> IP da máquina.
/// Ex.: flutter run --dart-define=API_URL=http://192.168.0.10:8000
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

/// URL pública do servidor, usada nos links de "compartilhar trajeto" (o amigo precisa
/// conseguir abrir). Em produção, aponte para o domínio real: --dart-define=PUBLIC_URL=https://api.seudominio.com
const publicUrl = String.fromEnvironment('PUBLIC_URL', defaultValue: apiUrl);

class Api {
  static Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$apiUrl$path').replace(queryParameters: query);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw ApiError(r.statusCode, utf8.decode(r.bodyBytes));
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$apiUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode >= 400) throw ApiError(r.statusCode, utf8.decode(r.bodyBytes));
    return jsonDecode(utf8.decode(r.bodyBytes));
  }
}

class ApiError implements Exception {
  final int status;
  final String body;
  ApiError(this.status, this.body);

  /// Extrai a mensagem "detail" do FastAPI quando existir.
  String get message {
    try {
      final d = jsonDecode(body)['detail'];
      return d is String ? d : 'Erro $status';
    } catch (_) {
      return 'Erro $status';
    }
  }
}

String brl(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

class CartItem {
  final Map<String, dynamic> dish;
  final List<Map<String, dynamic>> addons;
  final String note;
  int qty;

  CartItem({required this.dish, required this.addons, required this.note, this.qty = 1});

  double get unitPrice =>
      (dish['price'] as num).toDouble() +
      addons.fold(0.0, (s, a) => s + (a['price'] as num).toDouble());
  double get total => unitPrice * qty;
}

/// Estado global compartilhado entre as 3 abas.
/// É ele que liga: mapa -> cardápio, cardápio -> mapa, guia -> mapa.
class AppState extends ChangeNotifier {
  int tab = 0; // 0 = mapa, 1 = marketplace, 2 = comunidade/guia

  /// POI que o mapa deve focar: {type, id, lat, lng}
  Map<String, dynamic>? focusedPoi;

  /// Loja cujo cardápio o marketplace deve abrir.
  int? pendingStoreId;

  final List<CartItem> cart = [];
  int? cartStoreId;
  String? cartStoreName;

  void goTo(int i) {
    tab = i;
    notifyListeners();
  }

  /// Aba 2/3 -> Aba 1: mostra o local no mapa.
  void showOnMap(Map<String, dynamic> poi) {
    focusedPoi = poi;
    tab = 0;
    notifyListeners();
  }

  void clearFocus() => focusedPoi = null;

  /// Aba 1 -> Aba 2: abre o cardápio da loja.
  void openStoreMenu(int storeId) {
    pendingStoreId = storeId;
    tab = 1;
    notifyListeners();
  }

  void clearPendingStore() => pendingStoreId = null;

  void addToCart(int storeId, String storeName, CartItem item) {
    cartStoreId = storeId;
    cartStoreName = storeName;
    cart.add(item);
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    cart.remove(item);
    if (cart.isEmpty) {
      cartStoreId = null;
      cartStoreName = null;
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    cartStoreId = null;
    cartStoreName = null;
    notifyListeners();
  }

  double get cartTotal => cart.fold(0.0, (s, i) => s + i.total);
  int get cartCount => cart.fold(0, (s, i) => s + i.qty);
}

final appState = AppState();

IconData categoryIcon(String? c) {
  switch (c) {
    case 'restaurante':
      return Icons.restaurant;
    case 'cafe':
      return Icons.local_cafe;
    case 'artesanato':
      return Icons.palette;
    case 'hotel':
      return Icons.hotel;
    default:
      return Icons.storefront;
  }
}

/// Miniatura quadrada (os quadrados do rascunho). Usa imagem se houver, senão um ícone.
class Thumb extends StatelessWidget {
  final String? url;
  final IconData icon;
  final double size;
  const Thumb({super.key, this.url, required this.icon, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.orange, size: size * 0.5),
    );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(url!, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback),
    );
  }
}

class OpenBadge extends StatelessWidget {
  final bool open;
  const OpenBadge({super.key, required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(open ? 'Aberto' : 'Fechado',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
