const state = {
  category: "Todos",
  query: "",
  sort: "featured",
  favoritesOnly: false,
  favorites: new Set(JSON.parse(localStorage.getItem("wiseoff-favorites") || "[]"))
};

const $ = (selector) => document.querySelector(selector);
const productList = $("#productList");
const categoryList = $("#categoryList");
const money = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });

function keepOnlyLatestProductOnce() {
  const migrationKey = "wiseoff-keep-latest-v1";
  if (localStorage.getItem(migrationKey)) return;
  try {
    const products = JSON.parse(localStorage.getItem("wiseoff-products") || "[]");
    const latest = products
      .slice()
      .sort((a, b) => new Date(b.publishedAt || 0) - new Date(a.publishedAt || 0))[0];
    localStorage.setItem("wiseoff-products", JSON.stringify(latest ? [latest] : []));
    if (latest) localStorage.setItem("wiseoff-featured-product", String(latest.id));
    localStorage.setItem(migrationKey, "done");
  } catch {
    localStorage.setItem(migrationKey, "done");
  }
}

function getProducts() {
  try {
    const customProducts = JSON.parse(localStorage.getItem("wiseoff-products") || "[]");
    return [...customProducts, ...PRODUCTS];
  } catch {
    return PRODUCTS;
  }
}

async function syncProductsFromServer() {
  try {
    const isLocal = ["127.0.0.1", "localhost"].includes(location.hostname);
    let response = await fetch(isLocal ? "/api/products" : "data/products.json", { headers: { Accept: "application/json" } });
    if (!response.ok) return;
    let products = await response.json();
    const localProducts = getProducts();
    if (isLocal && !products.length && localProducts.length) {
      response = await fetch("/api/products", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(localProducts[0])
      });
      if (response.ok) products = [await response.json()];
    }
    localStorage.setItem("wiseoff-products", JSON.stringify(products));
    const featured = products.find((item) => item.featured) || products[0];
    if (featured) localStorage.setItem("wiseoff-featured-product", String(featured.id));
    renderFeaturedProduct();
    renderCategories();
    renderProducts();
    renderProductSchema(products);
  } catch {
    // Mantém a versão salva no navegador quando o servidor estiver indisponível.
  }
}

function renderProductSchema(products) {
  document.querySelector("#productsSchema")?.remove();
  if (!products.length) return;
  const script = document.createElement("script");
  script.id = "productsSchema";
  script.type = "application/ld+json";
  script.textContent = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Ofertas em destaque",
    itemListElement: products.map((product, index) => ({
      "@type": "ListItem",
      position: index + 1,
      url: `https://wiseoff.com.br${product.detailUrl}`,
      name: product.name
    }))
  });
  document.head.appendChild(script);
}

function renderFeaturedProduct() {
  const products = getProducts();
  if (!products.length) return;
  const featuredId = Number(localStorage.getItem("wiseoff-featured-product"));
  const product = products.find((item) => item.id === featuredId) || products[0];
  const image = document.querySelector("#featuredImage");
  image.src = product.image;
  image.alt = product.name;
  document.querySelector("#featuredName").textContent = product.name;
  document.querySelector("#featuredPrice").textContent = money.format(product.price);
  document.querySelector("#featuredInstallment").textContent = product.installment || "Consulte as condições";
  const link = document.querySelector("#featuredLink");
  link.href = product.url;
  link.target = "_blank";
  link.rel = "noopener sponsored";
  link.firstChild.textContent = "Ver oferta ";
}

function discountOf(product) {
  return Math.round((1 - product.price / product.oldPrice) * 100);
}

function timeAgo(dateString) {
  const hours = Math.max(1, Math.floor((Date.now() - new Date(dateString)) / 36e5));
  if (hours < 24) return `há ${hours} hora${hours > 1 ? "s" : ""}`;
  const days = Math.floor(hours / 24);
  return `há ${days} dia${days > 1 ? "s" : ""}`;
}

function productCard(product) {
  const favorite = state.favorites.has(product.id);
  const detailUrl = product.detailUrl || "#ofertas";
  return `
    <article class="product-card">
      <div class="product-media">
        <a href="${detailUrl}" aria-label="Ver detalhes de ${product.name}"><img src="${product.image}" alt="${product.name}" loading="lazy" width="700" height="500" /></a>
        <span class="discount-badge">-${discountOf(product)}%</span>
        <button class="heart-button ${favorite ? "selected" : ""}" type="button" data-favorite="${product.id}" aria-label="${favorite ? "Remover dos" : "Adicionar aos"} favoritos">
          <svg><use href="#icon-heart" /></svg>
        </button>
      </div>
      <div class="product-info">
        <div class="product-topline">
          <span class="category-pill">${product.category}</span>
          <span class="product-time"><svg><use href="#icon-clock" /></svg>${timeAgo(product.publishedAt)}</span>
        </div>
        <h3><a href="${detailUrl}">${product.name}</a></h3>
        <p>${product.description}</p>
        <div class="editor-pick"><svg><use href="#icon-check" /></svg>${product.badge}</div>
      </div>
      <div class="product-buy">
        <span class="store store-${product.storeClass}">${product.store}</span>
        <div class="price-row"><strong>${money.format(product.price)}</strong><del>${money.format(product.oldPrice)}</del></div>
        <small>${product.installment}</small>
        <a class="button button-green" href="${product.url}" target="_blank" rel="noopener sponsored">Ver oferta <svg><use href="#icon-external" /></svg></a>
      </div>
    </article>`;
}

function visibleProducts() {
  let items = getProducts().filter((product) => {
    const haystack = `${product.name} ${product.description} ${product.category} ${product.store}`.toLowerCase();
    const categoryMatch = state.category === "Todos" || product.category === state.category;
    return categoryMatch && haystack.includes(state.query) && (!state.favoritesOnly || state.favorites.has(product.id));
  });

  return items.sort((a, b) => {
    if (state.sort === "discount") return discountOf(b) - discountOf(a);
    if (state.sort === "lowest") return a.price - b.price;
    if (state.sort === "recent") return new Date(b.publishedAt) - new Date(a.publishedAt);
    return a.id - b.id;
  });
}

function renderProducts() {
  const items = visibleProducts();
  productList.innerHTML = items.map(productCard).join("");
  $("#resultCount").textContent = items.length;
  $("#emptyState").hidden = items.length > 0;
  $("#favoriteCount").textContent = state.favorites.size;
  $("#favoriteFilter").classList.toggle("active", state.favoritesOnly);
}

function renderCategories() {
  const categories = ["Todos", ...new Set(getProducts().map((product) => product.category))];
  categoryList.innerHTML = categories.map((category) => `
    <button type="button" class="category-button ${category === state.category ? "active" : ""}" data-category="${category}">
      ${category === "Todos" ? '<svg><use href="#icon-tag" /></svg>' : ""}${category}
    </button>`).join("");
}

function resetFilters() {
  state.category = "Todos";
  state.query = "";
  state.favoritesOnly = false;
  $("#searchInput").value = "";
  renderCategories();
  renderProducts();
}

categoryList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-category]");
  if (!button) return;
  state.category = button.dataset.category;
  renderCategories();
  renderProducts();
});

productList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-favorite]");
  if (!button) return;
  const id = Number(button.dataset.favorite);
  state.favorites.has(id) ? state.favorites.delete(id) : state.favorites.add(id);
  localStorage.setItem("wiseoff-favorites", JSON.stringify([...state.favorites]));
  renderProducts();
});

$("#searchInput").addEventListener("input", (event) => {
  state.query = event.target.value.trim().toLowerCase();
  renderProducts();
});

$("#sortSelect").addEventListener("change", (event) => {
  state.sort = event.target.value;
  renderProducts();
});

$("#favoriteFilter").addEventListener("click", () => {
  state.favoritesOnly = !state.favoritesOnly;
  renderProducts();
  $("#ofertas").scrollIntoView({ behavior: "smooth" });
});

$("#clearFilters").addEventListener("click", resetFilters);

$("#newsletterForm").addEventListener("submit", (event) => {
  event.preventDefault();
  event.currentTarget.reset();
  const toast = $("#toast");
  toast.textContent = "Pronto! Você entrou para a lista de ofertas.";
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3500);
});

document.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    event.preventDefault();
    $("#searchInput").focus();
  }
});

keepOnlyLatestProductOnce();
renderFeaturedProduct();
const initialQuery = new URLSearchParams(location.search).get("q");
if (initialQuery) {
  state.query = initialQuery.trim().toLowerCase();
  document.querySelector("#searchInput").value = initialQuery;
}
renderCategories();
renderProducts();
renderProductSchema(getProducts());
syncProductsFromServer();
