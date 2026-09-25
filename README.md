# WiseOff

Vitrine responsiva de ofertas inspirada no layout `Imagens_Base/BaseLayout.png`.

## Ambiente local

```bash
./iniciar.sh
```

Acesse:

- Site: `http://127.0.0.1:8000`
- Cadastro: `http://127.0.0.1:8000/admin.html`

O painel importa informações públicas dos links, cadastra, edita, exclui e destaca ofertas. Os produtos são armazenados em `data/products.json`.

## Publicação no GitHub Pages

A publicação é estática. O script abaixo gera em `public/` a página inicial, o catálogo JSON, páginas individuais de produtos, sitemap, robots.txt, dados estruturados e o arquivo de domínio:

```bash
python3 build_static.py
```

O workflow `.github/workflows/pages.yml` executa essa geração e publica automaticamente a cada envio para a branch `main`.

Depois da configuração inicial do repositório, o fluxo diário é:

1. Inicie `./iniciar.sh`.
2. Cadastre ou atualize ofertas em `/admin.html`.
3. Execute `bash publicar.sh`.
4. Acompanhe a publicação na aba **Actions** do GitHub.

O painel administrativo e o servidor Python não são publicados. Somente os arquivos estáticos gerados ficam acessíveis aos visitantes.

## Oferta da semana

Na lista **Ofertas adicionadas**, use **Destacar**. O campo `featured` do produto selecionado controla o banner principal.

## SEO

A geração estática inclui:

- URLs individuais em `/produto/nome-do-produto-id/`;
- canonical, Open Graph e Twitter Cards;
- dados estruturados `Product`, `Offer`, `BreadcrumbList`, `Organization`, `WebSite` e `ItemList`;
- `robots.txt` e `sitemap.xml`;
- títulos e descrições próprios para cada oferta.

Após conectar `wiseoff.com.br`, envie `https://wiseoff.com.br/sitemap.xml` ao Google Search Console e ao Bing Webmaster Tools.
