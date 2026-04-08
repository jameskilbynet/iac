"""
Ollama Prometheus Exporter

Polls the Ollama API and exposes model inventory, loaded model state,
and VRAM usage as Prometheus metrics. Designed to run as a sidecar
container — no request proxying, purely read-only polling.

Metrics exposed:
  ollama_models_available      - Total models available locally
  ollama_models_loaded         - Models currently loaded in memory
  ollama_model_loaded          - Per-model load state (1=loaded, 0=not)
  ollama_model_vram_bytes      - VRAM allocated per loaded model
  ollama_model_size_bytes      - On-disk size per available model
  ollama_vram_used_bytes_total - Total VRAM used across all loaded models
  ollama_up                    - Whether the Ollama API is reachable
"""

import logging
import os
import time

import requests
from prometheus_client import Gauge, start_http_server

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("ollama-exporter")

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://ollama:11434")
EXPORTER_PORT = int(os.environ.get("EXPORTER_PORT", "9394"))
POLL_TIMEOUT = int(os.environ.get("POLL_TIMEOUT", "10"))

# -- Metrics ----------------------------------------------------------------
ollama_up = Gauge(
    "ollama_up",
    "Whether the Ollama API is reachable (1=up, 0=down)",
)
models_available = Gauge(
    "ollama_models_available",
    "Total number of models available locally",
)
models_loaded = Gauge(
    "ollama_models_loaded",
    "Number of models currently loaded in memory",
)
model_loaded = Gauge(
    "ollama_model_loaded",
    "Whether a specific model is currently loaded (1=yes, 0=no)",
    ["model"],
)
model_vram_bytes = Gauge(
    "ollama_model_vram_bytes",
    "VRAM bytes allocated to a loaded model",
    ["model"],
)
model_size_bytes = Gauge(
    "ollama_model_size_bytes",
    "On-disk size in bytes of an available model",
    ["model"],
)
vram_used_total = Gauge(
    "ollama_vram_used_bytes_total",
    "Total VRAM bytes used across all loaded models",
)


def collect():
    """Poll Ollama API and update all metrics."""
    try:
        # /api/tags — all locally available models
        tags_resp = requests.get(
            f"{OLLAMA_URL}/api/tags", timeout=POLL_TIMEOUT
        )
        tags_resp.raise_for_status()
        tags = tags_resp.json().get("models", [])
        models_available.set(len(tags))

        available_names = set()
        for m in tags:
            name = m.get("name", m.get("model", "unknown"))
            available_names.add(name)
            model_size_bytes.labels(model=name).set(m.get("size", 0))

        # /api/ps — currently loaded models
        ps_resp = requests.get(
            f"{OLLAMA_URL}/api/ps", timeout=POLL_TIMEOUT
        )
        ps_resp.raise_for_status()
        running = ps_resp.json().get("models", [])
        models_loaded.set(len(running))

        loaded_names = set()
        total_vram = 0
        for m in running:
            name = m.get("name", m.get("model", "unknown"))
            loaded_names.add(name)
            vram = m.get("size_vram", m.get("size", 0))
            model_loaded.labels(model=name).set(1)
            model_vram_bytes.labels(model=name).set(vram)
            total_vram += vram

        vram_used_total.set(total_vram)

        # Mark unloaded models as 0
        for name in available_names - loaded_names:
            model_loaded.labels(model=name).set(0)
            model_vram_bytes.labels(model=name).set(0)

        ollama_up.set(1)

    except Exception as e:
        log.warning("Failed to poll Ollama: %s", e)
        ollama_up.set(0)


def main():
    log.info(
        "Starting ollama-exporter on :%d (polling %s)", EXPORTER_PORT, OLLAMA_URL
    )
    start_http_server(EXPORTER_PORT)

    while True:
        collect()
        time.sleep(14)  # slightly under the 15s scrape interval


if __name__ == "__main__":
    main()