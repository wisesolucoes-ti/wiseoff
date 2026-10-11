(() => {
  const measurementId = "G-TVE4FBLPDQ";
  const consentKey = "wiseoff-consent-v2";

  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function gtag() { window.dataLayer.push(arguments); };

  let consent = window.wiseoffConsent || { analytics: "denied", ads: "denied", decided: false };
  let analyticsAllowed = consent.analytics === "granted";
  let googleTagLoaded = false;

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

  function saveConsent(choice) {
    const choices = {
      necessary: { analytics: "denied", ads: "denied" },
      analytics: { analytics: "granted", ads: "denied" },
      all: { analytics: "granted", ads: "granted" }
    };
    consent = { ...(choices[choice] || choices.necessary), decided: true };
    window.wiseoffConsent = consent;
    analyticsAllowed = consent.analytics === "granted";
    window.gtag("consent", "update", {
      analytics_storage: consent.analytics,
      ad_storage: consent.ads,
      ad_user_data: consent.ads,
      ad_personalization: consent.ads
    });
    try {
      localStorage.setItem(consentKey, JSON.stringify(consent));
      localStorage.removeItem("wiseoff-analytics-consent");
    } catch { /* armazenamento indisponível */ }
    document.querySelector("#analyticsConsent")?.remove();
    loadGoogleTag();
  }

  function showConsent() {
    if (consent.decided) return;
    const banner = document.createElement("aside");
    banner.id = "analyticsConsent";
    banner.className = "consent-banner";
    banner.setAttribute("aria-label", "Preferências de privacidade");
    banner.innerHTML = `<p><strong>Privacidade na WiseOff</strong><span>Usamos métricas e publicidade para manter e melhorar o site. Você pode escolher o que autoriza. <a href="/privacidade.html">Saiba mais</a>.</span></p><div><button type="button" data-consent="necessary">Somente necessários</button><button type="button" data-consent="analytics">Só métricas</button><button class="consent-accept" type="button" data-consent="all">Aceitar tudo</button></div>`;
    banner.addEventListener("click", (event) => {
      const button = event.target.closest("[data-consent]");
      if (button) saveConsent(button.dataset.consent);
    });
    document.body.appendChild(banner);
  }

  loadGoogleTag();

  document.addEventListener("DOMContentLoaded", () => {
    showConsent();
    document.querySelector("#resetConsent")?.addEventListener("click", () => {
      analyticsAllowed = false;
      window.gtag("consent", "update", {
        analytics_storage: "denied",
        ad_storage: "denied",
        ad_user_data: "denied",
        ad_personalization: "denied"
      });
      try {
        localStorage.removeItem(consentKey);
        localStorage.removeItem("wiseoff-analytics-consent");
      } catch { /* armazenamento indisponível */ }
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
