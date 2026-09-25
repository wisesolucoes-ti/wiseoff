(() => {
  function productData(button) {
    const container = button.closest("article") || document;
    const name = button.dataset.shareName || container.querySelector("h1, h3")?.textContent?.trim() || "Oferta WiseOff";
    const path = button.dataset.shareUrl || window.location.pathname;
    return {
      name,
      url: new URL(path, window.location.origin).href,
      text: `${name} em oferta na WiseOff`
    };
  }

  function notify(message) {
    let notice = document.querySelector("#shareNotice");
    if (!notice) {
      notice = document.createElement("div");
      notice.id = "shareNotice";
      notice.className = "share-notice";
      notice.setAttribute("role", "status");
      document.body.appendChild(notice);
    }
    notice.textContent = message;
    notice.classList.add("show");
    window.clearTimeout(notice.hideTimer);
    notice.hideTimer = window.setTimeout(() => notice.classList.remove("show"), 3500);
  }

  async function copyLink(url) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(url);
      return;
    }
    const input = document.createElement("textarea");
    input.value = url;
    input.style.position = "fixed";
    input.style.opacity = "0";
    document.body.appendChild(input);
    input.select();
    document.execCommand("copy");
    input.remove();
  }

  document.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-share]");
    if (!button) return;
    event.preventDefault();

    const product = productData(button);
    if (button.dataset.share === "whatsapp") {
      const message = encodeURIComponent(`${product.text}\n${product.url}`);
      window.open(`https://wa.me/?text=${message}`, "_blank", "noopener,noreferrer");
      return;
    }

    if (button.dataset.share === "instagram") {
      if (navigator.share) {
        try {
          await navigator.share({ title: product.name, text: product.text, url: product.url });
          return;
        } catch (error) {
          if (error?.name === "AbortError") return;
        }
      }
      try {
        await copyLink(product.url);
        notify("Link copiado. Cole no Instagram para compartilhar.");
      } catch {
        notify(`Copie este link: ${product.url}`);
      }
    }
  });
})();
