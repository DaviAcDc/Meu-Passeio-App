"""Dados mockados realistas do Centro Histórico de São Luís.

Nomes de lojas e pratos de lojas são FICTÍCIOS (para demo). Os casarões e
marcos históricos são lugares reais, mas coordenadas e textos são aproximados
e devem ser revisados com curadoria (IPHAN, SECMA, historiadores locais).
"""
from datetime import timedelta

from sqlalchemy.orm import Session

from models import (Comment, Dish, DishAddon, Event, Mansion, Post, SafeZone,
                    Store, utcnow)


def seed(db: Session) -> None:
    if db.query(Store).count() > 0:
        return

    now = utcnow()

    # ---------------------------------------------------------------- Lojas
    cuxa = Store(
        name="Cuxá da Dona Zefa", category="restaurante",
        description="Cozinha maranhense de casarão, servida em salão com azulejos antigos.",
        address="Rua Portugal, Praia Grande", lat=-2.5314, lng=-44.3037,
        opens_at="11:00", closes_at="22:00", sponsored_until=now + timedelta(days=20),
        commission_rate=0.12,
    )
    giz = Store(
        name="Casarão do Giz Café", category="cafe",
        description="Café e doceria em casarão restaurado, com varanda para a rua.",
        address="Rua do Giz, Centro", lat=-2.5322, lng=-44.3029,
        opens_at="08:00", closes_at="19:00", commission_rate=0.10,
    )
    mar = Store(
        name="Mar de Sururu", category="restaurante",
        description="Frutos do mar da baía de São Marcos, com receitas de família.",
        address="Praça Nauro Machado, Reviver", lat=-2.5309, lng=-44.3052,
        opens_at="11:30", closes_at="23:00", commission_rate=0.12,
    )
    tulha = Store(
        name="Ateliê Azulejo & Palha", category="artesanato",
        description="Artesanato local: palha de buriti, cerâmica e azulejos pintados à mão.",
        address="Rua Afonso Pena, Centro", lat=-2.5287, lng=-44.3018,
        opens_at="09:00", closes_at="18:00", commission_rate=0.08,
    )
    hotel = Store(
        name="Pousada Sobrado Real", category="hotel",
        description="Pousada boutique em sobrado do século XIX.",
        address="Rua da Palma, Centro", lat=-2.5295, lng=-44.3024,
        opens_at="00:00", closes_at="23:59", sponsored_until=now + timedelta(days=5),
        commission_rate=0.0,
    )
    # Rua Grande: principal rua comercial do centro (coordenadas aproximadas, mock)
    sapato = Store(
        name="Calçados Rua Grande", category="calcados",
        description="Sandálias, tênis e calçados para toda a família, no coração da Rua Grande.",
        address="Rua Grande, Centro", lat=-2.5278, lng=-44.2995,
        opens_at="08:30", closes_at="18:00", commission_rate=0.08,
    )
    moda = Store(
        name="Moda Grande", category="roupas",
        description="Roupas casuais e moda praia numa das lojas mais antigas da rua.",
        address="Rua Grande, Centro", lat=-2.5281, lng=-44.2988,
        opens_at="08:30", closes_at="18:00", commission_rate=0.08,
    )
    db.add_all([cuxa, giz, mar, tulha, hotel, sapato, moda])
    db.flush()

    # --------------------------------------------------------------- Pratos
    def dish(store, name, desc, price, history="", addons=()):
        d = Dish(store_id=store.id, name=name, description=desc, price=price, history_note=history)
        d.addons = [DishAddon(name=n, price=p) for n, p in addons]
        db.add(d)

    dish(cuxa, "Arroz de Cuxá",
         "Arroz com molho de vinagreira (azedinha) e gergelim torrado, camarão seco e pimenta de cheiro.",
         34.90,
         "O cuxá é um dos pratos mais identitários do Maranhão, com raízes na culinária afro-brasileira.",
         [("Camarão seco extra", 8.0), ("Ovo frito", 4.0), ("Farofa d'água", 3.0)])
    dish(cuxa, "Torta de Camarão",
         "Torta cremosa de camarão em massa amanteigada, servida morna com salada.",
         29.90, "Prato típico de festas e almoços de domingo nas casas maranhenses.",
         [("Salada extra", 5.0), ("Pimenta da casa", 0.0)])
    dish(cuxa, "Peixe Frito com Pirão",
         "Posta de pescada frita, pirão de peixe, arroz branco e vinagrete.",
         42.00, "", [("Arroz de Maria Isabel", 6.0), ("Porção de farinha", 2.0)])
    dish(cuxa, "Guaraná Jesus (lata)",
         "O refrigerante cor-de-rosa que é a cara do Maranhão, bem gelado.", 7.00,
         "Refrigerante criado no Maranhão, símbolo da cultura local.")

    dish(giz, "Cuscuz Maranhense com Ovos",
         "Cuscuz de flocos de milho com ovos mexidos e café coado.", 18.00,
         "", [("Queijo coalho", 6.0), ("Manteiga de garrafa", 2.0)])
    dish(giz, "Bolo de Macaxeira",
         "Fatia de bolo de macaxeira com coco, receita de vó.", 12.00)
    dish(giz, "Suco de Juçara",
         "A juçara maranhense, mais ácida e intensa, batida na hora.", 14.00,
         "A juçara é uma palmeira típica; o fruto é primo do açaí paraense.",
         [("Com tapioca", 5.0), ("Com granola", 4.0)])
    dish(giz, "Doce de Espécie",
         "Doce tradicional de coco e especiarias, típico das festas maranhenses.", 9.00)

    dish(mar, "Caldo de Sururu",
         "Caldo grosso de sururu com leite de coco e coentro.", 26.00, "",
         [("Pimenta", 0.0), ("Farinha", 2.0)])
    dish(mar, "Casquinha de Caranguejo",
         "Carne de caranguejo gratinada na própria casca.", 22.00)
    dish(mar, "Moqueca de Camarão",
         "Moqueca com leite de coco e azeite de dendê, serve duas pessoas.", 78.00,
         "", [("Arroz extra", 8.0), ("Pirão extra", 8.0)])

    dish(tulha, "Bolsa de Palha de Buriti",
         "Peça artesanal feita por artesãs da região dos Lençóis.", 120.00)
    dish(tulha, "Azulejo Pintado à Mão",
         "Reprodução de padrão histórico, 15x15 cm.", 45.00,
         "", [("Moldura de madeira", 15.0)])

    # --------------------------------------------------------------- Casarões
    mansions = [
        Mansion(name="Palácio dos Leões", year_built=1612, style="Colonial / neoclássico",
                description="Sede do governo estadual, de onde se avista a baía. Conta a história da fundação francesa de São Luís.",
                lat=-2.5290, lng=-44.3034, visit_info="Visitas guiadas gratuitas em dias específicos (confirmar)."),
        Mansion(name="Casa das Tulhas", year_built=1830, style="Colonial",
                description="Antigo armazém, hoje mercado com produtos regionais.",
                lat=-2.5315, lng=-44.3046, visit_info="Funciona como mercado tradicional."),
        Mansion(name="Teatro Arthur Azevedo", year_built=1817, style="Neoclássico",
                description="Um dos teatros mais antigos do Brasil, com programação cultural regular.",
                lat=-2.5302, lng=-44.3012, visit_info="Consultar programação e horários de visita."),
        Mansion(name="Casario da Rua Portugal", year_built=1800, style="Azulejos portugueses",
                description="Conjunto de sobrados com fachadas de azulejos coloridos, ícone do Centro Histórico.",
                lat=-2.5313, lng=-44.3040, visit_info="Passeio livre pela rua."),
    ]
    db.add_all(mansions)

    # --------------------------------------------------------- Pontos de apoio
    db.add_all([
        SafeZone(name="Posto de Apoio ao Turista (mock)", kind="apoio_turista",
                 description="Ponto fictício: substituir por pontos oficiais validados.",
                 lat=-2.5298, lng=-44.3030),
        SafeZone(name="Base de Segurança Comunitária (mock)", kind="posto_policial",
                 description="Ponto fictício para demonstração.", lat=-2.5308, lng=-44.3043),
    ])

    # ------------------------------------------------------------------ Eventos
    db.add_all([
        Event(title="Roteiro dos Azulejos", kind="roteiro",
              description="Caminhada guiada de 2h pelo Centro Histórico com história e fotos.",
              starts_at=now + timedelta(days=3, hours=2), location_name="Praça Benedito Leite",
              lat=-2.5283, lng=-44.3022, ticket_price=45.0, organizer="Guias Associados (mock)"),
        Event(title="Roda de Tambor de Crioula", kind="evento",
              description="Apresentação cultural aberta ao público.",
              starts_at=now + timedelta(days=5, hours=4), location_name="Praça Nauro Machado",
              lat=-2.5309, lng=-44.3052, ticket_price=0.0, organizer="Grupo cultural (mock)"),
        Event(title="Noite de Chorinho no Casarão", kind="evento",
              description="Música ao vivo com petiscos regionais.",
              starts_at=now + timedelta(days=9, hours=5), location_name="Casarão do Giz Café",
              lat=-2.5322, lng=-44.3029, ticket_price=30.0, organizer="Casarão do Giz Café"),
    ])

    # ------------------------------------------------------------------- Feed
    p1 = Post(author_name="Marina (turista)", author_type="turista", rating=5,
              text="Almocei o cuxá no casarão e fiquei encantada com os azulejos. Voltaria só por isso!",
              store_id=cuxa.id, likes=12)
    p2 = Post(author_name="Seu Raimundo", author_type="morador", rating=None,
              text="Dica de morador: o fim da tarde na Praça Nauro Machado é o melhor horário para fotos.",
              likes=31)
    p3 = Post(author_name="Lucas", author_type="turista", rating=4,
              text="Suco de juçara no Giz Café, bem diferente do açaí. Recomendo experimentar.",
              store_id=giz.id, likes=7)
    p1.comments = [Comment(author_name="Seu Raimundo", text="Boa escolha! Peça com camarão seco extra.")]
    db.add_all([p1, p2, p3])
    db.commit()
