import 'package:flutter/material.dart';
import 'core.dart' hide Thumb;
import 'core.dart' as core show Thumb;
import 'theme.dart';

/// ABA 2 - Marketplace gastronômico e comercial ("iFood do Centro Histórico").
class MarketTab extends StatefulWidget {
  const MarketTab({super.key});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  static const _categories = {
    null: 'Todos',
    'restaurante': 'Restaurantes',
    'cafe': 'Cafés',
    'artesanato': 'Artesanato',
    'hotel': 'Hospedagem',
  };

  String? _category;
  late Future<List<Map<String, dynamic>>> _stores;

  @override
  void initState() {
    super.initState();
    _stores = _fetch();
    appState.addListener(_checkPendingStore);
  }

  @override
  void dispose() {
    appState.removeListener(_checkPendingStore);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final data = await Api.get(
        '/stores', {if (_category != null) 'category': _category!});
    return List<Map<String, dynamic>>.from(data);
  }

  /// Aba 1 -> Aba 2: o mapa pediu para abrir o cardápio de uma loja.
  void _checkPendingStore() {
    final id = appState.pendingStoreId;
    if (id == null || appState.tab != 1) return;
    appState.clearPendingStore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StoreMenuPage(storeId: id)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sabores do Centro Histórico')),
      body: Column(children: [
        // Linha de abas no topo (3 caixas do rascunho) -> categorias
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final e in _categories.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _category == e.key,
                    onSelected: (_) => setState(() {
                      _category = e.key;
                      _stores = _fetch();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _stores,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() => _stores = _fetch()),
                    child: const Text('Erro ao carregar. Tentar de novo'),
                  ),
                );
              }
              final stores = snap.data!;
              if (stores.isEmpty) {
                return const Center(
                  child: Text('Nenhum estabelecimento encontrado.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: stores.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _StoreTile(store: stores[i]),
              );
            },
          ),
        ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (appState.cart.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => showCartSheet(context),
            icon: const Icon(Icons.shopping_bag),
            label: Text(
                'Carrinho · ${appState.cartCount} · ${brl(appState.cartTotal)}'),
          );
        },
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final Map<String, dynamic> store;
  const _StoreTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final sponsored = store['is_sponsored'] == true;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: core.Thumb(
          url: store['image_url'] as String?,
          icon: categoryIcon(store['category'] as String?)),
      title: Row(children: [
        Flexible(
            child: Text(store['name'] as String,
                maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (sponsored) ...[
          const SizedBox(width: 6),
          const Icon(Icons.workspace_premium,
              size: 16, color: AppColors.orange),
        ],
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(store['description'] as String,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          OpenBadge(open: store['is_open'] == true),
          const SizedBox(width: 8),
          Text('${store['opens_at']}–${store['closes_at']}',
              style: const TextStyle(fontSize: 12)),
        ]),
      ]),
      // Botão de localização: Aba 2 -> Aba 1
      trailing: IconButton(
        tooltip: 'Ver no mapa',
        icon: const Icon(Icons.location_on, color: AppColors.orange),
        onPressed: () => appState.showOnMap({
          'type': 'store',
          'id': store['id'],
          'lat': store['lat'],
          'lng': store['lng'],
        }),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StoreMenuPage(storeId: store['id'] as int))),
    );
  }
}

// ------------------------------------------------------------------ Cardápio
class StoreMenuPage extends StatelessWidget {
  final int storeId;
  const StoreMenuPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Api.get('/stores/$storeId/menu'),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Erro ao carregar o cardápio.')));
        }
        final data = snap.data as Map<String, dynamic>;
        final store = data['store'] as Map<String, dynamic>;
        final dishes = List<Map<String, dynamic>>.from(data['dishes']);
        return Scaffold(
          appBar: AppBar(title: Text(store['name'] as String)),
          body: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store['description'] as String),
                    const SizedBox(height: 4),
                    Text(store['address'] as String,
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(children: [
                      OpenBadge(open: store['is_open'] == true),
                      const Spacer(),
                      // Botão de localização: Aba 2 -> Aba 1
                      OutlinedButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: const Text('Ver no mapa'),
                        onPressed: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          appState.showOnMap({
                            'type': 'store',
                            'id': store['id'],
                            'lat': store['lat'],
                            'lng': store['lng'],
                          });
                        },
                      ),
                    ]),
                  ]),
            ),
            const Divider(height: 1),
            if (dishes.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Esta loja ainda não tem itens à venda.')),
            for (final d in dishes) _DishTile(store: store, dish: d),
          ]),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: ListenableBuilder(
            listenable: appState,
            builder: (context, _) => appState.cart.isEmpty
                ? const SizedBox.shrink()
                : FloatingActionButton.extended(
                    onPressed: () => showCartSheet(context),
                    icon: const Icon(Icons.shopping_bag),
                    label: Text('Carrinho · ${brl(appState.cartTotal)}'),
                  ),
          ),
        );
      },
    );
  }
}

class _DishTile extends StatelessWidget {
  final Map<String, dynamic> store;
  final Map<String, dynamic> dish;
  const _DishTile({required this.store, required this.dish});

  @override
  Widget build(BuildContext context) {
    final history = dish['history_note'] as String? ?? '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: core.Thumb(
          url: dish['image_url'] as String?, icon: Icons.ramen_dining),
      title: Text(dish['name'] as String),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dish['description'] as String),
        if (history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              history,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          brl(dish['price'] as num),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ]),
      isThreeLine: true,
      onTap: () => _customize(context),
    );
  }

  Future<void> _customize(BuildContext context) async {
    // Um carrinho só pode ter itens de uma loja.
    if (appState.cartStoreId != null && appState.cartStoreId != store['id']) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trocar de loja?'),
          content: Text(
              'Seu carrinho tem itens de ${appState.cartStoreName}. Esvaziar e começar um novo pedido?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Esvaziar')),
          ],
        ),
      );
      if (ok != true) return;
      appState.clearCart();
    }
    if (!context.mounted) return;

    final addons = List<Map<String, dynamic>>.from(dish['addons']);
    final selected = <int>{};
    final noteCtrl = TextEditingController();
    var qty = 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final extras = addons
            .where((a) => selected.contains(a['id']))
            .fold<double>(0, (s, a) => s + (a['price'] as num).toDouble());
        final total = ((dish['price'] as num).toDouble() + extras) * qty;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish['name'] as String,
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (addons.isNotEmpty)
                    const Text('Adicionais',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  for (final a in addons)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: selected.contains(a['id']),
                      title: Text(a['name'] as String),
                      secondary: Text((a['price'] as num) > 0
                          ? '+ ${brl(a['price'] as num)}'
                          : 'grátis'),
                      onChanged: (v) => setSheet(() => v == true
                          ? selected.add(a['id'] as int)
                          : selected.remove(a['id'])),
                    ),
                  TextField(
                    controller: noteCtrl,
                    maxLength: 300,
                    decoration: const InputDecoration(
                        labelText: 'Observações (ex.: sem pimenta)'),
                  ),
                  Row(children: [
                    IconButton(
                        onPressed: qty > 1 ? () => setSheet(() => qty--) : null,
                        icon: const Icon(Icons.remove_circle_outline)),
                    Text('$qty', style: Theme.of(ctx).textTheme.titleMedium),
                    IconButton(
                        onPressed: () => setSheet(() => qty++),
                        icon: const Icon(Icons.add_circle_outline)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          appState.addToCart(
                            store['id'] as int,
                            store['name'] as String,
                            CartItem(
                              dish: dish,
                              addons: addons
                                  .where((a) => selected.contains(a['id']))
                                  .toList(),
                              note: noteCtrl.text.trim(),
                              qty: qty,
                            ),
                          );
                          Navigator.pop(ctx);
                        },
                        child: Text('Adicionar · ${brl(total)}'),
                      ),
                    ),
                  ]),
                ]),
          ),
        );
      }),
    );
    noteCtrl.dispose();
  }
}

// ------------------------------------------------------------------ Carrinho
Future<void> showCartSheet(BuildContext context) {
  final nameCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  var sending = false;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      Future<void> send() async {
        if (nameCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(ctx)
              .showSnackBar(const SnackBar(content: Text('Informe seu nome.')));
          return;
        }
        setSheet(() => sending = true);
        try {
          final res = await Api.post('/orders', {
            'store_id': appState.cartStoreId,
            'customer_name': nameCtrl.text.trim(),
            'notes': notesCtrl.text.trim(),
            'items': [
              for (final i in appState.cart)
                {
                  'dish_id': i.dish['id'],
                  'quantity': i.qty,
                  'addon_ids': [for (final a in i.addons) a['id']],
                  'note': i.note,
                }
            ],
          });
          appState.clearCart();
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Pedido #${res['order_id']} enviado! Total ${brl(res['subtotal'] as num)}')),
            );
          }
        } on ApiError catch (e) {
          setSheet(() => sending = false);
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        } catch (_) {
          setSheet(() => sending = false);
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Falha de conexão.')));
          }
        }
      }

      return ListenableBuilder(
        listenable: appState,
        builder: (ctx, _) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seu pedido · ${appState.cartStoreName ?? ''}',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  for (final i in appState.cart.toList())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${i.qty}× ${i.dish['name']}'),
                      subtitle: Text([
                        if (i.addons.isNotEmpty)
                          i.addons.map((a) => a['name']).join(', '),
                        if (i.note.isNotEmpty) 'Obs: ${i.note}',
                      ].join('\n')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(brl(i.total)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => appState.removeFromCart(i)),
                      ]),
                    ),
                  if (appState.cart.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Carrinho vazio.')),
                  TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Seu nome')),
                  TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Observações para a loja')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: sending || appState.cart.isEmpty ? null : send,
                      child: Text(sending
                          ? 'Enviando...'
                          : 'Finalizar · ${brl(appState.cartTotal)}'),
                    ),
                  ),
                ]),
          ),
        ),
      );
    }),
  );
}
