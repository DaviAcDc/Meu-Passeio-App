import 'package:flutter/material.dart';

import 'core.dart';
import 'theme.dart';

/// ABA 3 - Comunidade (feed social) + Guia (casarões, agenda, apoio ao turista).
class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunidade'),
          bottom: const TabBar(tabs: [Tab(text: 'Feed'), Tab(text: 'Guia')]),
        ),
        body: const TabBarView(children: [_FeedView(), _GuideView()]),
      ),
    );
  }
}

// ---------------------------------------------------------------------- Feed
class _FeedView extends StatefulWidget {
  const _FeedView();

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  late Future<List<Map<String, dynamic>>> _feed;

  @override
  void initState() {
    super.initState();
    _feed = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async =>
      List<Map<String, dynamic>>.from(await Api.get('/feed'));

  void _reload() => setState(() => _feed = _fetch());

  Future<void> _newPost() async {
    final stores = List<Map<String, dynamic>>.from(await Api.get('/stores'));
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    int rating = 5;
    int? storeId;
    String type = 'turista';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Compartilhe sua experiência', style: Theme.of(ctx).textTheme.titleLarge),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Seu nome')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'turista', label: Text('Turista')),
                  ButtonSegment(value: 'morador', label: Text('Morador')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setSheet(() => type = s.first),
              ),
              DropdownButtonFormField<int?>(
                decoration: const InputDecoration(labelText: 'Local (opcional)'),
                initialValue: storeId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sem local')),
                  for (final s in stores) DropdownMenuItem<int?>(value: s['id'] as int, child: Text(s['name'] as String)),
                ],
                onChanged: (v) => setSheet(() => storeId = v),
              ),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'O que achou?'),
              ),
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setSheet(() => rating = i),
                    icon: Icon(i <= rating ? Icons.star : Icons.star_border, color: Colors.amber),
                  ),
              ]),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty || textCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Publicar'),
                ),
              ),
            ]),
          ),
        );
      }),
    );

    if (ok == true) {
      try {
        await Api.post('/feed', {
          'author_name': nameCtrl.text.trim(),
          'author_type': type,
          'text': textCtrl.text.trim(),
          'rating': rating,
          if (storeId != null) 'store_id': storeId,
        });
        _reload();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível publicar.')));
        }
      }
    }
    nameCtrl.dispose();
    textCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _feed;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _feed,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: TextButton(onPressed: _reload, child: const Text('Erro ao carregar. Tentar de novo')));
            }
            final posts = snap.data!;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: posts.length,
              itemBuilder: (_, i) => _PostCard(post: posts[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPost,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Postar'),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late int _likes = widget.post['likes'] as int;
  bool _liked = false;

  Future<void> _like() async {
    if (_liked) return;
    setState(() {
      _liked = true;
      _likes++;
    });
    try {
      await Api.post('/feed/${widget.post['id']}/like', {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = false;
          _likes--;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final store = p['store'] as Map<String, dynamic>?;
    final rating = p['rating'] as int?;
    final comments = List<Map<String, dynamic>>.from(p['comments']);
    final photo = p['photo_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (photo != null)
          Image.network(photo, height: 180, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.orangeSoft,
                child: Text((p['author_name'] as String).substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['author_name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(p['author_type'] == 'morador' ? 'Morador' : 'Turista',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
              if (rating != null)
                Row(children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  Text(' $rating'),
                ]),
            ]),
            const SizedBox(height: 10),
            Text(p['text'] as String),
            if (store != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.storefront, size: 18),
                  label: Text(store['name'] as String),
                  // Aba 3 -> Aba 2: abre o cardápio do local citado
                  onPressed: () => appState.openStoreMenu(store['id'] as int),
                ),
              ),
            Row(children: [
              IconButton(
                onPressed: _like,
                icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent),
              ),
              Text('$_likes'),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, size: 18),
              Text(' ${comments.length}'),
            ]),
            for (final c in comments.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${c['author_name']}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: c['text'] as String),
                ])),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------- Guia
class _GuideView extends StatelessWidget {
  const _GuideView();

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final res = await Future.wait([
      Api.get('/mansions'),
      Api.get('/events'),
      Api.get('/safe-zones'),
    ]);
    return {
      'mansions': List<Map<String, dynamic>>.from(res[0]),
      'events': List<Map<String, dynamic>>.from(res[1]),
      'zones': List<Map<String, dynamic>>.from(res[2]),
    };
  }

  Widget _section(BuildContext context, String title, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return const Center(child: Text('Erro ao carregar o guia.'));
        final d = snap.data!;
        return ListView(padding: const EdgeInsets.all(12), children: [
          _section(context, 'Casarões históricos', Icons.account_balance),
          for (final m in d['mansions']!)
            Card(
              child: ListTile(
                title: Text(m['name'] as String),
                subtitle: Text([
                  if (m['year_built'] != null) 'Séc. ${((m['year_built'] as int) ~/ 100) + 1}',
                  m['description'] as String,
                  m['visit_info'] as String,
                ].where((s) => s.isNotEmpty).join('\n')),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Ver no mapa',
                  icon: const Icon(Icons.location_on, color: AppColors.orange),
                  onPressed: () => appState.showOnMap({
                    'type': 'mansion',
                    'id': m['id'],
                    'lat': m['lat'],
                    'lng': m['lng'],
                  }),
                ),
              ),
            ),
          _section(context, 'Agenda cultural', Icons.event),
          for (final e in d['events']!)
            Card(
              child: ListTile(
                title: Text(e['title'] as String),
                subtitle: Text('${_fmtDate(e['starts_at'] as String)} · ${e['location_name']}\n${e['description']}'),
                isThreeLine: true,
                trailing: e['is_free'] == true
                    ? const Chip(label: Text('Grátis'))
                    : FilledButton.tonal(
                        // Ponto de integração: checkout de ingressos (Pix / cartão)
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Compra de ingressos: integração de pagamento no próximo passo.')),
                        ),
                        child: Text(brl(e['ticket_price'] as num)),
                      ),
              ),
            ),
          _section(context, 'Apoio ao turista', Icons.shield),
          for (final z in d['zones']!)
            Card(
              child: ListTile(
                title: Text(z['name'] as String),
                subtitle: Text(z['description'] as String),
                trailing: IconButton(
                  tooltip: 'Ver no mapa',
                  icon: const Icon(Icons.location_on, color: AppColors.navySoft),
                  onPressed: () => appState.showOnMap({
                    'type': 'safe_zone',
                    'id': z['id'],
                    'lat': z['lat'],
                    'lng': z['lng'],
                  }),
                ),
              ),
            ),
        ]);
      },
    );
  }

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
