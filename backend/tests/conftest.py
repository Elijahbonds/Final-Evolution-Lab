"""Pytest configuration for the FEL backend suite.

THE PROBLEM THIS SOLVES
A large part of this suite is INTEGRATION tests: they call
`requests.get(f"{BASE_URL}/api/...")` against a running server backed by a
real MongoDB, rather than exercising the app in-process with FastAPI's
TestClient. On any runner without those services they produce 137 failures
and 43 errors — noise that buries real regressions and makes a green build
impossible by construction.

A test that cannot pass without a service it never starts is not failing —
it is INAPPLICABLE. This marks those modules as integration and skips them
with a clear reason when the backend is not reachable, so:

  · the unit suite is genuinely green and its failures mean something
  · integration tests still RUN whenever a backend IS available
    (locally, or in CI with a service container)

Force them on with:  FEL_REQUIRE_INTEGRATION=1  (they will then fail loudly
if the backend is missing, which is what you want in a staging pipeline).
"""

import os
import socket
from urllib.parse import urlparse

import pytest

# How an integration test is IDENTIFIED — by what the module DOES, not by a
# hardcoded name list that silently drifts as tests are added:
#   · imports `requests`  → drives a live server over HTTP  = integration
#   · uses TestClient     → exercises the app in-process    = unit
# Verified against this suite: the requests-based modules are exactly the
# ones that were producing 137 failures + 43 errors with no server running,
# and the TestClient modules are exactly the ones that were already passing.
def _is_integration_module(path: str) -> bool:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            src = fh.read()
    except OSError:
        return False
    imports_requests = ("import requests" in src) or ("from requests" in src)
    uses_testclient = "TestClient" in src
    return imports_requests and not uses_testclient


BASE_URL = os.environ.get("REACT_APP_BACKEND_URL", "").rstrip("/")
REQUIRE = os.environ.get("FEL_REQUIRE_INTEGRATION") == "1"


def _reachable(url: str, timeout: float = 1.5) -> bool:
    """True when something is listening on the URL's host:port."""
    if not url:
        return False
    parsed = urlparse(url if "://" in url else f"http://{url}")
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


BACKEND_UP = _reachable(BASE_URL)


def pytest_configure(config):
    config.addinivalue_line(
        "markers", "integration: needs a running backend + MongoDB"
    )


def pytest_collection_modifyitems(config, items):
    if BACKEND_UP or REQUIRE:
        return  # run them for real

    reason = (
        "integration test: needs a live backend at REACT_APP_BACKEND_URL "
        f"(currently {'unset' if not BASE_URL else BASE_URL + ' — not reachable'}). "
        "Set FEL_REQUIRE_INTEGRATION=1 to fail instead of skip."
    )
    skip = pytest.mark.skip(reason=reason)
    cache: dict[str, bool] = {}
    for item in items:
        path = str(getattr(item, "fspath", "") or "")
        if path not in cache:
            cache[path] = _is_integration_module(path)
        if cache[path]:
            item.add_marker(pytest.mark.integration)
            item.add_marker(skip)


def pytest_report_header(config):
    state = "reachable" if BACKEND_UP else "not reachable"
    return (
        f"FEL backend: {BASE_URL or '<unset>'} ({state}) · "
        f"integration tests {'ENABLED' if BACKEND_UP or REQUIRE else 'skipped'}"
    )
