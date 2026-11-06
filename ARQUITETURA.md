# Centro Histórico SLZ — Arquitetura, MVP e Modelo de Negócio

App mobile para dar visibilidade ao Centro Histórico de São Luís (MA), unindo turismo, história, apoio ao turista e um marketplace local com receita recorrente.

## 1. Visão geral da arquitetura

```
┌────────────────────────── Flutter (mobile) ──────────────────────────┐
│  NavigationBar fixa:  [1 Mapa]   [2 Pedir]   [3 Comunidade/Guia]      │
│                                                                      │
│  AppState (ChangeNotifier) = "cola" entre as abas                     │
│   • showOnMap(poi)      → Aba 2/3 leva o usuário ao pino no mapa      │
│   • openStoreMenu(id)   → Aba 1/3 abre o cardápio da loja             │
│   • carrinho (1 loja por pedido)                                      │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ HTTPS / JSON (REST)
┌───────────────────────────────▼──────────────────────────────────────┐
│  FastAPI (Python)                                                    │
│   /map/pois  /stores  /stores/{id}/menu  /orders                     │
│   /mansions  /events  /safe-zones  /feed  /admin/revenue             │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ SQLAlchemy 2.0
                     SQLite (MVP)  →  PostgreSQL + PostGIS (produção)
```

**Como as partes conversam:** o app só fala com a API REST em JSON. O Google Maps SDK desenha o mapa no próprio aparelho; a API entrega apenas os pontos (`/map/pois`) com status aberto/fechado já calculado no fuso do Maranhão. A navegação entre abas é feita pelo `AppState` compartilhado, sem acoplar as telas entre si.

### Fluxos integrados entre as abas (conforme o rascunho)

| De → Para | Gatilho | Resultado |
|---|---|---|
| Mapa → Pedir | Toque no pino de uma loja → "Ver cardápio" | Aba 2 abre o cardápio da loja |
| Pedir → Mapa | Ícone de localização na loja/cardápio | Aba 1 centraliza no pino e abre o card da loja |
| Comunidade → Mapa | Ícone de localização em casarão/apoio | Aba 1 foca o ponto |
| Comunidade → Pedir | Post que cita uma loja | Abre o cardápio daquela loja |
| Mapa → Guia | Pino de casarão → "Ver no guia" | Vai para a Aba 3 |

## 2. Modelagem de dados (`backend/models.py`)

| Tabela | Campos principais | Observação |
|---|---|---|
| `stores` | nome, categoria, lat/lng, horário, `commission_rate`, `sponsored_until` | Patrocínio ativo = `sponsored_until >= agora` |
| `dishes` | loja, nome, descrição, `history_note`, preço, disponível | `history_note` conta a história cultural do prato |
| `dish_addons` | prato, nome, preço | Personalização do pedido |
| `mansions` | nome, ano, estilo, lat/lng, `visit_info` | Conteúdo curado |
| `events` | título, tipo (`evento`/`roteiro`), data, `ticket_price`, `platform_fee_rate` | Preço 0 = gratuito |
| `safe_zones` | nome, tipo, lat/lng | Pontos de apoio ao turista |
| `posts` / `comments` | autor, tipo (turista/morador), texto, nota 1–5, loja/casarão, curtidas | Prova social |
| `orders` / `order_items` | subtotal, `commission_rate`, `commission_value` | Comissão congelada no momento do pedido |

## 3. Endpoints (MVP)

- `GET /map/pois?lat&lng&radius_km&types=store,mansion,safe_zone` — patrocinados primeiro, depois por distância.
- `GET /stores?category&q` — patrocinados e abertos primeiro. `GET /stores/{id}`, `GET /stores/{id}/menu`.
- `POST /orders` — valida loja aberta, pratos e adicionais; calcula subtotal e comissão da plataforma.
- `GET /mansions`, `GET /events`, `GET /safe-zones`.
- `GET /feed`, `POST /feed`, `POST /feed/{id}/like`, `POST /feed/{id}/comments`.
- `GET /admin/revenue` — GMV, comissões e lojas patrocinadas (base para o painel de investidores).

Documentação interativa automática em `/docs` (Swagger).

## 4. Como rodar

**Backend**
```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
O banco SQLite é criado e populado com dados mockados na primeira execução.

**App Flutter** (Flutter 3.16+)
```bash
cd mobile
flutter create . --platforms=android,ios   # gera as pastas android/ e ios/ (preserva lib/)
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000   # emulador Android
```
Configurações obrigatórias:
- **Google Maps:** criar uma chave no Google Cloud (Maps SDK for Android/iOS) e colocar em `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`) e no `AppDelegate` do iOS.
- **Localização:** permissões `ACCESS_FINE_LOCATION` (Android) e `NSLocationWhenInUseUsageDescription` (iOS).
- **Dispositivo real:** use o IP da sua máquina em `API_URL`. Para HTTP em desenvolvimento no Android, habilite `usesCleartextTraffic`.

## 5. Modelo de negócio

| Receita | Como funciona no MVP | Onde está no código |
|---|---|---|
| **Comissão por pedido** | % configurável por loja (padrão 12%) sobre o subtotal | `POST /orders`, campos `commission_*` |
| **Destaque patrocinado** | Loja paga por período; aparece primeiro no mapa e na lista, com selo | `Store.sponsored_until`, ordenação em `/map/pois` e `/stores` |
| **Roteiros e eventos pagos** | Ingresso com taxa da plataforma (padrão 10%) | `Event.ticket_price`, `platform_fee_rate` |

Exemplo ilustrativo (hipóteses, não projeção): ticket médio de R$ 60 com 12% rende R$ 7,20 por pedido; 100 pedidos/dia equivalem a cerca de R$ 21,6 mil/mês só de comissão, antes de patrocínios e ingressos. Substitua pelos números reais de um piloto com 10–20 lojas.

## 6. Ideias extras ("Frankenstein")

**1. Passaporte do Centro Histórico (gamificação + dados).**
O turista faz check-in por geolocalização nos casarões e pontos culturais e ganha selos digitais. Cada trilha concluída libera cupons em lojas parceiras (que pagam pelo cupom). Para investidores e poder público, os check-ins viram um mapa de calor de fluxo turístico, vendável como painel B2B (hotéis, secretaria de turismo, associações de comerciantes).

**2. "O Casarão Fala": áudio-guia e AR geolocalizados.**
Ao chegar perto de um casarão, o app toca uma narrativa curta, gravada por historiadores e moradores, e oferece uma visão em realidade aumentada "como era no passado". Vende-se como pacote premium para turistas e como licença para hotéis e agências. Também cria um motivo recorrente de uso e preserva a memória oral do bairro.

## 7. Pendências e riscos antes de um piloto real

- **Dados fictícios:** lojas, pratos de lojas, eventos e pontos de apoio do `seed.py` são mockados. Casarões e marcos são reais, mas coordenadas e textos são aproximados e precisam de curadoria (IPHAN, historiadores locais). **Pontos de apoio e segurança devem vir de fontes oficiais**; não publique "zonas seguras" sem validação.
- **Pagamentos:** o MVP registra o pedido, mas não cobra. Integre um provedor com Pix e split de pagamento (comissão automática).
- **Autenticação:** o MVP não tem login. Adicione contas (OTP por SMS ou Google/Apple), perfis de lojista e painel da loja.
- **Moderação do feed:** denúncia, filtro de conteúdo e regras de upload de fotos (armazenamento S3/GCS).
- **LGPD:** consentimento de localização, política de privacidade e retenção de dados.
- **Escala:** migrar para PostgreSQL + PostGIS, adicionar Alembic (migrações), cache e notificações push.
- **Verificação:** o código do backend passou apenas em checagem de sintaxe; o ambiente onde foi escrito bloqueou a instalação de dependências, então a API e o app Flutter **ainda não foram executados**. Espere pequenos ajustes no primeiro `flutter run` e `uvicorn`.
