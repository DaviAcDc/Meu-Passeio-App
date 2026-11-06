"""API do app Centro Histórico de São Luís (MVP).

Rodar:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
Docs:   http://localhost:8000/docs
"""
import math
from contextlib import asynccontextmanager
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from models import (Base, Comment, Dish, DishAddon, Event, Mansion, Order,
                    OrderItem, Post, SafeZone, SessionLocal, Store, engine)
from routing import get_route, get_weather, matches_query
from trips import VIEWER_HTML, create_trip, get_trip, update_position
from seed import seed

TZ = ZoneInfo("America/Fortaleza")  # mesmo fuso do Maranhão (UTC-3, sem horário de verão)


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        seed(db)
    yield


app = FastAPI(title="Centro Histórico SLZ API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ----------------------------------------------------------------- Utilitários
def haversine_km(lat1, lng1, lat2, lng2) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def is_open_now(store: Store, now: datetime | None = None) -> bool:
    now = now or datetime.now(TZ)
    cur = now.strftime("%H:%M")
    o, c = store.opens_at, store.closes_at
    if o <= c:
        return o <= cur <= c
    return cur >= o or cur <= c  # horário que cruza a meia-noite


def store_out(s: Store, user_lat=None, user_lng=None) -> dict:
    d = {
        "id": s.id, "name": s.name, "category": s.category,
        "description": s.description, "address": s.address,
        "lat": s.lat, "lng": s.lng, "image_url": s.image_url,
        "opens_at": s.opens_at, "closes_at": s.closes_at,
        "is_open": is_open_now(s), "is_sponsored": s.is_sponsored,
    }
    if user_lat is not None and user_lng is not None:
        d["distance_km"] = round(haversine_km(user_lat, user_lng, s.lat, s.lng), 2)
    return d


def dish_out(d: Dish) -> dict:
    return {
        "id": d.id, "store_id": d.store_id, "name": d.name,
        "description": d.description, "history_note": d.history_note,
        "price": d.price, "image_url": d.image_url, "available": d.available,
        "addons": [{"id": a.id, "name": a.name, "price": a.price} for a in d.addons],
    }


def post_out(p: Post) -> dict:
    return {
        "id": p.id, "author_name": p.author_name, "author_type": p.author_type,
        "text": p.text, "photo_url": p.photo_url, "rating": p.rating,
        "likes": p.likes, "created_at": p.created_at.isoformat(),
        "store": {"id": p.store.id, "name": p.store.name} if p.store else None,
        "mansion": {"id": p.mansion.id, "name": p.mansion.name} if p.mansion else None,
        "comments": [{"author_name": c.author_name, "text": c.text} for c in p.comments],
    }


# ------------------------------------------------------- ABA 1: Mapa inteligente
@app.get("/map/pois")
def map_pois(
    lat: float | None = None, lng: float | None = None,
    radius_km: float = Query(3.0, gt=0, le=50),
    types: str = Query("store,mansion,safe_zone", description="separados por vírgula"),
    db: Session = Depends(get_db),
):
    """Pontos de interesse para os marcadores do mapa (lojas, casarões, zonas seguras)."""
    wanted = {t.strip() for t in types.split(",")}
    pois: list[dict] = []

    def within(plat, plng):
        if lat is None or lng is None:
            return True, None
        dist = haversine_km(lat, lng, plat, plng)
        return dist <= radius_km, round(dist, 2)

    if "store" in wanted:
        for s in db.query(Store).all():
            ok, dist = within(s.lat, s.lng)
            if ok:
                pois.append(store_poi(s, dist))
    if "mansion" in wanted:
        for m in db.query(Mansion).all():
            ok, dist = within(m.lat, m.lng)
            if ok:
                pois.append(mansion_poi(m, dist))
    if "safe_zone" in wanted:
        for z in db.query(SafeZone).all():
            ok, dist = within(z.lat, z.lng)
            if ok:
                pois.append(zone_poi(z, dist))

    # Patrocinados primeiro (monetização), depois por distância
    pois.sort(key=lambda p: (not p.get("is_sponsored", False), p.get("distance_km") or 0))
    return pois


def store_poi(s: Store, dist=None) -> dict:
    return {
        "type": "store", "id": s.id, "name": s.name, "lat": s.lat, "lng": s.lng,
        "category": s.category, "description": s.description, "address": s.address,
        "image_url": s.image_url, "is_open": is_open_now(s),
        "hours": f"{s.opens_at}–{s.closes_at}", "is_sponsored": s.is_sponsored,
        "distance_km": dist,
    }


def mansion_poi(m: Mansion, dist=None) -> dict:
    return {
        "type": "mansion", "id": m.id, "name": m.name, "lat": m.lat, "lng": m.lng,
        "category": "casarao", "description": m.description, "address": m.style,
        "image_url": m.image_url, "summary": m.visit_info, "distance_km": dist,
    }


def zone_poi(z: SafeZone, dist=None) -> dict:
    return {
        "type": "safe_zone", "id": z.id, "name": z.name, "lat": z.lat, "lng": z.lng,
        "category": "apoio", "description": z.description, "address": "",
        "image_url": None, "kind": z.kind, "distance_km": dist,
    }


@app.get("/map/search")
def map_search(
    q: str = Query("", max_length=80),
    lat: float | None = None, lng: float | None = None,
    db: Session = Depends(get_db),
):
    """Busca por nome ou categoria ('loja de calçados', 'restaurantes').
    Se mandar lat/lng do usuário, ordena pelo mais próximo."""
    results: list[dict] = []
    for s in db.query(Store).all():
        if matches_query(q, s.name, s.category, s.description):
            results.append(store_poi(s))
    for m in db.query(Mansion).all():
        if matches_query(q, m.name, "casarao", m.description):
            results.append(mansion_poi(m))
    if lat is not None and lng is not None:
        for r in results:
            r["distance_km"] = round(haversine_km(lat, lng, r["lat"], r["lng"]), 2)
        results.sort(key=lambda r: r["distance_km"])
    else:
        results.sort(key=lambda r: (not r.get("is_sponsored", False), r["name"]))
    return results[:30]


@app.get("/route")
def route(
    from_lat: float = Query(ge=-90, le=90), from_lng: float = Query(ge=-180, le=180),
    to_lat: float = Query(ge=-90, le=90), to_lng: float = Query(ge=-180, le=180),
):
    """Distância, tempo e traçado a pé / de carro / de moto."""
    return get_route(from_lat, from_lng, to_lat, to_lng)


@app.get("/weather")
def weather(lat: float = Query(ge=-90, le=90), lng: float = Query(ge=-180, le=180)):
    """Clima atual em °C e °F (Open-Meteo, sem chave)."""
    return get_weather(lat, lng)


# ------------------------------------------- Compartilhar trajeto com um amigo
class TripIn(BaseModel):
    dest_name: str = Field(min_length=1, max_length=120)
    dest_lat: float = Field(ge=-90, le=90)
    dest_lng: float = Field(ge=-180, le=180)
    origin_lat: float = Field(ge=-90, le=90)
    origin_lng: float = Field(ge=-180, le=180)


class PositionIn(BaseModel):
    update_token: str
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    finished: bool = False


@app.post("/trips", status_code=201)
def trip_create(payload: TripIn):
    return create_trip(**payload.model_dump())


@app.post("/trips/{trip_id}/position")
def trip_position(trip_id: str, payload: PositionIn):
    if not update_position(trip_id, payload.update_token, payload.lat, payload.lng, payload.finished):
        raise HTTPException(404, "Trajeto não encontrado ou token inválido")
    return {"ok": True}


@app.get("/trips/{trip_id}")
def trip_get(trip_id: str):
    t = get_trip(trip_id)
    if not t:
        raise HTTPException(404, "Trajeto não encontrado ou expirado")
    return t


@app.get("/t/{trip_id}", response_class=HTMLResponse, include_in_schema=False)
def trip_page(trip_id: str):
    """Página que o amigo abre no navegador para acompanhar o trajeto."""
    return VIEWER_HTML


# ---------------------------------------------- ABA 2: Marketplace gastronômico
@app.get("/stores")
def list_stores(
    category: str | None = None, q: str | None = None,
    lat: float | None = None, lng: float | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(Store)
    if category:
        query = query.filter(Store.category == category)
    if q:
        query = query.filter(Store.name.ilike(f"%{q}%"))
    stores = [store_out(s, lat, lng) for s in query.all()]
    stores.sort(key=lambda s: (not s["is_sponsored"], not s["is_open"], s["name"]))
    return stores


@app.get("/stores/{store_id}")
def get_store(store_id: int, db: Session = Depends(get_db)):
    s = db.get(Store, store_id)
    if not s:
        raise HTTPException(404, "Loja não encontrada")
    return store_out(s)


@app.get("/stores/{store_id}/menu")
def store_menu(store_id: int, db: Session = Depends(get_db)):
    s = db.get(Store, store_id)
    if not s:
        raise HTTPException(404, "Loja não encontrada")
    return {"store": store_out(s), "dishes": [dish_out(d) for d in s.dishes if d.available]}


class OrderItemIn(BaseModel):
    dish_id: int
    quantity: int = Field(1, ge=1, le=50)
    addon_ids: list[int] = []
    note: str = Field("", max_length=300)


class OrderIn(BaseModel):
    store_id: int
    customer_name: str = Field(min_length=1, max_length=80)
    notes: str = Field("", max_length=500)
    items: list[OrderItemIn] = Field(min_length=1)


@app.post("/orders", status_code=201)
def create_order(payload: OrderIn, db: Session = Depends(get_db)):
    store = db.get(Store, payload.store_id)
    if not store:
        raise HTTPException(404, "Loja não encontrada")
    if not is_open_now(store):
        raise HTTPException(409, "Estabelecimento fechado no momento")

    order_items, subtotal = [], 0.0
    for it in payload.items:
        dish = db.get(Dish, it.dish_id)
        if not dish or dish.store_id != store.id or not dish.available:
            raise HTTPException(400, f"Prato {it.dish_id} inválido para esta loja")
        addons = [a for a in dish.addons if a.id in set(it.addon_ids)]
        if len(addons) != len(set(it.addon_ids)):
            raise HTTPException(400, "Adicional inválido")
        unit = dish.price + sum(a.price for a in addons)
        subtotal += unit * it.quantity
        order_items.append(OrderItem(
            dish_id=dish.id, dish_name=dish.name, quantity=it.quantity, unit_price=unit,
            addons_text=", ".join(a.name for a in addons), note=it.note))

    # Comissão por pedido (receita da plataforma)
    commission = round(subtotal * store.commission_rate, 2)
    order = Order(store_id=store.id, customer_name=payload.customer_name, notes=payload.notes,
                  subtotal=round(subtotal, 2), commission_rate=store.commission_rate,
                  commission_value=commission, items=order_items)
    db.add(order)
    db.commit()
    return {
        "order_id": order.id, "status": order.status, "subtotal": order.subtotal,
        "platform_commission": order.commission_value,
        "store_receives": round(order.subtotal - order.commission_value, 2),
    }


# -------------------------------------------- ABA 3: Guia, eventos e comunidade
@app.get("/mansions")
def list_mansions(db: Session = Depends(get_db)):
    return [{"id": m.id, "name": m.name, "description": m.description,
             "year_built": m.year_built, "style": m.style, "lat": m.lat, "lng": m.lng,
             "image_url": m.image_url, "visit_info": m.visit_info}
            for m in db.query(Mansion).all()]


@app.get("/events")
def list_events(db: Session = Depends(get_db)):
    events = db.query(Event).order_by(Event.starts_at).all()
    return [{"id": e.id, "title": e.title, "kind": e.kind, "description": e.description,
             "starts_at": e.starts_at.isoformat(), "location_name": e.location_name,
             "lat": e.lat, "lng": e.lng, "ticket_price": e.ticket_price,
             "is_free": e.ticket_price == 0, "organizer": e.organizer} for e in events]


@app.get("/safe-zones")
def list_safe_zones(db: Session = Depends(get_db)):
    return [{"id": z.id, "name": z.name, "kind": z.kind, "description": z.description,
             "lat": z.lat, "lng": z.lng} for z in db.query(SafeZone).all()]


@app.get("/feed")
def get_feed(limit: int = Query(30, le=100), store_id: int | None = None,
             db: Session = Depends(get_db)):
    q = db.query(Post)
    if store_id:
        q = q.filter(Post.store_id == store_id)
    return [post_out(p) for p in q.order_by(Post.created_at.desc()).limit(limit).all()]


class PostIn(BaseModel):
    author_name: str = Field(min_length=1, max_length=80)
    author_type: str = Field("turista", pattern="^(turista|morador)$")
    text: str = Field(min_length=1, max_length=1000)
    photo_url: str | None = None
    rating: int | None = Field(None, ge=1, le=5)
    store_id: int | None = None
    mansion_id: int | None = None


@app.post("/feed", status_code=201)
def create_post(payload: PostIn, db: Session = Depends(get_db)):
    if payload.store_id and not db.get(Store, payload.store_id):
        raise HTTPException(404, "Loja não encontrada")
    if payload.mansion_id and not db.get(Mansion, payload.mansion_id):
        raise HTTPException(404, "Casarão não encontrado")
    post = Post(**payload.model_dump())
    db.add(post)
    db.commit()
    db.refresh(post)
    return post_out(post)


@app.post("/feed/{post_id}/like")
def like_post(post_id: int, db: Session = Depends(get_db)):
    post = db.get(Post, post_id)
    if not post:
        raise HTTPException(404, "Post não encontrado")
    post.likes += 1
    db.commit()
    return {"id": post.id, "likes": post.likes}


class CommentIn(BaseModel):
    author_name: str = Field(min_length=1, max_length=80)
    text: str = Field(min_length=1, max_length=500)


@app.post("/feed/{post_id}/comments", status_code=201)
def add_comment(post_id: int, payload: CommentIn, db: Session = Depends(get_db)):
    post = db.get(Post, post_id)
    if not post:
        raise HTTPException(404, "Post não encontrado")
    db.add(Comment(post_id=post_id, **payload.model_dump()))
    db.commit()
    db.refresh(post)
    return post_out(post)


# ------------------------------------------------ Painel B2B (investidores/lojas)
@app.get("/admin/revenue")
def revenue_summary(db: Session = Depends(get_db)):
    """Resumo de receita da plataforma: comissões + patrocínios ativos + ingressos."""
    orders = db.query(Order).all()
    gmv = sum(o.subtotal for o in orders)
    commissions = sum(o.commission_value for o in orders)
    sponsored = sum(1 for s in db.query(Store).all() if s.is_sponsored)
    return {"orders": len(orders), "gmv": round(gmv, 2),
            "commission_revenue": round(commissions, 2), "active_sponsored_stores": sponsored}
