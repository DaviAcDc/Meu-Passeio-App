import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core.dart';
import 'map_flow.dart';
import 'models.dart';

/// Cria (uma vez por destino) o trajeto compartilhado e abre a folha de compartilhamento.
/// O amigo abre o link no navegador e acompanha a posição em tempo real.
Future<void> shareTrip(BuildContext context, MapFlow flow, Poi dest) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    flow.activeTrip ??= await flow.service.createTrip(dest: dest, origin: flow.origin);
    final url = '$publicUrl/t/${flow.activeTrip!.id}';
    await Share.share('Acompanhe meu trajeto até ${dest.name}: $url');
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Não foi possível criar o link de acompanhamento.')));
  }
}
