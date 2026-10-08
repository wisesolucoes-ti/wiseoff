#!/usr/bin/env python3
"""Cliente mínimo e seguro para a Amazon Creators API (Brasil)."""

from __future__ import annotations

import csv
import html
import json
import os
import re
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
CREDENTIALS_FILE = ROOT / "credentials" / "wiseoff-credentials.csv"
TOKEN_ENDPOINTS = {
    "3.1": "https://api.amazon.com/auth/o2/token",
    "3.2": "https://api.amazon.co.uk/auth/o2/token",
    "3.3": "https://api.amazon.co.jp/auth/o2/token",
}
API_ENDPOINT = "https://creatorsapi.amazon/catalog/v1/getItems"
MARKETPLACE = "www.amazon.com.br"
DEFAULT_PARTNER_TAG = "wiseimport-20"
MAX_PAGE_SIZE = 2 * 1024 * 1024
USER_AGENT = "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36"
RESOURCES = [
    "images.primary.large",
    "itemInfo.title",
    "itemInfo.features",
    "itemInfo.byLineInfo",
    "itemInfo.classifications",
    "offersV2.listings.price",
    "offersV2.listings.availability",
    "offersV2.listings.dealDetails",
    "offersV2.listings.merchantInfo",
]

_TOKEN_LOCK = threading.Lock()
_TOKEN_CACHE = {"access_token": "", "expires_at": 0.0}


class AmazonAPIError(Exception):
    """Erro seguro para exibição, sem credenciais ou token."""


def _first(mapping, *keys):
    current = mapping
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def _clean(value):
    return re.sub(r"\s+", " ", html.unescape(str(value or ""))).strip()


def _truncate(value, limit):
    value = _clean(value)
    if len(value) <= limit:
        return value
    shortened = value[: limit - 1].rsplit(" ", 1)[0].rstrip(".,;:-")
    return (shortened or value[: limit - 1]) + "…"


def is_amazon_url(raw_url):
    hostname = (urlparse(raw_url).hostname or "").lower()
    return hostname in {"link.amazon", "amzn.to"} or hostname.endswith(".amazon.com.br") or hostname == "amazon.com.br"


def load_credentials():
    """Lê primeiro o ambiente e, localmente, o CSV ignorado pelo Git."""
    client_id = os.getenv("AMAZON_CREATORS_CLIENT_ID", "").strip()
    client_secret = os.getenv("AMAZON_CREATORS_CLIENT_SECRET", "").strip()
    version = os.getenv("AMAZON_CREATORS_VERSION", "").strip()

    if not (client_id and client_secret):
        try:
            with CREDENTIALS_FILE.open(newline="", encoding="utf-8-sig") as handle:
                row = next(csv.DictReader(handle), None) or {}
        except (FileNotFoundError, OSError, csv.Error):
            row = {}
        client_id = str(row.get("Credential Id") or "").strip()
        client_secret = str(row.get("Secret") or "").strip()
        version = str(row.get("Version") or version or "").strip()

    if not client_id or not client_secret:
        raise AmazonAPIError("as credenciais da Creators API não foram configuradas")
    version = version or "3.1"
    endpoint = TOKEN_ENDPOINTS.get(version)
    if not endpoint:
        raise AmazonAPIError(f"a versão de credencial {version} não é reconhecida")
    return {
        "client_id": client_id,
        "client_secret": client_secret,
        "version": version,
        "token_endpoint": endpoint,
        "partner_tag": os.getenv("AMAZON_PARTNER_TAG", DEFAULT_PARTNER_TAG).strip() or DEFAULT_PARTNER_TAG,
    }


def credentials_status():
    """Retorna apenas metadados não sensíveis para diagnóstico."""
    try:
        values = load_credentials()
        return {
            "configured": True,
            "version": values["version"],
            "marketplace": MARKETPLACE,
            "partnerTag": values["partner_tag"],
        }
    except AmazonAPIError as error:
        return {"configured": False, "error": str(error)}


def _error_message(error, default):
    try:
        raw = error.read(64 * 1024).decode("utf-8", errors="replace")
        payload = json.loads(raw)
        detail = payload.get("error_description") or payload.get("message") or payload.get("error")
        if isinstance(detail, dict):
            detail = detail.get("message") or detail.get("code")
        if detail:
            if "eligibility requirements" in str(detail).lower():
                return "a conta de Associados ainda não atende aos requisitos de elegibilidade da Amazon"
            return _truncate(detail, 180)
    except (AttributeError, UnicodeDecodeError, json.JSONDecodeError):
        pass
    return default


def _post_json(url, payload, headers=None, timeout=20):
    request = Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json", **(headers or {})},
        method="POST",
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        message = _error_message(error, f"a Amazon recusou a consulta (HTTP {error.code})")
        raise AmazonAPIError(message) from None
    except (URLError, TimeoutError):
        raise AmazonAPIError("não foi possível conectar à Amazon") from None
    except json.JSONDecodeError:
        raise AmazonAPIError("a Amazon devolveu uma resposta inválida") from None


def get_access_token():
    now = time.time()
    with _TOKEN_LOCK:
        if _TOKEN_CACHE["access_token"] and now < _TOKEN_CACHE["expires_at"]:
            return _TOKEN_CACHE["access_token"]

        credentials = load_credentials()
        response = _post_json(
            credentials["token_endpoint"],
            {
                "grant_type": "client_credentials",
                "client_id": credentials["client_id"],
                "client_secret": credentials["client_secret"],
                "scope": "creatorsapi::default",
            },
        )
        token = str(response.get("access_token") or "")
        if not token:
            raise AmazonAPIError("a autenticação não retornou um token de acesso")
        expires_in = max(int(response.get("expires_in") or 3600), 120)
        _TOKEN_CACHE.update(access_token=token, expires_at=now + expires_in - 60)
        return token


def _asin_from_text(value):
    patterns = (
        r"/(?:dp|gp/product|gp/aw/d)/([A-Z0-9]{10})(?:[/?]|$)",
        r"[?&]asin=([A-Z0-9]{10})(?:[&#]|$)",
    )
    for pattern in patterns:
        match = re.search(pattern, value, re.I)
        if match:
            return match.group(1).upper()
    return ""


def resolve_asin(raw_url):
    if not is_amazon_url(raw_url):
        raise AmazonAPIError("o link informado não pertence à Amazon Brasil")
    asin = _asin_from_text(raw_url)
    if asin:
        return asin

    hostname = (urlparse(raw_url).hostname or "").lower()
    user_agent = "facebookexternalhit/1.1" if hostname == "link.amazon" else USER_AGENT
    request = Request(raw_url, headers={"User-Agent": user_agent, "Accept-Language": "pt-BR,pt;q=0.9"})
    try:
        with urlopen(request, timeout=15) as response:
            final_url = response.geturl()
            asin = _asin_from_text(final_url)
            if asin:
                return asin
            markup = response.read(MAX_PAGE_SIZE + 1).decode(response.headers.get_content_charset() or "utf-8", errors="replace")
    except HTTPError as error:
        raise AmazonAPIError(f"não foi possível abrir o link curto da Amazon (HTTP {error.code})") from None
    except (URLError, TimeoutError):
        raise AmazonAPIError("não foi possível abrir o link curto da Amazon") from None

    decoded = html.unescape(markup)
    match = re.search(r"[?&]btn_url=([^&\"'<>\s]+)", decoded, re.I)
    destination = unquote(match.group(1)) if match else decoded
    asin = _asin_from_text(destination)
    if not asin:
        raise AmazonAPIError("não foi possível identificar o ASIN nesse link")
    return asin


def _map_product(item):
    title = _first(item, "itemInfo", "title", "displayValue")
    features = _first(item, "itemInfo", "features", "displayValues") or []
    image = _first(item, "images", "primary", "large", "url")
    listings = _first(item, "offersV2", "listings") or []
    listing = listings[0] if isinstance(listings, list) and listings else {}
    price = _first(listing, "price", "money", "amount")
    old_price = _first(listing, "price", "savingBasis", "money", "amount")
    discount = _first(listing, "price", "savings", "percentage")
    badge = _first(listing, "dealDetails", "badge")
    availability = _first(listing, "availability", "type")

    try:
        price = float(price) if price is not None else None
        old_price = float(old_price) if old_price is not None else None
    except (TypeError, ValueError):
        price, old_price = None, None
    if old_price is not None and (price is None or old_price <= price):
        old_price = None

    if not title:
        raise AmazonAPIError("o produto foi localizado, mas não retornou um título")
    description = " · ".join(_clean(value) for value in features[:3] if _clean(value))
    if not description:
        description = f"Confira os detalhes de {_clean(title)} na Amazon."
    if not badge and discount:
        badge = f"{round(float(discount))}% de desconto"

    return {
        "name": _truncate(title, 90),
        "description": _truncate(description, 220),
        "image": image or "",
        "price": price,
        "oldPrice": old_price,
        "store": "Amazon",
        "url": item.get("detailPageURL") or f"https://www.amazon.com.br/dp/{item.get('asin', '')}",
        "asin": item.get("asin") or "",
        "amazonUpdatedAt": datetime.now(timezone.utc).isoformat(),
        "importSource": "Amazon Creators API",
        "availability": availability or "",
        "badge": _clean(badge),
    }


def get_product(raw_url):
    asin = resolve_asin(raw_url)
    credentials = load_credentials()
    response = _post_json(
        API_ENDPOINT,
        {
            "itemIds": [asin],
            "itemIdType": "ASIN",
            "marketplace": MARKETPLACE,
            "partnerTag": credentials["partner_tag"],
            "resources": RESOURCES,
        },
        headers={"Authorization": f"Bearer {get_access_token()}", "x-marketplace": MARKETPLACE},
    )
    items = _first(response, "itemsResult", "items") or _first(response, "itemResults", "items") or []
    item = next((candidate for candidate in items if candidate.get("asin") == asin), None)
    if not item:
        errors = response.get("errors") or []
        message = errors[0].get("message") if errors and isinstance(errors[0], dict) else ""
        raise AmazonAPIError(_truncate(message, 180) or "a Amazon não retornou dados para este ASIN")
    return _map_product(item)
