import 'package:flutter/material.dart';

import 'community_tab.dart';
import 'core.dart';
import 'map/map_screen.dart';
import 'market_tab.dart';
import 'theme.dart';

void main() => runApp(const CentroHistoricoApp());

class CentroHistoricoApp extends StatelessWidget {
  const CentroHistoricoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Centro Histórico SLZ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}

/// Casca do app: barra de navegação inferior fixa com as 3 abas do rascunho.
/// As abas deslizam suavemente e mantêm o estado (o mapa não recarrega ao trocar de aba).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _pages = PageController();

  @override
  void initState() {
    super.initState();
    appState.addListener(_syncPage);
  }

  @override
  void dispose() {
    appState.removeListener(_syncPage);
    _pages.dispose();
    super.dispose();
  }

  void _syncPage() {
    if (!_pages.hasClients) return;
    if ((_pages.page ?? 0).round() == appState.tab) return;
    _pages.animateToPage(
      appState.tab,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(), // troca pela barra ou pela borda do mapa
        children: const [
          _KeepAlive(child: MapScreen()),
          _KeepAlive(child: MarketTab()),
          _KeepAlive(child: CommunityTab()),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => NavigationBar(
          selectedIndex: appState.tab,
          onDestinationSelected: appState.goTo,
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: appState.cartCount > 0,
                label: Text('${appState.cartCount}'),
                child: const Icon(Icons.restaurant_menu_outlined),
              ),
              selectedIcon: const Icon(Icons.restaurant_menu),
              label: 'Pedir',
            ),
            const NavigationDestination(
                icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Comunidade'),
          ],
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
