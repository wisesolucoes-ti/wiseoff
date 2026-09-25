(() => {
  let activeButton = null;
  let activeProduct = null;

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

  function menu() {
    let element = document.querySelector("#shareMenu");
    if (element) return element;
    element = document.createElement("div");
    element.id = "shareMenu";
    element.className = "share-menu";
    element.setAttribute("role", "menu");
    element.hidden = true;
    element.innerHTML = `
      <strong>Compartilhar oferta</strong>
      <button type="button" role="menuitem" data-share-option="facebook">Facebook</button>
      <button type="button" role="menuitem" data-share-option="twitter">X / Twitter</button>
      <button type="button" role="menuitem" data-share-option="instagram">Instagram</button>
      <button type="button" role="menuitem" data-share-option="whatsapp">WhatsApp</button>
      <button type="button" role="menuitem" data-share-option="copy">Copiar link</button>`;
    document.body.appendChild(element);
    return element;
  }

  function closeMenu() {
    const element = menu();
    element.hidden = true;
    activeButton?.setAttribute("aria-expanded", "false");
    activeButton = null;
    activeProduct = null;
  }

  function openMenu(button, product) {
    const element = menu();
    if (activeButton === button && !element.hidden) {
      closeMenu();
      return;
    }
    activeButton?.setAttribute("aria-expanded", "false");
    activeButton = button;
    activeProduct = product;
    button.setAttribute("aria-expanded", "true");
    element.hidden = false;

    const rect = button.getBoundingClientRect();
    const menuWidth = element.offsetWidth;
    const menuHeight = element.offsetHeight;
    const left = Math.min(Math.max(12, rect.right - menuWidth), window.innerWidth - menuWidth - 12);
    const below = rect.bottom + 8;
    const top = below + menuHeight <= window.innerHeight - 12 ? below : Math.max(12, rect.top - menuHeight - 8);
    element.style.left = `${left}px`;
    element.style.top = `${top}px`;
    element.querySelector("button")?.focus({ preventScroll: true });
  }

  async function nativeShare(button, product) {
    try {
      await navigator.share({ title: product.name, text: product.text, url: product.url });
    } catch (error) {
      if (error?.name !== "AbortError") openMenu(button, product);
    }
  }

  async function shareOnDesktop(option, product) {
    const encodedUrl = encodeURIComponent(product.url);
    const encodedText = encodeURIComponent(product.text);
    if (option === "facebook") window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodedUrl}`, "_blank", "noopener,noreferrer,width=680,height=560");
    if (option === "twitter") window.open(`https://twitter.com/intent/tweet?text=${encodedText}&url=${encodedUrl}`, "_blank", "noopener,noreferrer,width=680,height=560");
    if (option === "whatsapp") window.open(`https://wa.me/?text=${encodeURIComponent(`${product.text}\n${product.url}`)}`, "_blank", "noopener,noreferrer");
    if (option === "instagram") {
      window.open("https://www.instagram.com/", "_blank", "noopener,noreferrer");
      await copyLink(product.url);
      notify("Link copiado. Cole no Instagram para compartilhar.");
    }
    if (option === "copy") {
      await copyLink(product.url);
      notify("Link da oferta copiado.");
    }
  }

  document.addEventListener("click", async (event) => {
    const trigger = event.target.closest("[data-share-trigger]");
    if (trigger) {
      event.preventDefault();
      const product = productData(trigger);
      if (window.matchMedia("(max-width: 780px), (pointer: coarse)").matches && navigator.share) {
        await nativeShare(trigger, product);
      } else {
        openMenu(trigger, product);
      }
      return;
    }

    const option = event.target.closest("[data-share-option]");
    if (option && activeProduct) {
      const product = activeProduct;
      closeMenu();
      try {
        await shareOnDesktop(option.dataset.shareOption, product);
      } catch {
        notify("Não foi possível compartilhar. Tente copiar o link.");
      }
      return;
    }

    if (!event.target.closest("#shareMenu")) closeMenu();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      const button = activeButton;
      closeMenu();
      button?.focus();
    }
  });
  window.addEventListener("resize", closeMenu);
  window.addEventListener("scroll", closeMenu, { passive: true });
})();
