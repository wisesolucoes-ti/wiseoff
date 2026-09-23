#!/usr/bin/env python3
"""Gera em public/ a versão estática pronta para o GitHub Pages."""

from __future__ import annotations

import html
import json
import shutil
from pathlib import Path

from server import SITE_URL, load_products, product_page, product_public

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "public"
STATIC_FILES = ("styles.css", "app.js", "products.js", "favicon.svg", "site.webmanifest")


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main():
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    OUTPUT.mkdir()

    products = load_products()
    public_products = [product_public(product) for product in products]

    index = (ROOT / "index.html").read_text(encoding="utf-8")
    index = index.replace('          <a href="admin.html">Cadastrar</a>\n', "")
    write(OUTPUT / "index.html", index)

    for filename in STATIC_FILES:
        shutil.copy2(ROOT / filename, OUTPUT / filename)

    base_image = ROOT / "Imagens_Base" / "BaseLayout.png"
    if base_image.exists():
        target = OUTPUT / "Imagens_Base" / "BaseLayout.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(base_image, target)

    write(OUTPUT / "data" / "products.json", json.dumps(public_products, ensure_ascii=False, indent=2))

    sitemap_urls = [f"  <url><loc>{SITE_URL}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>"]
    for product in products:
        item = product_public(product)
        write(OUTPUT / "produto" / item["slug"] / "index.html", product_page(product))
        modified = str(product.get("publishedAt") or "")[:10]
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
