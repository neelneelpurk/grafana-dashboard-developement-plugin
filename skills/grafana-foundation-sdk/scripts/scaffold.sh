#!/usr/bin/env bash
# Scaffold a Grafana Foundation SDK project.
# Usage: scaffold.sh <target-dir> <typescript|go|python>
set -euo pipefail

DIR="${1:?usage: scaffold.sh <target-dir> <typescript|go|python>}"
LANG="${2:-typescript}"

mkdir -p "$DIR"
cd "$DIR"

case "$LANG" in
  typescript|ts)
    echo "Scaffolding TypeScript Foundation SDK project in $DIR"
    cat > package.json <<'JSON'
{
  "name": "grafana-dashboards",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsx src/index.ts > dashboard.json"
  },
  "dependencies": {
    "@grafana/grafana-foundation-sdk": "^11.6.0"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "typescript": "^5.6.0"
  }
}
JSON
    mkdir -p src
    cat > src/index.ts <<'TS'
import { DashboardBuilder } from '@grafana/grafana-foundation-sdk/dashboard';
import { PanelBuilder as TimeSeries } from '@grafana/grafana-foundation-sdk/timeseries';
import { DataqueryBuilder as PromQuery } from '@grafana/grafana-foundation-sdk/prometheus';
import * as units from '@grafana/grafana-foundation-sdk/units';

const prometheus = { type: 'prometheus', uid: '${datasource}' };

const dashboard = new DashboardBuilder('My Dashboard')
  .uid('my-dashboard')
  .tags(['generated'])
  .refresh('30s')
  .time({ from: 'now-6h', to: 'now' })
  .withPanel(
    new TimeSeries()
      .title('Example')
      .datasource(prometheus)
      .unit(units.Short)
      .withTarget(new PromQuery().expr('vector(1)')),
  )
  .build();

console.log(JSON.stringify(dashboard, null, 2));
TS
    echo "Next: (cd $DIR && npm install && npm run build)"
    ;;

  go)
    echo "Scaffolding Go Foundation SDK project in $DIR"
    cat > go.mod <<'MOD'
module grafana-dashboards

go 1.21
MOD
    mkdir -p panels
    cat > panels/panels.go <<'GO'
// Package panels holds reusable, parametrized panel builders shared across
// dashboards. Add a panel shape here once and call it with different
// titles/queries/units instead of copy-pasting builder chains in main.go.
package panels

import (
	"github.com/grafana/grafana-foundation-sdk/go/cog"
	"github.com/grafana/grafana-foundation-sdk/go/common"
	"github.com/grafana/grafana-foundation-sdk/go/dashboard"
	"github.com/grafana/grafana-foundation-sdk/go/prometheus"
	"github.com/grafana/grafana-foundation-sdk/go/stat"
	"github.com/grafana/grafana-foundation-sdk/go/timeseries"
)

// Ptr is the generic helper the SDK needs for optional pointer fields.
func Ptr[T any](v T) *T { return &v }

// Datasource returns a portable ${datasource}-variable reference for the given plugin type.
func Datasource(dsType string) dashboard.DataSourceRef {
	return dashboard.DataSourceRef{Type: Ptr(dsType), Uid: Ptr("${datasource}")}
}

// TimeSeries builds a "value over time" panel — the shape shared by latency,
// traffic, and error-rate panels. Reuse it for every rate/gauge-over-time metric
// instead of writing a new builder chain per panel.
func TimeSeries(title, expr, legend, unit string, ds dashboard.DataSourceRef) *timeseries.PanelBuilder {
	return timeseries.NewPanelBuilder().
		Title(title).
		Datasource(ds).
		Unit(unit).
		Min(0).
		WithTarget(prometheus.NewDataqueryBuilder().Expr(expr).LegendFormat(legend))
}

// CurrentValue builds a Stat panel reduced to the latest value — reuse it for any
// "one number that matters right now" signal.
func CurrentValue(title, expr, unit string, ds dashboard.DataSourceRef) *stat.PanelBuilder {
	return stat.NewPanelBuilder().
		Title(title).
		Datasource(ds).
		Unit(unit).
		ReduceOptions(common.NewReduceDataOptionsBuilder().Calcs([]string{"lastNotNull"}).Fields("").Values(false)).
		WithTarget(prometheus.NewDataqueryBuilder().Expr(expr))
}

// WithPanels adds each panel in order and returns the builder for further chaining,
// so a slice of panels built by a factory function can be spliced into a dashboard
// in one call.
func WithPanels(b *dashboard.DashboardBuilder, panels ...cog.Builder[dashboard.Panel]) *dashboard.DashboardBuilder {
	for _, p := range panels {
		b = b.WithPanel(p)
	}
	return b
}
GO
    cat > main.go <<'GO'
package main

import (
	"encoding/json"
	"fmt"

	"grafana-dashboards/panels"

	"github.com/grafana/grafana-foundation-sdk/go/dashboard"
	"github.com/grafana/grafana-foundation-sdk/go/units"
)

func main() {
	ds := panels.Datasource("prometheus")

	builder := dashboard.NewDashboardBuilder("My Dashboard").
		Uid("my-dashboard").
		Tags([]string{"generated"}).
		Refresh("30s").
		Time("now-6h", "now").
		WithRow(dashboard.NewRowBuilder("Overview"))

	builder = panels.WithPanels(builder,
		panels.TimeSeries("Example", "vector(1)", "value", units.Short, ds).Span(24).Height(8),
	)

	dash, err := builder.Build()
	if err != nil {
		panic(err)
	}
	out, _ := json.MarshalIndent(dash, "", "  ")
	fmt.Println(string(out))
}
GO
    echo "Next: (cd $DIR && go get github.com/grafana/grafana-foundation-sdk/go@latest && go run . > dashboard.json)"
    ;;

  python|py)
    echo "Scaffolding Python Foundation SDK project in $DIR"
    cat > requirements.txt <<'REQ'
grafana-foundation-sdk>=11.6.0
REQ
    cat > dashboard.py <<'PY'
from grafana_foundation_sdk.builders import dashboard, timeseries, prometheus
from grafana_foundation_sdk.models.dashboard import DataSourceRef
from grafana_foundation_sdk.cog.encoder import JSONEncoder

ds = DataSourceRef(type_val="prometheus", uid="${datasource}")

builder = (
    dashboard.Dashboard("My Dashboard")
    .uid("my-dashboard")
    .tags(["generated"])
    .refresh("30s")
    .time("now-6h", "now")
    .with_panel(
        timeseries.Panel()
        .title("Example")
        .datasource(ds)
        .unit("short")
        .with_target(prometheus.Dataquery().expr("vector(1)"))
    )
)

print(JSONEncoder(sort_keys=True, indent=2).encode(builder.build()))
PY
    echo "Next: (cd $DIR && pip install -r requirements.txt && python dashboard.py > dashboard.json)"
    ;;

  *)
    echo "Unknown language: $LANG (expected typescript, go, or python)" >&2
    exit 1
    ;;
esac
