#!/usr/bin/env python3
"""Servidor local da WiseOff com importação de dados de páginas de produto."""

from __future__ import annotations

import html
import ipaddress
import json
import re
import socket
import sys
import threading
import unicodedata
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
DATA_FILE = ROOT / "data" / "products.json"
SITE_URL = "https://wiseoff.com.br"
DATA_LOCK = threading.Lock()
MAX_PAGE_SIZE = 5 * 1024 * 1024
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
)


def load_products():
    try:
        with DATA_LOCK:
            return json.loads(DATA_FILE.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def save_products(products):
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    temporary = DATA_FILE.with_suffix(".tmp")
    with DATA_LOCK:
        temporary.write_text(json.dumps(products, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(DATA_FILE)


def slugify(value):
    normalized = unicodedata.normalize("NFKD", str(value)).encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", normalized.lower()).strip("-")
    return slug[:70] or "oferta"


def product_slug(product):
    return f"{slugify(product.get('name', 'oferta'))}-{product.get('id')}"


def product_public(product):
    result = dict(product)
    result["slug"] = product_slug(product)
    result["detailUrl"] = f"/produto/{result['slug']}/"
    return result


def page_escape(value):
    return html.escape(str(value or ""), quote=True)


def format_brl(value):
    return f"{float(value or 0):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def truncate(value, limit):
    text = clean_text(value)
    if len(text) <= limit:
        return text
    return text[: limit - 1].rsplit(" ", 1)[0].rstrip(".,;:-") + "…"


def product_page(product):
    item = product_public(product)
    name = page_escape(item.get("name"))
    description = page_escape(item.get("description"))
    seo_title = page_escape(truncate(item.get("name"), 54))
    seo_description = page_escape(truncate(item.get("description"), 155))
    image = page_escape(item.get("image"))
    store = page_escape(item.get("store"))
    category = page_escape(item.get("category"))
    offer_url = page_escape(item.get("url"))
    canonical = f"{SITE_URL}{item['detailUrl']}"
    price = float(item.get("price") or 0)
    old_price = float(item.get("oldPrice") or 0)
    display_price = format_brl(price)
    display_old_price = format_brl(old_price)
    discount = round((1 - price / old_price) * 100) if old_price > price > 0 else 0
    discount_badge = f'<span class="discount-badge">-{discount}%</span>' if discount else ""
    old_price_html = f'<del>R$ {display_old_price}</del>' if old_price > price > 0 else ""
    price_html = f'R$ {display_price}' if price > 0 else "Consulte o preço"
    price_meta = f'<meta property="product:price:amount" content="{price:.2f}"><meta property="product:price:currency" content="BRL">' if price > 0 else ""
    offer_schema = {"@type": "Offer", "url": item.get("url"), "seller": {"@type": "Organization", "name": item.get("store")}}
    if price > 0:
        offer_schema.update({"priceCurrency": "BRL", "price": f"{price:.2f}"})
    published = item.get("publishedAt") or datetime.now(timezone.utc).isoformat()
    structured = {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "BreadcrumbList",
                "itemListElement": [
                    {"@type": "ListItem", "position": 1, "name": "Início", "item": f"{SITE_URL}/"},
                    {"@type": "ListItem", "position": 2, "name": category or "Ofertas", "item": f"{SITE_URL}/#ofertas"},
                    {"@type": "ListItem", "position": 3, "name": item.get("name"), "item": canonical},
                ],
            },
            {
                "@type": "Product",
                "@id": f"{canonical}#product",
                "name": item.get("name"),
                "description": item.get("description"),
                "image": [item.get("image")],
                "category": item.get("category"),
                "sku": str(item.get("id")),
                "offers": offer_schema,
            },
        ],
    }
    structured_json = json.dumps(structured, ensure_ascii=False).replace("</", "<\\/")
    return f'''<!doctype html>
<html lang="pt-BR"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="{seo_description}"><meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1">
<link rel="canonical" href="{canonical}"><link rel="alternate" hreflang="pt-BR" href="{canonical}">
<meta property="og:type" content="product"><meta property="og:locale" content="pt_BR"><meta property="og:site_name" content="WiseOff">
<meta property="og:title" content="{seo_title} em oferta | WiseOff"><meta property="og:description" content="{seo_description}">
<meta property="og:url" content="{canonical}"><meta property="og:image" content="{image}"><meta property="og:image:alt" content="{name}">
{price_meta}
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{seo_title} em oferta | WiseOff"><meta name="twitter:description" content="{seo_description}"><meta name="twitter:image" content="{image}">
<title>{seo_title} em oferta | WiseOff</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml"><link rel="manifest" href="/site.webmanifest">
<link rel="stylesheet" href="/styles.css"><script type="application/ld+json">{structured_json}</script>
</head><body class="detail-page">
<header class="site-header"><div class="shell nav-wrap admin-nav"><a class="brand" href="/"><span>Wise<span>Off</span></span><small>Escolha esperta.<br>Preço melhor.</small></a><a class="back-link" href="/#ofertas">← Todas as ofertas</a></div></header>
<main class="detail-main shell">
<nav class="breadcrumbs" aria-label="Navegação estrutural"><a href="/">Início</a><span>›</span><a href="/#ofertas">{category or 'Ofertas'}</a><span>›</span><span>{name}</span></nav>
<article class="detail-card">
<div class="detail-media"><img src="{image}" alt="{name}" width="720" height="720">{discount_badge}</div>
<div class="detail-copy"><span class="category-pill">{category}</span><h1>{name}</h1><p>{description}</p><div class="detail-store">Oferta encontrada na <strong>{store}</strong></div>
<div class="detail-price"><strong>{price_html}</strong>{old_price_html}</div><small>{page_escape(item.get('installment'))}</small>
<a class="button button-green" href="{offer_url}" target="_blank" rel="noopener sponsored nofollow">Ver oferta na {store} →</a>
<p class="affiliate-note">O preço pode mudar a qualquer momento. Confirme as condições no site da loja.</p></div>
</article>
<section class="detail-about"><h2>Sobre esta oferta</h2><p>Esta oferta foi selecionada pela curadoria WiseOff. Comparamos as informações públicas do produto para ajudar você a comprar melhor.</p><time datetime="{page_escape(published)}">Oferta publicada em {page_escape(published[:10])}</time></section>
</main><footer><div class="shell footer-wrap"><a class="brand footer-brand" href="/"><span>Wise<span>Off</span></span></a><p>Boas escolhas para você gastar melhor.</p><small>© 2026 WiseOff</small></div></footer>
</body></html>'''


def clean_text(value):
    if value is None:
        return ""
    value = re.sub(r"<[^>]+>", " ", str(value))
    return re.sub(r"\s+", " ", html.unescape(value)).strip()


def to_number(value):
    if value is None:
        return None
    match = re.search(r"[\d.,]+", str(value).replace("\xa0", ""))
    if not match:
        return None
    number = match.group(0)
    if "," in number and "." in number:
        number = number.replace(".", "").replace(",", ".") if number.rfind(",") > number.rfind(".") else number.replace(",", "")
    elif "," in number:
        number = number.replace(".", "").replace(",", ".")
    try:
        return float(number)
    except ValueError:
        return None


def is_public_url(raw_url):
    parsed = urlparse(raw_url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        return False
    try:
        addresses = socket.getaddrinfo(parsed.hostname, parsed.port or 443, type=socket.SOCK_STREAM)
        for address in addresses:
            ip = ipaddress.ip_address(address[4][0])
            if not ip.is_global:
                return False
    except (socket.gaierror, ValueError):
        return False
    return True


def meta_value(markup, *keys):
    for key in keys:
        patterns = (
            rf'<meta[^>]+(?:property|name|itemprop)=["\']{re.escape(key)}["\'][^>]+content=["\']([^"\']+)',
            rf'<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name|itemprop)=["\']{re.escape(key)}["\']',
        )
        for pattern in patterns:
            match = re.search(pattern, markup, re.I)
            if match:
                return clean_text(match.group(1))
    return ""


def product_nodes(value):
    if isinstance(value, list):
        for item in value:
            yield from product_nodes(item)
    elif isinstance(value, dict):
        node_type = value.get("@type", "")
        types = node_type if isinstance(node_type, list) else [node_type]
        if any(str(item).lower() == "product" for item in types):
            yield value
        for key in ("@graph", "mainEntity", "itemListElement"):
            if key in value:
                yield from product_nodes(value[key])


def json_ld_product(markup):
    scripts = re.findall(
        r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
        markup,
        re.I | re.S,
    )
    for script in scripts:
        try:
            decoded = json.loads(html.unescape(script).strip())
            node = next(product_nodes(decoded), None)
            if node:
                return node
        except (json.JSONDecodeError, StopIteration):
            continue
    return {}


def first_offer(product):
    offers = product.get("offers", {}) if isinstance(product, dict) else {}
    if isinstance(offers, list):
        return offers[0] if offers else {}
    return offers if isinstance(offers, dict) else {}


def image_from(product):
    image = product.get("image", "") if isinstance(product, dict) else ""
    if isinstance(image, list):
        image = image[0] if image else ""
    if isinstance(image, dict):
        image = image.get("url") or image.get("contentUrl") or ""
    return image


def store_from(product, markup, hostname):
    brand = product.get("brand", {}) if isinstance(product, dict) else {}
    if isinstance(brand, dict):
        brand = brand.get("name", "")
    site_name = meta_value(markup, "og:site_name", "application-name")
    known = {
        "amazon.com.br": "Amazon",
        "mercadolivre.com.br": "Mercado Livre",
        "magazineluiza.com.br": "Magalu",
        "kabum.com.br": "KaBuM!",
        "shopee.com.br": "Shopee",
        "americanas.com.br": "Americanas",
        "casasbahia.com.br": "Casas Bahia",
    }
    for domain, name in known.items():
        if hostname == domain or hostname.endswith("." + domain):
            return name
    return clean_text(site_name or brand or hostname.removeprefix("www.").split(".")[0].title())


def extract_product(raw_url):
    if not is_public_url(raw_url):
        raise ValueError("Use um endereço público iniciado por http:// ou https://.")

    request = Request(raw_url, headers={"User-Agent": USER_AGENT, "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.7"})
    with urlopen(request, timeout=15) as response:
        final_url = response.geturl()
        if not is_public_url(final_url):
            raise ValueError("O redirecionamento da página não é permitido.")
        content_type = response.headers.get("Content-Type", "")
        if "text/html" not in content_type:
            raise ValueError("O endereço informado não é uma página HTML.")
        raw = response.read(MAX_PAGE_SIZE + 1)
        if len(raw) > MAX_PAGE_SIZE:
            raise ValueError("A página é grande demais para importar.")
        charset = response.headers.get_content_charset() or "utf-8"
        markup = raw.decode(charset, errors="replace")

    hostname = urlparse(final_url).hostname or ""
    if hostname == "shopee.com.br" or hostname.endswith(".shopee.com.br"):
        ids = re.search(r"-i\.(\d+)\.(\d+)", final_url) or re.search(r"/product/(\d+)/(\d+)", final_url)
        if ids:
            shop_id, item_id = ids.groups()
            social_url = f"https://shopee.com.br/product/{shop_id}/{item_id}"
            social_request = Request(
                social_url,
                headers={"User-Agent": "facebookexternalhit/1.1", "Accept-Language": "pt-BR,pt;q=0.9"},
            )
            try:
                with urlopen(social_request, timeout=15) as social_response:
                    social_raw = social_response.read(MAX_PAGE_SIZE + 1)
                    if len(social_raw) <= MAX_PAGE_SIZE:
                        social_charset = social_response.headers.get_content_charset() or "utf-8"
                        markup = social_raw.decode(social_charset, errors="replace")
            except (HTTPError, URLError, TimeoutError, socket.timeout):
                pass

    product = json_ld_product(markup)
    offer = first_offer(product)
    name = clean_text(product.get("name")) or meta_value(markup, "og:title", "twitter:title")
    description = clean_text(product.get("description")) or meta_value(markup, "og:description", "description")
    image = image_from(product) or meta_value(markup, "og:image", "twitter:image")
    price = to_number(offer.get("price") or offer.get("lowPrice")) or to_number(meta_value(markup, "product:price:amount", "og:price:amount"))
    old_price = to_number(offer.get("highPrice") or offer.get("listPrice")) or to_number(meta_value(markup, "product:original_price:amount"))
    if hostname == "shopee.com.br" or hostname.endswith(".shopee.com.br"):
        name = re.sub(r"\s*\|\s*Shopee Brasil\s*$", "", name, flags=re.I)
        description = re.sub(r"[*_`#]+", "", description).strip()

    if not name:
        title_match = re.search(r"<title[^>]*>(.*?)</title>", markup, re.I | re.S)
        name = clean_text(title_match.group(1)) if title_match else ""
    if not name:
        raise ValueError("Não foi possível identificar o produto nessa página.")

    original_hostname = urlparse(raw_url).hostname or ""
    preserved_url = raw_url if original_hostname == "s.shopee.com.br" else final_url
    return {
        "name": name[:90],
        "description": description[:220],
        "image": image,
        "price": price,
        "oldPrice": old_price,
        "store": store_from(product, markup, hostname),
        "url": preserved_url,
    }


class WiseOffHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, status, body, content_type="text/plain; charset=utf-8"):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(encoded)

    def do_HEAD(self):
        if unquote(urlparse(self.path).path) == "/index.html":
            self.send_response(301)
            self.send_header("Location", "/")
            self.end_headers()
            return
        return super().do_HEAD()

    def do_GET(self):
        path = unquote(urlparse(self.path).path)
        if path == "/index.html":
            self.send_response(301)
            self.send_header("Location", "/")
            self.end_headers()
            return
        if path == "/api/products":
            return self.send_json(200, [product_public(item) for item in load_products()])
        if path == "/robots.txt":
            return self.send_text(200, f"User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: {SITE_URL}/sitemap.xml\n")
        if path == "/sitemap.xml":
            products = load_products()
            urls = [f"  <url><loc>{SITE_URL}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>"]
            for product in products:
                item = product_public(product)
                modified = str(item.get("publishedAt") or "")[:10]
                lastmod = f"<lastmod>{page_escape(modified)}</lastmod>" if modified else ""
                urls.append(f"  <url><loc>{SITE_URL}{item['detailUrl']}</loc>{lastmod}<changefreq>daily</changefreq><priority>0.8</priority></url>")
            sitemap = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + "\n".join(urls) + "\n</urlset>\n"
            return self.send_text(200, sitemap, "application/xml; charset=utf-8")
        if path.startswith("/produto/"):
            requested_slug = path.removeprefix("/produto/").strip("/")
            product = next((item for item in load_products() if product_slug(item) == requested_slug), None)
            if not product:
                return self.send_error(404, "Oferta não encontrada")
            return self.send_text(200, product_page(product), "text/html; charset=utf-8")
        return super().do_GET()

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 10_000:
                raise ValueError("Requisição inválida.")
            payload = json.loads(self.rfile.read(length))
            if self.path == "/api/import-product":
                product = extract_product(str(payload.get("url", "")).strip())
                return self.send_json(200, product)
            if self.path == "/api/products":
                required = ("name", "description", "image", "price", "oldPrice", "category", "store", "url")
                if any(not payload.get(field) for field in required):
                    raise ValueError("Preencha todos os campos obrigatórios.")
                products = load_products()
                product_id = int(payload.get("id") or int(datetime.now(timezone.utc).timestamp() * 1000))
                payload["id"] = product_id
                payload["publishedAt"] = payload.get("publishedAt") or datetime.now(timezone.utc).isoformat()
                existing = next((index for index, item in enumerate(products) if int(item.get("id", 0)) == product_id), None)
                if existing is None:
                    products.insert(0, payload)
                else:
                    products[existing] = payload
                save_products(products)
                return self.send_json(200, product_public(payload))
            if self.path == "/api/products/delete":
                product_id = int(payload.get("id", 0))
                products = [item for item in load_products() if int(item.get("id", 0)) != product_id]
                save_products(products)
                return self.send_json(200, {"ok": True})
            if self.path == "/api/feature":
                product_id = int(payload.get("id", 0))
                products = load_products()
                if not any(int(item.get("id", 0)) == product_id for item in products):
                    raise ValueError("Produto não encontrado.")
                for item in products:
                    item["featured"] = int(item.get("id", 0)) == product_id
                save_products(products)
                return self.send_json(200, {"ok": True})
            return self.send_json(404, {"error": "Rota não encontrada."})
        except ValueError as error:
            self.send_json(400, {"error": str(error)})
        except HTTPError as error:
            self.send_json(422, {"error": f"A loja recusou a consulta (HTTP {error.code}). Preencha os campos manualmente."})
        except (URLError, TimeoutError, socket.timeout):
            self.send_json(422, {"error": "Não foi possível acessar a página. Confira o link ou preencha manualmente."})
        except Exception as error:
            print(f"Erro ao importar: {error}", file=sys.stderr)
            self.send_json(500, {"error": "Não foi possível importar essa oferta."})


if __name__ == "__main__":
    host = "127.0.0.1"
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    server = ThreadingHTTPServer((host, port), WiseOffHandler)
    print(f"WiseOff disponível em http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor encerrado.")
    finally:
        server.server_close()
