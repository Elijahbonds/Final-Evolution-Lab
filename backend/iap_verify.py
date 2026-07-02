"""
Apple In-App Purchase HTTP helpers.

- Legacy ``verifyReceipt`` against Apple using ``APPLE_SHARED_SECRET``.
- Product → internal SKU mapping is ``storekit_catalog`` (defaults + ``FEL_STOREKIT_CATALOG_JSON``).

Fulfillment is fail-closed in ``server.verify_iap_transaction`` until App Store Server API / verified JWS grants exist.
Optional ``FEL_APPLE_PRODUCT_MAP`` is still exposed via ``load_product_map()`` for tooling — not used for entitlements.
"""
from __future__ import annotations

import json
import os
from typing import Any, Dict, List

import httpx
from fastapi import HTTPException

PRODUCTION_VERIFY = "https://buy.itunes.apple.com/verifyReceipt"
SANDBOX_VERIFY = "https://sandbox.itunes.apple.com/verifyReceipt"


async def verify_legacy_receipt(receipt_b64: str, shared_secret: str) -> Dict[str, Any]:
    """Call Apple's verifyReceipt; retry sandbox when Apple returns 21007 (sandbox receipt on prod URL)."""
    payload = {
        "receipt-data": receipt_b64,
        "password": shared_secret,
        "exclude-old-transactions": True,
    }
    async with httpx.AsyncClient() as client:
        r = await client.post(PRODUCTION_VERIFY, json=payload, timeout=45.0)
    try:
        data = r.json()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Invalid Apple response: {exc}") from exc

    status = data.get("status")
    if status == 21007:
        async with httpx.AsyncClient() as client:
            r = await client.post(SANDBOX_VERIFY, json=payload, timeout=45.0)
        try:
            data = r.json()
        except Exception as exc:
            raise HTTPException(status_code=502, detail=f"Invalid Apple sandbox response: {exc}") from exc
        status = data.get("status")

    if status != 0:
        raise HTTPException(
            status_code=400,
            detail=f"Apple verifyReceipt failed (status={status}). See Apple status codes.",
        )
    return data


def extract_product_ids(receipt_body: Dict[str, Any]) -> List[str]:
    """Collect product ids from verifyReceipt payload."""
    seen: List[str] = []
    rec = receipt_body.get("receipt") or {}
    for tx in rec.get("in_app") or []:
        pid = tx.get("product_id")
        if pid and pid not in seen:
            seen.append(pid)
    lr = receipt_body.get("latest_receipt_info")
    if isinstance(lr, dict):
        lr = [lr]
    elif lr is None:
        lr = []
    for tx in lr:
        pid = tx.get("product_id")
        if pid and pid not in seen:
            seen.append(pid)
    return seen


def extract_line_items(receipt_body: Dict[str, Any]) -> List[Dict[str, str]]:
    """Pairs of (transaction_id, product_id) from verifyReceipt — latest_receipt_info + receipt.in_app."""
    rows: List[Dict[str, str]] = []
    seen: set[str] = set()

    def add(tx: Dict[str, Any]) -> None:
        tid = tx.get("transaction_id") or tx.get("original_transaction_id")
        pid = tx.get("product_id")
        if not tid or not pid:
            return
        tid_s, pid_s = str(tid), str(pid)
        key = f"{tid_s}:{pid_s}"
        if key in seen:
            return
        seen.add(key)
        rows.append({"transaction_id": tid_s, "product_id": pid_s})

    rec = receipt_body.get("receipt") or {}
    for tx in rec.get("in_app") or []:
        add(tx)

    lr = receipt_body.get("latest_receipt_info")
    if isinstance(lr, dict):
        lr_list = [lr]
    elif isinstance(lr, list):
        lr_list = lr
    else:
        lr_list = []
    for tx in lr_list:
        add(tx)

    return rows


def load_product_map() -> Dict[str, Dict[str, str]]:
    raw = os.environ.get("FEL_APPLE_PRODUCT_MAP") or "{}"
    try:
        m = json.loads(raw)
        if not isinstance(m, dict):
            return {}
        out: Dict[str, Dict[str, str]] = {}
        for k, v in m.items():
            if isinstance(v, dict) and v.get("item_type") and v.get("item_id"):
                out[str(k)] = {"item_type": str(v["item_type"]), "item_id": str(v["item_id"])}
        return out
    except Exception:
        return {}
