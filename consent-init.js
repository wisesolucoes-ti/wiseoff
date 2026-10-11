(() => {
  const consentKey = "wiseoff-consent-v2";
  const defaultConsent = { analytics: "denied", ads: "denied", decided: false };
  let consent = { ...defaultConsent };

  try {
    const saved = JSON.parse(localStorage.getItem(consentKey) || "null");
    if (saved && ["granted", "denied"].includes(saved.analytics) && ["granted", "denied"].includes(saved.ads)) {
      consent = { analytics: saved.analytics, ads: saved.ads, decided: true };
    } else {
      const legacy = localStorage.getItem("wiseoff-analytics-consent");
      if (["granted", "denied"].includes(legacy)) consent.analytics = legacy;
    }
  } catch { /* armazenamento indisponível */ }

  window.wiseoffConsent = consent;
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function gtag() { window.dataLayer.push(arguments); };
  window.gtag("consent", "default", {
    analytics_storage: consent.analytics,
    ad_storage: consent.ads,
    ad_user_data: consent.ads,
    ad_personalization: consent.ads,
    wait_for_update: 500
  });
})();
