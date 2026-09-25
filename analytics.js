(() => {
  const measurementId = "G-TVE4FBLPDQ";
  const consentKey = "wiseoff-analytics-consent";

  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function gtag() { window.dataLayer.push(arguments); };

  let savedConsent = "";
  let analyticsAllowed = false;
  let googleTagLoaded = false;
  try { savedConsent = localStorage.getItem(consentKey) || ""; } catch { /* armazenamento indisponível */ }
  analyticsAllowed = savedConsent === "granted";

  window.gtag("consent", "default", {
    analytics_storage: analyticsAllowed ? "granted" : "denied",
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
    wait_for_update: 500
  });

  function loadGoogleTag() {
    if (googleTagLoaded || !analyticsAllowed) return;
    googleTagLoaded = true;
    const googleTag = document.createElement("script");
    googleTag.async = true;
    googleTag.src = `https://www.googletagmanager.com/gtag/js?id=${measurementId}`;
    document.head.appendChild(googleTag);
    window.gtag("js", new Date());
    window.gtag("config", measurementId);
  }

  function saveConsent(value) {
    analyticsAllowed = value === "granted";
    window.gtag("consent", "update", { analytics_storage: value });
    try { localStorage.setItem(consentKey, value); } catch { /* armazenamento indisponível */ }
    document.querySelector("#analyticsConsent")?.remove();
    loadGoogleTag();
  }

  function showConsent() {
    if (savedConsent) return;
    const banner = document.createElement("aside");
    banner.id = "analyticsConsent";
    banner.className = "consent-banner";
    banner.setAttribute("aria-label", "Preferências de privacidade");
    banner.innerHTML = `<p><strong>Privacidade na WiseOff</strong><span>Usamos métricas para melhorar as ofertas e a navegação. <a href="/privacidade.html">Saiba mais</a>.</span></p><div><button type="button" data-consent="denied">Recusar</button><button class="consent-accept" type="button" data-consent="granted">Aceitar métricas</button></div>`;
    banner.addEventListener("click", (event) => {
      const button = event.target.closest("[data-consent]");
      if (button) saveConsent(button.dataset.consent);
    });
    document.body.appendChild(banner);
  }

  loadGoogleTag();

  document.addEventListener("DOMContentLoaded", () => {
    showConsent();
    document.querySelector("#resetAnalyticsConsent")?.addEventListener("click", () => {
      analyticsAllowed = false;
      window.gtag("consent", "update", { analytics_storage: "denied" });
      try { localStorage.removeItem(consentKey); } catch { /* armazenamento indisponível */ }
      window.location.reload();
    });
    document.addEventListener("click", (event) => {
      const link = event.target.closest("a[data-offer-link]");
      if (!link || !analyticsAllowed) return;
      const card = link.closest("article") || document;
      const title = card.querySelector("h1, h3")?.textContent?.trim() || "Oferta";
      window.gtag("event", "click_offer", {
        product_id: link.dataset.productId || "",
        product_name: title,
        store: link.dataset.store || "",
        link_url: link.href
      });
    });
  });
})();
