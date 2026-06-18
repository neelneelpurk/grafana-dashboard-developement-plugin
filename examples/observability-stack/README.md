# Local observability stack (Grafana + Prometheus + sample metrics)

A self-contained stack for developing, previewing, and grading dashboards against **live,
realistic data** — no real infrastructure required.

## What's inside

| Service | Port | Purpose |
| --- | --- | --- |
| Grafana | 3000 | Dashboard UI. `admin` / `admin`; anonymous viewing enabled for Playwright. |
| Prometheus | 9090 | Scrapes the sample app + node-exporter every 5s. |
| sample-app | 8000 | Synthetic **checkout** service: golden-signal metrics (traffic, errors, latency histogram, queue depth, inventory). |
| node-exporter | 9100 | Real host metrics (CPU, memory, disk, network) for USE-style panels. |

Prometheus is auto-provisioned in Grafana with a stable datasource `uid: prometheus`, so
example dashboards can target it directly or via a `${datasource}` variable.

## Run it

```bash
docker compose up -d
# Grafana:    http://localhost:3000   (admin / admin)
# Prometheus: http://localhost:9090
# Metrics:    http://localhost:8000/metrics
docker compose down            # stop
```

Give the sample app ~30s to produce enough history for `rate()` windows to look good.

## Metrics the sample app exposes

- `http_requests_total{method,route,status,service="checkout"}` — counter (traffic + errors)
- `http_request_duration_seconds_bucket{route,service="checkout"}` — histogram (p50/p95/p99)
- `checkout_queue_depth` — gauge (saturation)
- `checkout_active_connections` — gauge
- `checkout_inventory_items{warehouse}` — gauge (table / bar-gauge demo)

## Build and preview a dashboard against it

The `examples/checkout-dashboard/checkout.ts` dashboard is built for exactly these metrics:

```bash
cd ../checkout-dashboard
npm install @grafana/grafana-foundation-sdk tsx
npx tsx checkout.ts > checkout.json
../../skills/grafana-foundation-sdk/scripts/provision-dashboard.sh checkout.json
# then preview with the dashboard-preview skill (Playwright MCP) and grade with the rubric
```

This is the recommended sandbox for the `/create-dashboard` and `/review-dashboard` workflows.
