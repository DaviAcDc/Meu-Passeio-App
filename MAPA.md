# Redesign do Mapa — do desenho ao código

Versão 2 do app. Só o mapa foi refeito; as abas "Pedir" e "Comunidade" continuam, com a paleta nova aplicada.
Paleta: azul-marinho `#0B2545`, laranja `#FF7A1A`, branco (tudo em `lib/theme.dart`).

## Do rascunho para os arquivos

| Seu desenho | O que virou | Arquivo |
|---|---|---|
| **1º** mapa de entrada, claro | Google Maps com estilo claro, sem POIs do Google, **travado no Centro Histórico** (`cameraTargetBounds`) e zoom 15–19,5 | `map/map_screen.dart`, `theme.dart` (`mapStyleLight`, `centroBounds`) |
| Barra de pesquisa no topo | `SearchPill` + sugestões ("Loja de calçados", "Restaurantes"…). A busca entende categoria e sinônimos (calçado, sapato, tênis…) | `map/widgets.dart`, `backend/routing.py` |
| 3 círculos azuis (1, 2, 3) | 3 botões: **Lojas**, **Comércio** (Rua Grande + casarões), **Apoio** | `map/map_flow.dart` (`MapFilter`) |
| "Sem ponto vermelho, só outline" | Cada local é um **contorno laranja** (casarão: marinho; apoio: marinho claro). Sem pinos | `map/map_screen.dart` (`_polygons`) |
| Mostrar onde a pessoa está | Ponto azul do Google (`myLocationEnabled`) + botão de centralizar | `map/map_screen.dart` |
| Clicar no local → foto e descrição | Card com foto, categoria, aberto/fechado, distância, 2 linhas de descrição, **Como chegar** (e **Cardápio** para restaurantes) | `map/widgets.dart` (`PoiCard`) |
| Deslizar entre abas | Deslizar a partir da **borda direita** do mapa vai para a próxima aba; as abas trocam com animação | `main.dart`, `map_screen.dart` |
| **2º** detalhes do trajeto | Mapa com a rota no topo e painel: DISTÂNCIA, TEMPO DE VIAGEM, a pé/carro/moto, "De onde você está saindo" → "Destino", **INICIAR** e **compartilhar** | `map/route_screen.dart` |
| Foto do local em cima | Cabeçalho com foto, nome e endereço do destino | `map/route_screen.dart` |
| **3º** navegação 3D | Câmera inclinada 62° que segue o trajeto, clima em °C/°F no topo, painel inferior com foto, distância e tempo restantes. Ao tocar em INICIAR você escolhe **Mapa 2D** ou **Mapa 3D** | `map/navigation_screen.dart` |

## Como rodar

```bash
# Backend
cd backend && pip install -r requirements.txt
export GOOGLE_MAPS_API_KEY=sua_chave      # opcional: rota real pelas ruas (sem ela, o app usa estimativa)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# App (Flutter 3.22+)
cd mobile && flutter create . --platforms=android,ios && flutter pub get
run --dart-define=API_URL=http://10.0.2.2:8000
```

Configurações obrigatórias:
- **Chave do Google Maps** (Maps SDK Android/iOS) no `AndroidManifest.xml` (`com.google.android.geo.API_KEY`) e no `AppDelegate` do iOS.
- **Localização:** `ACCESS_FINE_LOCATION` (Android) e `NSLocationWhenInUseUsageDescription` (iOS).
- **Rota real:** ative a *Directions API* na mesma conta e coloque a chave em `GOOGLE_MAPS_API_KEY` **no servidor**.
- **Compartilhar trajeto:** em produção defina `--dart-define=PUBLIC_URL=https://seu-dominio`, para o amigo conseguir abrir o link.

## O que é novo no backend

| Endpoint | Para quê |
|---|---|
| `GET /map/search?q=loja de calçados&lat&lng` | Busca por nome ou categoria |
| `GET /route?from_lat&from_lng&to_lat&to_lng` | Distância, tempo e traçado a pé / carro / moto |
| `GET /weather?lat&lng` | Clima em °C e °F (Open-Meteo, sem chave) |
| `POST /trips`, `POST /trips/{id}/position`, `GET /trips/{id}`, `GET /t/{id}` | Compartilhar o trajeto: o amigo abre o link e vê a posição atualizando a cada 5 s |

## Limites e decisões (leia antes de testar)

- **Nada disto foi compilado nem rodado num celular.** O ambiente onde escrevi não tem Flutter e bloqueia o pip. Testei só a lógica Python pura (busca, rota, clima, trajetos) com respostas simuladas e conferi sintaxe, imports e balanceamento do Dart. Espere pequenos ajustes no primeiro `flutter run`.
- **Contornos são aproximados.** Cada "prédio" é um quadrado de ~20 m em volta da coordenada. Para o contorno real é preciso importar pegadas de prédios (OpenStreetMap/IPHAN).
- **Coordenadas de lojas e da Rua Grande são fictícias** (seed de demonstração). Os limites do mapa (`centroBounds`) também são aproximados: ajuste com o mapa aberto.
- **Fotos:** não há fotos cadastradas, então aparece um placeholder marinho com ícone. Preencha `image_url` das lojas e casarões com fotos reais (com direito de uso).
- **3D:** depende de o Google ter prédios 3D em São Luís naquela região. Se vier plano, a inclinação continua, mas sem volumes.
- **Simulação:** se você estiver fora do Centro (ex.: testando de casa), a navegação é simulada ao longo da rota, e a tela avisa. Dentro do Centro usa o GPS.
- **Rota "estimada":** sem chave no servidor, tempo e distância saem de linha reta × 1,3, e o painel avisa. Com a chave, usa a Directions API. A rota de moto reaproveita a do carro com tempo 15% menor (a API não cobre moto no Brasil).
- **Compartilhar:** os trajetos ficam em memória do servidor (6 h) — serve para demo. Para produção, use Redis/banco e avise o usuário que a posição fica visível a quem tiver o link.
- **Deslizar entre abas:** o mapa consome os gestos horizontais do centro, então o gesto vale a partir da borda direita. A troca também funciona pela barra inferior.
