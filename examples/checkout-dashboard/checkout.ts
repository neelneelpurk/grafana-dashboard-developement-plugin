// Example dashboard built with the Grafana Foundation SDK against the bundled
// observability stack (examples/observability-stack). It uses the synthetic
// "checkout" service metrics and lays out the four golden signals.
//
//   npm install @grafana/grafana-foundation-sdk tsx
//   npx tsx checkout.ts > checkout.json
//   ../../skills/grafana-foundation-sdk/scripts/provision-dashboard.sh checkout.json
//
import { DashboardBuilder, RowBuilder } from '@grafana/grafana-foundation-sdk/dashboard';
import { PanelBuilder as TimeSeries } from '@grafana/grafana-foundation-sdk/timeseries';
import { PanelBuilder as Stat } from '@grafana/grafana-foundation-sdk/stat';
import { PanelBuilder as Gauge } from '@grafana/grafana-foundation-sdk/gauge';
import { PanelBuilder as BarGauge } from '@grafana/grafana-foundation-sdk/bargauge';
import { DataqueryBuilder as PromQuery } from '@grafana/grafana-foundation-sdk/prometheus';
import * as units from '@grafana/grafana-foundation-sdk/units';

// The example stack provisions a Prometheus datasource with uid "prometheus".
const prom = { type: 'prometheus', uid: 'prometheus' };

const dashboard = new DashboardBuilder('Checkout — Golden Signals')
  .uid('checkout-golden-signals')
  .tags(['generated', 'checkout', 'golden-signals'])
  .refresh('10s')
  .time({ from: 'now-15m', to: 'now' })

  // --- Top-line current values -------------------------------------------------
  .withRow(new RowBuilder('Now'))
  .withPanel(
    new Stat()
      .title('Requests / sec')
      .datasource(prom)
      .unit(units.RequestsPerSecond)
      .reduceOptions({ calcs: ['lastNotNull'], fields: '', values: false })
      .withTarget(new PromQuery().expr('sum(rate(http_requests_total{service="checkout"}[1m]))'))
      .span(6).height(6),
  )
  .withPanel(
    new Stat()
      .title('Error rate')
      .datasource(prom)
      .unit(units.PercentUnit)
      .decimals(2)
      .reduceOptions({ calcs: ['lastNotNull'], fields: '', values: false })
      .thresholds({
        mode: 'absolute',
        steps: [
          { value: null, color: 'green' },
          { value: 0.02, color: 'yellow' },
          { value: 0.05, color: 'red' },
        ],
      } as any)
      .withTarget(
        new PromQuery().expr(
          'sum(rate(http_requests_total{service="checkout",status=~"5.."}[1m])) / sum(rate(http_requests_total{service="checkout"}[1m]))',
        ),
      )
      .span(6).height(6),
  )
  .withPanel(
    new Gauge()
      .title('Queue saturation')
      .datasource(prom)
      .unit(units.Short)
      .min(0).max(150)
      .thresholds({
        mode: 'absolute',
        steps: [
          { value: null, color: 'green' },
          { value: 90, color: 'yellow' },
          { value: 120, color: 'red' },
        ],
      } as any)
      .withTarget(new PromQuery().expr('checkout_queue_depth'))
      .span(6).height(6),
  )
  .withPanel(
    new Stat()
      .title('Active connections')
      .datasource(prom)
      .unit(units.Short)
      .reduceOptions({ calcs: ['lastNotNull'], fields: '', values: false })
      .withTarget(new PromQuery().expr('checkout_active_connections'))
      .span(6).height(6),
  )

  // --- Latency -----------------------------------------------------------------
  .withRow(new RowBuilder('Latency'))
  .withPanel(
    new TimeSeries()
      .title('Request latency (p50 / p95 / p99)')
      .datasource(prom)
      .unit(units.Seconds)
      .min(0)
      .withTarget(
        new PromQuery()
          .expr('histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{service="checkout"}[5m])) by (le))')
          .legendFormat('p50'),
      )
      .withTarget(
        new PromQuery()
          .expr('histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="checkout"}[5m])) by (le))')
          .legendFormat('p95'),
      )
      .withTarget(
        new PromQuery()
          .expr('histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service="checkout"}[5m])) by (le))')
          .legendFormat('p99'),
      )
      .span(24).height(8),
  )

  // --- Traffic & errors --------------------------------------------------------
  .withRow(new RowBuilder('Traffic & errors'))
  .withPanel(
    new TimeSeries()
      .title('Requests / sec by route')
      .datasource(prom)
      .unit(units.RequestsPerSecond)
      .min(0)
      .withTarget(
        new PromQuery()
          .expr('sum by (route) (rate(http_requests_total{service="checkout"}[1m]))')
          .legendFormat('{{route}}'),
      )
      .span(12).height(8),
  )
  .withPanel(
    new TimeSeries()
      .title('Errors / sec by status')
      .datasource(prom)
      .unit(units.RequestsPerSecond)
      .min(0)
      .withTarget(
        new PromQuery()
          .expr('sum by (status) (rate(http_requests_total{service="checkout",status=~"[45].."}[1m]))')
          .legendFormat('{{status}}'),
      )
      .span(12).height(8),
  )

  // --- Inventory (bar gauge / breakdown) --------------------------------------
  .withRow(new RowBuilder('Inventory by warehouse'))
  .withPanel(
    new BarGauge()
      .title('Inventory on hand')
      .datasource(prom)
      .unit(units.Short)
      .withTarget(
        new PromQuery()
          .expr('checkout_inventory_items')
          .legendFormat('{{warehouse}}')
          .instant(),
      )
      .span(24).height(8),
  )
  .build();

console.log(JSON.stringify(dashboard, null, 2));
