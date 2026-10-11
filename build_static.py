#!/usr/bin/env python3
"""Gera em public/ a versão estática pronta para o GitHub Pages."""

from __future__ import annotations

import html
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

from server import SITE_URL, category_url, load_products, product_page, product_public, slugify

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "public"
STATIC_FILES = ("styles.css", "app.js", "consent-init.js", "analytics.js", "sharing.js", "privacidade.html", "favicon.svg", "site.webmanifest", "ads.txt")


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def money(value):
    return f"R$ {float(value or 0):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def discount_of(product):
    price = float(product.get("price") or 0)
    old_price = float(product.get("oldPrice") or 0)
    return round((1 - price / old_price) * 100) if old_price > price > 0 else 0


def time_ago(value):
    try:
        published = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if published.tzinfo is None:
            published = published.replace(tzinfo=timezone.utc)
        hours = max(1, int((datetime.now(timezone.utc) - published).total_seconds() // 3600))
        if hours < 24:
            return f"há {hours} hora{'s' if hours != 1 else ''}"
        days = max(1, hours // 24)
        return f"há {days} dia{'s' if days != 1 else ''}"
    except (TypeError, ValueError):
        return "publicada recentemente"


def product_card(product):
    item = product_public(product)
    name = html.escape(str(item.get("name") or ""), quote=True)
    description = html.escape(str(item.get("description") or ""), quote=True)
    image = html.escape(str(item.get("image") or ""), quote=True)
    category = html.escape(str(item.get("category") or "Ofertas"), quote=True)
    store = html.escape(str(item.get("store") or "Loja"), quote=True)
    store_class = slugify(item.get("storeClass") or item.get("store") or "loja")
    offer_url = html.escape(str(item.get("url") or "#"), quote=True)
    detail_url = html.escape(item["detailUrl"], quote=True)
    badge = html.escape(str(item.get("badge") or "Oferta verificada"), quote=True)
    installment = html.escape(str(item.get("installment") or "Consulte as condições na loja"), quote=True)
    product_id = html.escape(str(item.get("id") or ""), quote=True)
    discount = discount_of(item)
    discount_html = f'<span class="discount-badge">-{discount}%</span>' if discount else ""
    price = float(item.get("price") or 0)
    old_price = float(item.get("oldPrice") or 0)
    price_html = money(price) if price > 0 else "Consulte o preço"
    old_price_html = f"<del>{money(old_price)}</del>" if old_price > price > 0 else ""
    return f'''<article class="product-card" itemprop="itemListElement" itemscope itemtype="https://schema.org/ListItem">
      <meta itemprop="position" content="0">
      <div class="product-media">
        <a href="{detail_url}" itemprop="url" aria-label="Ver detalhes de {name}"><img src="{image}" alt="{name}" loading="lazy" width="700" height="500"></a>
        {discount_html}
        <button class="heart-button" type="button" data-favorite="{product_id}" aria-label="Adicionar aos favoritos"><svg><use href="#icon-heart"></use></svg></button>
      </div>
      <div class="product-info">
        <div class="product-topline"><span class="category-pill">{category}</span><span class="product-time"><svg><use href="#icon-clock"></use></svg>{time_ago(item.get('publishedAt'))}</span></div>
        <h3 itemprop="name"><a href="{detail_url}">{name}</a></h3>
        <p>{description}</p>
        <div class="editor-pick"><svg><use href="#icon-check"></use></svg>{badge}</div>
      </div>
      <div class="product-buy">
        <span class="store store-{store_class}">{store}</span>
        <div class="price-row"><strong>{price_html}</strong>{old_price_html}</div>
        <small>{installment}</small>
        <a class="button button-green" href="{offer_url}" target="_blank" rel="noopener sponsored" data-offer-link data-product-id="{product_id}" data-store="{store}">Ver oferta <svg><use href="#icon-external"></use></svg></a>
        <button class="share-trigger" type="button" data-share-trigger data-share-url="{detail_url}" aria-label="Compartilhar oferta" aria-haspopup="menu" aria-expanded="false"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="18" cy="5" r="3"></circle><circle cx="6" cy="12" r="3"></circle><circle cx="18" cy="19" r="3"></circle><path d="m8.6 10.5 6.8-4M8.6 13.5l6.8 4"></path></svg>Compartilhar</button>
      </div>
    </article>'''


def category_links(products, active="Todos"):
    categories = sorted({str(product.get("category") or "Ofertas") for product in products})
    links = []
    for category in ["Todos", *categories]:
        url = "/#ofertas" if category == "Todos" else category_url(category)
        icon = '<svg><use href="#icon-tag"></use></svg>' if category == "Todos" else ""
        selected = " active" if category == active else ""
        links.append(
            f'<a href="{html.escape(url, quote=True)}" class="category-button{selected}" data-category="{html.escape(category, quote=True)}">{icon}{html.escape(category)}</a>'
        )
    return "".join(links)


def item_list_schema(products, name):
    payload = {
        "@context": "https://schema.org",
        "@type": "ItemList",
        "name": name,
        "numberOfItems": len(products),
        "itemListElement": [
            {
                "@type": "ListItem",
                "position": position,
                "url": f"{SITE_URL}{product_public(product)['detailUrl']}",
                "name": product.get("name"),
            }
            for position, product in enumerate(products, 1)
        ],
    }
    encoded = json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")
    return f'<script id="productsSchema" type="application/ld+json">{encoded}</script>'


def render_listing(template, all_products, listed_products, active="Todos"):
    rendered = template.replace("<!-- STATIC_CATEGORIES -->", category_links(all_products, active))
    cards = "\n".join(product_card(product).replace('content="0"', f'content="{position}"', 1) for position, product in enumerate(listed_products, 1))
    rendered = rendered.replace("<!-- STATIC_PRODUCTS -->", cards)
    rendered = rendered.replace('<b id="resultCount">0</b>', f'<b id="resultCount">{len(listed_products)}</b>')
    rendered = rendered.replace("</head>", f"    {item_list_schema(listed_products, 'Ofertas em destaque' if active == 'Todos' else f'Ofertas de {active}')}\n  </head>")
    rendered = rendered.replace('<body data-category="Todos">', f'<body data-category="{html.escape(active, quote=True)}">')
    if listed_products:
        featured = next((product for product in listed_products if product.get("featured")), listed_products[0])
        rendered = rendered.replace('id="heroTitle">Oferta da semana', f'id="heroTitle">{html.escape(str(featured.get("name") or "Oferta da semana"))}')
        rendered = rendered.replace('id="featuredImage" src="https://images.unsplash.com/photo-1546868871-7041f2a55e12?auto=format&fit=crop&w=760&q=90"', f'id="featuredImage" src="{html.escape(str(featured.get("image") or ""), quote=True)}"')
        rendered = rendered.replace('id="featuredPrice">R$ 899', f'id="featuredPrice">{money(featured.get("price"))}')
        rendered = rendered.replace('id="featuredInstallment">até 10x sem juros', f'id="featuredInstallment">{html.escape(str(featured.get("installment") or "Consulte as condições"))}')
        rendered = rendered.replace('id="featuredLink" href="#ofertas"', f'id="featuredLink" href="{html.escape(str(featured.get("url") or "#ofertas"), quote=True)}" target="_blank" rel="noopener sponsored"')
    return rendered


def main():
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    OUTPUT.mkdir()

    products = load_products()
    public_products = [product_public(product) for product in products]

    template = (ROOT / "index.html").read_text(encoding="utf-8")
    template = template.replace('          <a href="admin.html">Cadastrar</a>\n', "")
    index = render_listing(template, products, products)
    write(OUTPUT / "index.html", index)

    for filename in STATIC_FILES:
        shutil.copy2(ROOT / filename, OUTPUT / filename)

    products_javascript = json.dumps(public_products, ensure_ascii=False).replace("</", "<\\/")
    write(OUTPUT / "products.js", f"const PRODUCTS = {products_javascript};\n")

    base_image = ROOT / "Imagens_Base" / "BaseLayout.png"
    if base_image.exists():
        target = OUTPUT / "Imagens_Base" / "BaseLayout.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(base_image, target)

    write(OUTPUT / "data" / "products.json", json.dumps(public_products, ensure_ascii=False, indent=2))

    sitemap_urls = [
        f"  <url><loc>{SITE_URL}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>",
        f"  <url><loc>{SITE_URL}/privacidade.html</loc><changefreq>yearly</changefreq><priority>0.3</priority></url>",
    ]
    categories = sorted({str(product.get("category") or "Ofertas") for product in products})
    for category in categories:
        category_products = [product for product in products if str(product.get("category") or "Ofertas") == category]
        category_page = render_listing(template, products, category_products, category)
        category_title = f"Ofertas de {category} | WiseOff"
        category_description = f"Encontre ofertas de {category}, descontos verificados e produtos selecionados nas principais lojas do Brasil."
        category_page = category_page.replace("WiseOff — Ofertas que realmente valem a pena", html.escape(category_title))
        category_page = category_page.replace(
            "Encontre ofertas verificadas, descontos reais e produtos selecionados nas principais lojas do Brasil. Economize com a curadoria independente da WiseOff.",
            html.escape(category_description, quote=True),
        )
        category_page = category_page.replace('content="https://wiseoff.com.br/"', f'content="{SITE_URL}{category_url(category)}"')
        category_page = category_page.replace('href="https://wiseoff.com.br/"', f'href="{SITE_URL}{category_url(category)}"')
        category_page = category_page.replace("<h2>Ofertas em destaque</h2>", f"<h2>Ofertas de {html.escape(category)}</h2>")
        category_page = category_page.replace("Produtos selecionados e recomendados pela nossa equipe.", f"Produtos de {html.escape(category)} selecionados pela WiseOff.")
        write(OUTPUT / category_url(category).strip("/") / "index.html", category_page)
        sitemap_urls.append(
            f"  <url><loc>{SITE_URL}{category_url(category)}</loc><changefreq>daily</changefreq><priority>0.7</priority></url>"
        )
    for product in products:
        item = product_public(product)
        write(OUTPUT / "produto" / item["slug"] / "index.html", product_page(product))
        modified = str(product.get("updatedAt") or product.get("publishedAt") or "")[:10]
        lastmod = f"<lastmod>{html.escape(modified)}</lastmod>" if modified else ""
        sitemap_urls.append(
            f"  <url><loc>{SITE_URL}{item['detailUrl']}</loc>{lastmod}<changefreq>daily</changefreq><priority>0.8</priority></url>"
        )

    sitemap = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    sitemap += "\n".join(sitemap_urls) + "\n</urlset>\n"
    write(OUTPUT / "sitemap.xml", sitemap)
    write(OUTPUT / "robots.txt", f"User-agent: *\nAllow: /\nSitemap: {SITE_URL}/sitemap.xml\n")
    write(OUTPUT / "CNAME", "wiseoff.com.br\n")
    write(OUTPUT / ".nojekyll", "")
    write(
        OUTPUT / "404.html",
        """<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Página não encontrada | WiseOff</title><link rel="stylesheet" href="/styles.css"></head><body><main class="empty-state" style="max-width:620px;margin:12vh auto"><h1>Página não encontrada</h1><p>Esta oferta pode ter expirado ou mudado de endereço.</p><a class="button button-green" href="/">Voltar para as ofertas</a></main></body></html>""",
    )

    print(f"Publicação gerada em {OUTPUT}")
    print(f"Produtos publicados: {len(products)}")


if __name__ == "__main__":
    main()
