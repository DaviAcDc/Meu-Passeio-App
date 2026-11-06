"""Lógica pura de rota, busca e clima (sem dependência de FastAPI, fácil de testar).

Rota: se a variável de ambiente GOOGLE_MAPS_API_KEY existir, usa a Directions API
(a chave fica no servidor, não no app). Sem chave, devolve uma ESTIMATIVA por
linha reta x fator de ruas, marcada com source="estimate".
"""
import math
import os
import unicodedata

WALK_KMH = 4.8
CAR_KMH = 22.0   # trânsito urbano do centro, ajuste com dados reais
MOTO_KMH = 27.0
STREET_FACTOR = 1.3  # linha reta -> distância real aproximada nas ruas


def haversine_m(lat1, lng1, lat2, lng2) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def normalize(text: str) -> str:
    """minúsculas e sem acentos: 'Calçados' -> 'calcados'."""
    text = unicodedata.normalize("NFD", text.lower())
    return "".join(c for c in text if unicodedata.category(c) != "Mn").strip()


# Termos que o usuário digita -> categoria interna.
CATEGORY_SYNONYMS = {
    "calcado": "calcados", "calcados": "calcados", "sapato": "calcados", "sapatos": "calcados",
    "tenis": "calcados", "sandalia": "calcados",
    "roupa": "roupas", "roupas": "roupas", "moda": "roupas",
    "restaurante": "restaurante", "restaurantes": "restaurante", "comer": "restaurante",
    "almoco": "restaurante", "jantar": "restaurante",
    "cafe": "cafe", "cafes": "cafe", "cafeteria": "cafe",
    "artesanato": "artesanato", "souvenir": "artesanato", "lembranca": "artesanato",
    "hotel": "hotel", "pousada": "hotel", "hospedagem": "hotel",
}


def resolve_category(query: str) -> str | None:
    """Acha a categoria dentro de frases como 'loja de calçados'."""
    for word in normalize(query).replace("-", " ").split():
        if word in CATEGORY_SYNONYMS:
            return CATEGORY_SYNONYMS[word]
    return None


def matches_query(query: str, name: str, category: str, description: str) -> bool:
    q = normalize(query)
    if not q:
        return True
    cat = resolve_category(q)
    if cat and category == cat:
        return True
    return q in normalize(name) or q in normalize(description) or q == normalize(category)


def estimate_route(o_lat, o_lng, d_lat, d_lng) -> dict:
    straight = haversine_m(o_lat, o_lng, d_lat, d_lng)
    dist = straight * STREET_FACTOR
    line = [[o_lat, o_lng], [d_lat, d_lng]]

    def mode(kmh):
        return {"distance_m": round(dist), "duration_s": round(dist / (kmh / 3.6)), "polyline": line}

    return {"source": "estimate", "walk": mode(WALK_KMH), "car": mode(CAR_KMH), "moto": mode(MOTO_KMH)}


def decode_polyline(encoded: str) -> list[list[float]]:
    """Decodifica o formato 'encoded polyline' do Google em [[lat, lng], ...]."""
    pts, index, lat, lng = [], 0, 0, 0
    while index < len(encoded):
        for is_lng in (False, True):
            shift = result = 0
            while True:
                b = ord(encoded[index]) - 63
                index += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20:
                    break
            delta = ~(result >> 1) if result & 1 else result >> 1
            if is_lng:
                lng += delta
            else:
                lat += delta
        pts.append([lat / 1e5, lng / 1e5])
    return pts


def _directions(o, d, mode, key, http_get) -> dict | None:
    r = http_get(
        "https://maps.googleapis.com/maps/api/directions/json",
        params={"origin": f"{o[0]},{o[1]}", "destination": f"{d[0]},{d[1]}",
                "mode": mode, "key": key, "language": "pt-BR"},
        timeout=8,
    )
    data = r.json()
    if data.get("status") != "OK" or not data.get("routes"):
        return None
    route = data["routes"][0]
    legs = route["legs"]
    return {
        "distance_m": sum(l["distance"]["value"] for l in legs),
        "duration_s": sum(l["duration"]["value"] for l in legs),
        "polyline": decode_polyline(route["overview_polyline"]["points"]),
    }


def get_route(o_lat, o_lng, d_lat, d_lng, http_get=None) -> dict:
    """Rota por meio de transporte. Nunca levanta erro de rede: cai na estimativa."""
    base = estimate_route(o_lat, o_lng, d_lat, d_lng)
    key = os.getenv("GOOGLE_MAPS_API_KEY")
    if not key:
        return base
    try:
        if http_get is None:
            import httpx
            http_get = httpx.get
        walk = _directions((o_lat, o_lng), (d_lat, d_lng), "walking", key, http_get)
        car = _directions((o_lat, o_lng), (d_lat, d_lng), "driving", key, http_get)
        if not walk or not car:
            return base
        # Moto: mesmo traçado do carro, tempo um pouco menor (fator ajustável).
        moto = dict(car, duration_s=round(car["duration_s"] * 0.85))
        return {"source": "google", "walk": walk, "car": car, "moto": moto}
    except Exception:
        return base


# --------------------------------------------------------------------- Clima
_WMO = {  # código WMO (Open-Meteo) -> (rótulo, ícone)
    0: ("Céu limpo", "sunny"), 1: ("Predomina sol", "sunny"), 2: ("Parcialmente nublado", "partly"),
    3: ("Nublado", "cloudy"), 45: ("Neblina", "fog"), 48: ("Neblina", "fog"),
    51: ("Garoa", "rain"), 53: ("Garoa", "rain"), 55: ("Garoa forte", "rain"),
    61: ("Chuva fraca", "rain"), 63: ("Chuva", "rain"), 65: ("Chuva forte", "rain"),
    80: ("Pancadas de chuva", "rain"), 81: ("Pancadas de chuva", "rain"), 82: ("Chuva intensa", "rain"),
    95: ("Trovoada", "storm"), 96: ("Trovoada", "storm"), 99: ("Trovoada", "storm"),
}


def parse_weather(payload: dict) -> dict:
    cur = payload["current"]
    c = float(cur["temperature_2m"])
    label, icon = _WMO.get(int(cur["weather_code"]), ("Tempo instável", "cloudy"))
    if icon == "sunny" and not cur.get("is_day", 1):
        icon = "night"
    return {"available": True, "temp_c": round(c), "temp_f": round(c * 9 / 5 + 32),
            "label": label, "icon": icon}


def get_weather(lat: float, lng: float, http_get=None) -> dict:
    try:
        if http_get is None:
            import httpx
            http_get = httpx.get
        r = http_get("https://api.open-meteo.com/v1/forecast",
                     params={"latitude": lat, "longitude": lng,
                             "current": "temperature_2m,weather_code,is_day"}, timeout=6)
        return parse_weather(r.json())
    except Exception:
        return {"available": False}
