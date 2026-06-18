"""Synthetic golden-signal metrics for a fake "checkout" service.

Exposes a Prometheus /metrics endpoint on :8000 and continuously simulates
realistic traffic so dashboards built against it show live, plausible data:

  - http_requests_total{method,route,status}      counter  (traffic + errors)
  - http_request_duration_seconds{route}          histogram (latency p50/p95/p99)
  - checkout_queue_depth                           gauge     (saturation)
  - checkout_active_connections                    gauge
  - checkout_inventory_items{warehouse}            gauge     (table/bar-gauge demo)

No external dependencies beyond prometheus_client.
"""
import math
import random
import threading
import time

from prometheus_client import Counter, Gauge, Histogram, start_http_server

REQUESTS = Counter(
    "http_requests_total", "Total HTTP requests", ["method", "route", "status"]
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency in seconds",
    ["route"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5),
)
QUEUE_DEPTH = Gauge("checkout_queue_depth", "Pending checkout jobs")
ACTIVE_CONNS = Gauge("checkout_active_connections", "Active connections")
INVENTORY = Gauge("checkout_inventory_items", "Inventory on hand", ["warehouse"])

ROUTES = ["/cart", "/checkout", "/pay", "/receipt"]
WAREHOUSES = ["us-east", "us-west", "eu-central", "ap-south"]


def simulate():
    t0 = time.time()
    inventory = {w: random.randint(500, 5000) for w in WAREHOUSES}
    for w, v in inventory.items():
        INVENTORY.labels(warehouse=w).set(v)

    while True:
        elapsed = time.time() - t0
        # Diurnal-ish traffic wave so time series have shape.
        wave = 0.5 + 0.5 * math.sin(elapsed / 30.0)
        burst = random.randint(5, 25) + int(40 * wave)

        for _ in range(burst):
            route = random.choices(ROUTES, weights=[4, 3, 2, 1])[0]
            method = "POST" if route in ("/checkout", "/pay") else "GET"

            # Latency: most fast, occasional slow tail; /pay is slower.
            base = 0.04 if route != "/pay" else 0.12
            latency = abs(random.gauss(base, base * 0.6))
            if random.random() < 0.03:  # tail latency
                latency += random.uniform(0.3, 1.5)
            LATENCY.labels(route=route).observe(latency)

            # Error rate ~2%, spiking with saturation.
            err_chance = 0.02 + 0.08 * wave
            if random.random() < err_chance:
                status = random.choice(["500", "503", "504"])
            elif random.random() < 0.05:
                status = "404"
            else:
                status = "200"
            REQUESTS.labels(method=method, route=route, status=status).inc()

        QUEUE_DEPTH.set(max(0, int(random.gauss(20 + 60 * wave, 10))))
        ACTIVE_CONNS.set(max(1, int(random.gauss(50 + 100 * wave, 15))))
        for w in WAREHOUSES:
            # Drift down with sales, restock when low, so the gauge stays positive.
            inventory[w] += random.randint(-5, 4)
            if inventory[w] < 50:
                inventory[w] += random.randint(200, 800)
            INVENTORY.labels(warehouse=w).set(inventory[w])

        time.sleep(1)


if __name__ == "__main__":
    start_http_server(8000)
    print("Sample metrics on :8000/metrics")
    threading.Thread(target=simulate, daemon=True).start()
    while True:
        time.sleep(3600)
