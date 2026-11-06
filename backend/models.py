"""Modelagem de dados (SQLAlchemy 2.0) do app Centro Histórico de São Luís.

Em produção, troque a URL do SQLite por PostgreSQL (ex.: postgresql+psycopg://...).
Para consultas geográficas pesadas, use PostGIS no Postgres.
"""
from datetime import datetime, timezone

from sqlalchemy import (Boolean, DateTime, Float, ForeignKey, Integer, String,
                        Text, create_engine)
from sqlalchemy.orm import (DeclarativeBase, Mapped, mapped_column,
                            relationship, sessionmaker)

DATABASE_URL = "sqlite:///./centro_historico.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Store(Base):
    """Loja, restaurante, café, hotel ou ponto comercial."""
    __tablename__ = "stores"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    category: Mapped[str] = mapped_column(String(40))  # restaurante, cafe, artesanato, hotel
    description: Mapped[str] = mapped_column(Text, default="")
    address: Mapped[str] = mapped_column(String(200), default="")
    lat: Mapped[float] = mapped_column(Float)
    lng: Mapped[float] = mapped_column(Float)
    opens_at: Mapped[str] = mapped_column(String(5), default="09:00")   # "HH:MM"
    closes_at: Mapped[str] = mapped_column(String(5), default="18:00")
    image_url: Mapped[str | None] = mapped_column(String(300), nullable=True)
    # Monetização
    commission_rate: Mapped[float] = mapped_column(Float, default=0.12)  # 12% por pedido
    sponsored_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    dishes: Mapped[list["Dish"]] = relationship(back_populates="store", cascade="all, delete-orphan")

    @property
    def is_sponsored(self) -> bool:
        if not self.sponsored_until:
            return False
        until = self.sponsored_until
        if until.tzinfo is None:
            until = until.replace(tzinfo=timezone.utc)
        return until >= utcnow()


class Dish(Base):
    __tablename__ = "dishes"

    id: Mapped[int] = mapped_column(primary_key=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"))
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    history_note: Mapped[str] = mapped_column(Text, default="")  # curiosidade cultural do prato
    price: Mapped[float] = mapped_column(Float)
    image_url: Mapped[str | None] = mapped_column(String(300), nullable=True)
    available: Mapped[bool] = mapped_column(Boolean, default=True)

    store: Mapped[Store] = relationship(back_populates="dishes")
    addons: Mapped[list["DishAddon"]] = relationship(back_populates="dish", cascade="all, delete-orphan")


class DishAddon(Base):
    """Adicionais personalizáveis (ex.: porção extra de camarão)."""
    __tablename__ = "dish_addons"

    id: Mapped[int] = mapped_column(primary_key=True)
    dish_id: Mapped[int] = mapped_column(ForeignKey("dishes.id"))
    name: Mapped[str] = mapped_column(String(80))
    price: Mapped[float] = mapped_column(Float, default=0.0)

    dish: Mapped[Dish] = relationship(back_populates="addons")


class Mansion(Base):
    """Casarão histórico (conteúdo curado)."""
    __tablename__ = "mansions"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    year_built: Mapped[int | None] = mapped_column(Integer, nullable=True)
    style: Mapped[str] = mapped_column(String(80), default="")  # ex.: azulejos portugueses
    lat: Mapped[float] = mapped_column(Float)
    lng: Mapped[float] = mapped_column(Float)
    image_url: Mapped[str | None] = mapped_column(String(300), nullable=True)
    visit_info: Mapped[str] = mapped_column(String(200), default="")


class Event(Base):
    """Eventos culturais e roteiros guiados (gratuitos ou pagos)."""
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(140))
    kind: Mapped[str] = mapped_column(String(20), default="evento")  # evento | roteiro
    description: Mapped[str] = mapped_column(Text, default="")
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    location_name: Mapped[str] = mapped_column(String(140), default="")
    lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    ticket_price: Mapped[float] = mapped_column(Float, default=0.0)  # 0 = gratuito
    organizer: Mapped[str] = mapped_column(String(120), default="")
    platform_fee_rate: Mapped[float] = mapped_column(Float, default=0.10)


class SafeZone(Base):
    """Pontos de apoio ao turista. Em produção, validar com órgãos oficiais."""
    __tablename__ = "safe_zones"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    kind: Mapped[str] = mapped_column(String(40))  # apoio_turista, posto_policial, hospital
    description: Mapped[str] = mapped_column(Text, default="")
    lat: Mapped[float] = mapped_column(Float)
    lng: Mapped[float] = mapped_column(Float)


class Post(Base):
    """Post do feed social (foto, avaliação, comentário)."""
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    author_name: Mapped[str] = mapped_column(String(80))
    author_type: Mapped[str] = mapped_column(String(20), default="turista")  # turista | morador
    text: Mapped[str] = mapped_column(Text)
    photo_url: Mapped[str | None] = mapped_column(String(300), nullable=True)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)  # 1..5
    store_id: Mapped[int | None] = mapped_column(ForeignKey("stores.id"), nullable=True)
    mansion_id: Mapped[int | None] = mapped_column(ForeignKey("mansions.id"), nullable=True)
    likes: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    store: Mapped[Store | None] = relationship()
    mansion: Mapped[Mansion | None] = relationship()
    comments: Mapped[list["Comment"]] = relationship(cascade="all, delete-orphan")


class Comment(Base):
    __tablename__ = "comments"

    id: Mapped[int] = mapped_column(primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("posts.id"))
    author_name: Mapped[str] = mapped_column(String(80))
    text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"))
    customer_name: Mapped[str] = mapped_column(String(80))
    status: Mapped[str] = mapped_column(String(20), default="recebido")
    notes: Mapped[str] = mapped_column(Text, default="")
    subtotal: Mapped[float] = mapped_column(Float)
    commission_rate: Mapped[float] = mapped_column(Float)
    commission_value: Mapped[float] = mapped_column(Float)  # receita da plataforma
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    items: Mapped[list["OrderItem"]] = relationship(cascade="all, delete-orphan")


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"))
    dish_id: Mapped[int] = mapped_column(ForeignKey("dishes.id"))
    dish_name: Mapped[str] = mapped_column(String(120))
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit_price: Mapped[float] = mapped_column(Float)  # prato + adicionais
    addons_text: Mapped[str] = mapped_column(String(300), default="")
    note: Mapped[str] = mapped_column(String(300), default="")
