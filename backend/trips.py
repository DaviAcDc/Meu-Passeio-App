"""Trajetos compartilhados (acompanhamento em tempo real por um amigo).

Guardado em MEMÓRIA: serve para o MVP/demo. Em produção use Redis ou o banco,
com autenticação e expiração. Privacidade: só quem tem o link (id aleatório)
vê a posição; só quem tem o update_token consegue atualizá-la.
"""
import secrets
import time

TTL_S = 6 * 3600
MAX_TRIPS = 500
_TRIPS: dict[str, dict] = {}


def _purge(now: float) -> None:
    for tid in [t for t, v in _TRIPS.items() if now - v["created"] > TTL_S]:
        del _TRIPS[tid]
    while len(_TRIPS) >= MAX_TRIPS:  # remove os mais antigos
        del _TRIPS[min(_TRIPS, key=lambda t: _TRIPS[t]["created"])]


def create_trip(dest_name: str, dest_lat: float, dest_lng: float,
                origin_lat: float, origin_lng: float, now: float | None = None) -> dict:
    now = time.time() if now is None else now
    _purge(now)
    tid, token = secrets.token_urlsafe(6), secrets.token_urlsafe(12)
    _TRIPS[tid] = {
        "created": now, "update_token": token, "dest_name": dest_name,
        "dest": [dest_lat, dest_lng], "origin": [origin_lat, origin_lng],
        "position": [origin_lat, origin_lng], "updated": now, "finished": False,
    }
    return {"id": tid, "update_token": token}


def update_position(tid: str, token: str, lat: float, lng: float,
                    finished: bool = False, now: float | None = None) -> bool:
    t = _TRIPS.get(tid)
    if not t or not secrets.compare_digest(t["update_token"], token):
        return False
    t["position"] = [lat, lng]
    t["updated"] = time.time() if now is None else now
    t["finished"] = finished
    return True


def get_trip(tid: str, now: float | None = None) -> dict | None:
    now = time.time() if now is None else now
    t = _TRIPS.get(tid)
    if not t or now - t["created"] > TTL_S:
        return None
    return {k: v for k, v in t.items() if k != "update_token"}


VIEWER_HTML = """<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Acompanhar trajeto</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
 html,body{height:100%;margin:0;font-family:system-ui,sans-serif;color:#0b2545}
 #map{height:calc(100% - 76px)}
 #bar{height:76px;box-sizing:border-box;padding:12px 16px;background:#0b2545;color:#fff}
 #bar b{color:#ff7a1a} #bar small{opacity:.8;display:block;margin-top:4px}
</style></head><body>
<div id="map"></div>
<div id="bar"><div id="t">Carregando...</div><small id="s"></small></div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
 const id = location.pathname.split('/').pop();
 const map = L.map('map', {zoomControl:false}).setView([-2.5297,-44.3028], 16);
 L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
   {maxZoom:19, attribution:'&copy; OpenStreetMap'}).addTo(map);
 let me, dest;
 async function tick(){
   try{
     const r = await fetch('/trips/'+id); if(!r.ok) throw 0;
     const t = await r.json();
     const p = t.position;
     if(!me){ me = L.circleMarker(p,{radius:9,color:'#fff',weight:3,fillColor:'#ff7a1a',fillOpacity:1}).addTo(map);
              dest = L.circleMarker(t.dest,{radius:9,color:'#fff',weight:3,fillColor:'#0b2545',fillOpacity:1}).addTo(map);
              map.fitBounds([p,t.dest],{padding:[60,60]}); }
     me.setLatLng(p);
     document.getElementById('t').innerHTML = t.finished ? 'Chegou em <b>'+t.dest_name+'</b>' : 'Indo para <b>'+t.dest_name+'</b>';
     document.getElementById('s').textContent = 'Atualizado ' + new Date(t.updated*1000).toLocaleTimeString();
   }catch(e){ document.getElementById('t').textContent = 'Trajeto não encontrado ou expirado'; }
 }
 tick(); setInterval(tick, 5000);
</script></body></html>
"""
