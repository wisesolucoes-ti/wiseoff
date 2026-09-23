const STORAGE_KEY = "wiseoff-products";
const form = document.querySelector("#productForm");
const money = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const fields = ["name", "description", "price", "oldPrice", "category", "store", "url", "image", "badge", "installment"];

function keepOnlyLatestProductOnce() {
  const migrationKey = "wiseoff-keep-latest-v1";
  if (localStorage.getItem(migrationKey)) return;
  const products = loadProducts();
  const latest = products
    .slice()
    .sort((a, b) => new Date(b.publishedAt || 0) - new Date(a.publishedAt || 0))[0];
  saveProducts(latest ? [latest] : []);
  if (latest) localStorage.setItem("wiseoff-featured-product", String(latest.id));
  localStorage.setItem(migrationKey, "done");
}

function formatInputNumber(value) {
  if (value === null || value === undefined || value === "") return "";
  return Number(value).toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function loadProducts() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]"); }
  catch { return []; }
}

function saveProducts(products) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(products));
}

function numberFromInput(value) {
  const normalized = String(value).trim().replace(/\s/g, "").replace(/\.(?=\d{3}(?:\D|$))/g, "").replace(",", ".");
  return Number(normalized) || 0;
}

function storeClass(name) {
  return name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function showToast(message) {
  const toast = document.querySelector("#toast");
  toast.textContent = message;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3000);
}

function updatePreview() {
  const value = (id, fallback) => document.querySelector(`#${id}`).value.trim() || fallback;
  const price = numberFromInput(document.querySelector("#price").value);
  const oldPrice = numberFromInput(document.querySelector("#oldPrice").value);
  const discount = oldPrice > price && price > 0 ? Math.round((1 - price / oldPrice) * 100) : 0;
  const image = document.querySelector("#image").value.trim();

  document.querySelector("#previewName").textContent = value("name", "Nome do produto");
  document.querySelector("#previewDescription").textContent = value("description", "A descrição da oferta aparecerá neste espaço.");
  document.querySelector("#previewCategory").textContent = value("category", "Categoria");
  document.querySelector("#previewStore").textContent = value("store", "Nome da loja");
  document.querySelector("#previewPrice").textContent = money.format(price);
  document.querySelector("#previewOldPrice").textContent = money.format(oldPrice);
  document.querySelector("#previewDiscount").textContent = `-${discount}%`;
  document.querySelector("#descriptionCount").textContent = document.querySelector("#description").value.length;

  const previewImage = document.querySelector("#previewImage");
  const placeholder = document.querySelector("#imagePlaceholder");
  if (image) {
    previewImage.src = image;
    previewImage.hidden = false;
    placeholder.hidden = true;
  } else {
    previewImage.removeAttribute("src");
    previewImage.hidden = true;
    placeholder.hidden = false;
  }
}

function resetForm() {
  form.reset();
  document.querySelector("#productId").value = "";
  document.querySelector("#formStep").textContent = "Nova oferta";
  document.querySelector("#formTitle").textContent = "Informações do produto";
  document.querySelector("#submitLabel").textContent = "Cadastrar oferta";
  document.querySelector("#cancelEdit").hidden = true;
  document.querySelector("#importUrl").value = "";
  document.querySelector("#importStatus").textContent = "";
  updatePreview();
}

async function importFromUrl() {
  const importUrl = document.querySelector("#importUrl");
  const button = document.querySelector("#importButton");
  const status = document.querySelector("#importStatus");
  const url = importUrl.value.trim();
  if (!url) {
    importUrl.focus();
    status.textContent = "Cole o link de uma página de produto.";
    status.className = "import-status error";
    return;
  }

  button.disabled = true;
  button.classList.add("loading");
  button.querySelector("span").textContent = "Buscando...";
  status.textContent = "Acessando a página da loja e procurando os dados do produto...";
  status.className = "import-status";

  try {
    const response = await fetch("/api/import-product", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url })
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "Não foi possível importar o produto.");

    const importedFields = ["name", "description", "image", "store", "url"];
    importedFields.forEach((field) => {
      if (result[field]) document.querySelector(`#${field}`).value = result[field];
    });
    if (result.price) document.querySelector("#price").value = formatInputNumber(result.price);
    if (result.oldPrice) document.querySelector("#oldPrice").value = formatInputNumber(result.oldPrice);
    document.querySelector("#badge").value ||= "Oferta importada e verificada";
    updatePreview();

    const missing = [];
    if (!result.price) missing.push("preço");
    if (!result.oldPrice) missing.push("preço anterior");
    if (!result.image) missing.push("imagem");
    status.textContent = missing.length
      ? `Dados encontrados. Revise o formulário e complete: ${missing.join(", ")}.`
      : "Produto encontrado! Revise os dados e clique em Cadastrar oferta.";
    status.className = `import-status ${missing.length ? "warning" : "success"}`;
    document.querySelector("#name").focus();
  } catch (error) {
    status.textContent = error.message;
    status.className = "import-status error";
  } finally {
    button.disabled = false;
    button.classList.remove("loading");
    button.querySelector("span").textContent = "Buscar dados";
  }
}

function editProduct(id) {
  const product = loadProducts().find((item) => item.id === id);
  if (!product) return;
  document.querySelector("#productId").value = product.id;
  fields.forEach((field) => {
    document.querySelector(`#${field}`).value = product[field] ?? "";
  });
  document.querySelector("#formStep").textContent = "Editando oferta";
  document.querySelector("#formTitle").textContent = product.name;
  document.querySelector("#submitLabel").textContent = "Salvar alterações";
  document.querySelector("#cancelEdit").hidden = false;
  updatePreview();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function deleteProduct(id) {
  const product = loadProducts().find((item) => item.id === id);
  if (!product || !confirm(`Excluir a oferta “${product.name}”?`)) return;
  try {
    const response = await fetch("/api/products/delete", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id }) });
    if (!response.ok) throw new Error();
  } catch { return showToast("Não foi possível excluir no servidor."); }
  saveProducts(loadProducts().filter((item) => item.id !== id));
  if (localStorage.getItem("wiseoff-featured-product") === String(id)) {
    localStorage.removeItem("wiseoff-featured-product");
  }
  if (document.querySelector("#productId").value === String(id)) resetForm();
  renderProducts();
  showToast("Oferta excluída.");
}

async function featureProduct(id) {
  const product = loadProducts().find((item) => item.id === id);
  if (!product) return;
  try {
    const response = await fetch("/api/feature", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id }) });
    if (!response.ok) throw new Error();
  } catch { return showToast("Não foi possível atualizar o destaque."); }
  localStorage.setItem("wiseoff-featured-product", String(id));
  const updated = loadProducts().map((item) => ({ ...item, featured: item.id === id }));
  saveProducts(updated);
  renderProducts();
  showToast(`“${product.name}” agora é a oferta da semana!`);
}

function renderProducts() {
  const products = loadProducts();
  const featuredId = Number(localStorage.getItem("wiseoff-featured-product"));
  const list = document.querySelector("#adminProductsList");
  document.querySelector("#adminProductCount").textContent = products.length;
  document.querySelector("#adminEmpty").hidden = products.length > 0;
  list.innerHTML = products.map((product) => `
    <article class="admin-product-row">
      <img src="${product.image}" alt="${product.name}" />
      <div><span>${product.category} · ${product.store}</span><h3>${product.name}</h3><strong>${money.format(product.price)}</strong></div>
      <div class="row-actions">
        <button class="feature ${product.id === featuredId ? "active" : ""}" type="button" data-feature="${product.id}">${product.id === featuredId ? "★ Oferta da semana" : "☆ Destacar"}</button>
        <button type="button" data-edit="${product.id}">Editar</button>
        <button class="danger" type="button" data-delete="${product.id}">Excluir</button>
      </div>
    </article>`).join("");
}

form.addEventListener("input", updatePreview);
form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const price = numberFromInput(document.querySelector("#price").value);
  const oldPrice = numberFromInput(document.querySelector("#oldPrice").value);
  if (price <= 0 || oldPrice <= 0) return showToast("Informe preços válidos.");
  if (oldPrice <= price) return showToast("O preço anterior precisa ser maior que a oferta.");

  const existingId = Number(document.querySelector("#productId").value);
  const product = {
    id: existingId || Date.now(),
    name: document.querySelector("#name").value.trim(),
    description: document.querySelector("#description").value.trim(),
    image: document.querySelector("#image").value.trim(),
    price,
    oldPrice,
    category: document.querySelector("#category").value.trim(),
    store: document.querySelector("#store").value.trim(),
    storeClass: storeClass(document.querySelector("#store").value),
    url: document.querySelector("#url").value.trim(),
    badge: document.querySelector("#badge").value.trim() || "Oferta verificada",
    installment: document.querySelector("#installment").value.trim() || "Consulte as condições na loja",
    publishedAt: existingId ? (loadProducts().find((item) => item.id === existingId)?.publishedAt || new Date().toISOString()) : new Date().toISOString()
  };

  try {
    const response = await fetch("/api/products", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(product) });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "Não foi possível salvar.");
    Object.assign(product, result);
  } catch (error) {
    return showToast(error.message || "Não foi possível salvar no servidor.");
  }

  const products = loadProducts();
  const index = products.findIndex((item) => item.id === product.id);
  if (index >= 0) products[index] = product;
  else products.unshift(product);
  saveProducts(products);
  renderProducts();
  resetForm();
  showToast(index >= 0 ? "Oferta atualizada com sucesso!" : "Oferta cadastrada com sucesso!");
});

document.querySelector("#adminProductsList").addEventListener("click", (event) => {
  const edit = event.target.closest("[data-edit]");
  const remove = event.target.closest("[data-delete]");
  const feature = event.target.closest("[data-feature]");
  if (edit) editProduct(Number(edit.dataset.edit));
  if (remove) deleteProduct(Number(remove.dataset.delete));
  if (feature) featureProduct(Number(feature.dataset.feature));
});

document.querySelector("#resetForm").addEventListener("click", resetForm);
document.querySelector("#cancelEdit").addEventListener("click", resetForm);
document.querySelector("#importButton").addEventListener("click", importFromUrl);
document.querySelector("#importUrl").addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    importFromUrl();
  }
});
document.querySelector("#previewImage").addEventListener("error", () => {
  document.querySelector("#previewImage").hidden = true;
  document.querySelector("#imagePlaceholder").hidden = false;
});

keepOnlyLatestProductOnce();
updatePreview();

async function syncWithServer() {
  try {
    let response = await fetch("/api/products");
    let serverProducts = await response.json();
    const localProducts = loadProducts();
    if (!serverProducts.length && localProducts.length) {
      response = await fetch("/api/products", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(localProducts[0]) });
      if (response.ok) serverProducts = [await response.json()];
    }
    saveProducts(serverProducts);
    const featured = serverProducts.find((item) => item.featured) || serverProducts[0];
    if (featured) localStorage.setItem("wiseoff-featured-product", String(featured.id));
  } catch {
    showToast("Servidor indisponível. Os dados locais foram mantidos.");
  }
  renderProducts();
}

syncWithServer();
