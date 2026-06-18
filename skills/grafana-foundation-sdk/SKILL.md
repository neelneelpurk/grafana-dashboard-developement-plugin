---
name: grafana-foundation-sdk
description: Build Grafana dashboards as code with the Grafana Foundation SDK in TypeScript, Go, or Python. Use when the user wants to create, edit, or generate a Grafana dashboard, define panels/queries/variables programmatically, or produce dashboard JSON to provision into Grafana. Covers scaffolding a project, the builder API for all three languages, and serializing to dashboard JSON.
---

# Build Grafana dashboards with the Foundation SDK

The [Grafana Foundation SDK](https://github.com/grafana/grafana-foundation-sdk) is a set of
strongly-typed builder libraries for defining Grafana dashboards and other resources as code.
You compose a dashboard with a fluent builder, call `.build()`/`.Build()` to get a plain
dashboard object, serialize it to JSON, and provision it into Grafana.

**This plugin supports three languages: TypeScript, Go, and Python.** Pick based on the user's
request or the `sdk_language` plugin option (`typescript`, `go`, or `python`); default to
TypeScript when unset. The builder API is intentionally parallel across all three — same
concepts, language-idiomatic naming (`new DashboardBuilder(...)` / `.withPanel()` in TS;
`dashboard.NewDashboardBuilder(...)` / `.WithPanel()` in Go; `dashboard.Dashboard(...)` /
`.with_panel()` in Python). Requires Grafana **v11+** for the latest schema, plus Node.js 18+
(TS), Go 1.21+ (Go), or Python 3.9+ (Python).

## Workflow

1. **Clarify intent.** What is the dashboard for? What data source (Prometheus, Loki, etc.),
   what metrics, what audience (on-call vs. exec)? Pick a sensible default and proceed rather
   than over-asking — a first draft you can preview beats a long interview.
2. **Scaffold** a project if one doesn't exist: `scripts/scaffold.sh <dir> <language>`.
3. **Build** the dashboard in code using the builder API (see below and `reference.md`).
4. **Generate JSON**: run the program; it prints/writes the dashboard JSON.
5. **Provision & preview**: hand off to the `dashboard-preview` skill to push it to Grafana and
   screenshot it with Playwright.
6. **Grade**: hand off to the `dashboard-quality-rubric` skill to score quality and taste, then
   iterate on the lowest-scoring dimensions.

## Install

```bash
# TypeScript
npm install @grafana/grafana-foundation-sdk

# Go
go get github.com/grafana/grafana-foundation-sdk/go@v11.6.0+cog.4   # match your Grafana

# Python
pip install grafana-foundation-sdk
```

The SDK is versioned to match Grafana releases (e.g. `@grafana/grafana-foundation-sdk@11.x`,
`grafana-foundation-sdk/go@v11.x`, `grafana-foundation-sdk` 11.x on PyPI). Pin the version to
the target Grafana to avoid schema drift.

## TypeScript builder pattern

Each resource type lives in its own subpath: `dashboard`, `timeseries`, `stat`, `gauge`,
`table`, `prometheus`, `loki`, `common`, `units`.

```typescript
import { DashboardBuilder, RowBuilder } from '@grafana/grafana-foundation-sdk/dashboard';
import { PanelBuilder as TimeSeries } from '@grafana/grafana-foundation-sdk/timeseries';
import { PanelBuilder as Stat } from '@grafana/grafana-foundation-sdk/stat';
import { DataqueryBuilder as PromQuery } from '@grafana/grafana-foundation-sdk/prometheus';
import * as common from '@grafana/grafana-foundation-sdk/common';
import * as units from '@grafana/grafana-foundation-sdk/units';

const prometheus = { type: 'prometheus', uid: '${datasource}' };

const dashboard = new DashboardBuilder('Service Overview')
  .uid('service-overview')
  .tags(['generated', 'service'])
  .refresh('30s')
  .time({ from: 'now-6h', to: 'now' })
  .timezone(common.TimeZoneBrowser)
  // A datasource template variable so the board is portable
  .withVariable(/* see reference.md for QueryVariableBuilder */ undefined as any)
  .withRow(new RowBuilder('Golden signals'))
  .withPanel(
    new Stat()
      .title('Requests / sec')
      .datasource(prometheus)
      .unit(units.RequestsPerSecond)
      .withTarget(new PromQuery().expr('sum(rate(http_requests_total[5m]))'))
      .reduceOptions({ calcs: ['lastNotNull'], fields: '', values: false })
      .span(6).height(8),
  )
  .withPanel(
    new TimeSeries()
      .title('Latency p95')
      .description('95th percentile request latency')
      .datasource(prometheus)
      .unit(units.Seconds)
      .min(0)
      .withTarget(
        new PromQuery()
          .expr('histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))')
          .legendFormat('p95'),
      )
      .span(12).height(8),
  )
  .build();

console.log(JSON.stringify(dashboard, null, 2));
```

Key rules:
- Start with `new DashboardBuilder(title)`. Always set a stable `.uid()` so re-provisioning
  updates the same dashboard instead of creating duplicates.
- Add panels with `.withPanel(panelBuilder)`. Group with `.withRow(new RowBuilder(...))`.
- Each panel needs a `.datasource(...)` and at least one `.withTarget(query)`.
- Prefer template variables (`${datasource}`, `${job}`, `${instance}`) over hard-coded values.
- `.build()` returns a plain object; `JSON.stringify` it. Do **not** wrap it yourself — the SDK
  already produces a schema-valid dashboard model.

## Go builder pattern

The Go SDK mirrors the TypeScript one. Each resource type is its own package under
`github.com/grafana/grafana-foundation-sdk/go/...`. Builder methods are PascalCase; `Build()`
returns `(model, error)`.

```go
package main

import (
	"encoding/json"
	"fmt"

	"github.com/grafana/grafana-foundation-sdk/go/common"
	"github.com/grafana/grafana-foundation-sdk/go/dashboard"
	"github.com/grafana/grafana-foundation-sdk/go/prometheus"
	"github.com/grafana/grafana-foundation-sdk/go/stat"
	"github.com/grafana/grafana-foundation-sdk/go/timeseries"
	"github.com/grafana/grafana-foundation-sdk/go/units"
)

func main() {
	ds := dashboard.DataSourceRef{Type: cogPtr("prometheus"), Uid: cogPtr("${datasource}")}

	builder := dashboard.NewDashboardBuilder("Service Overview").
		Uid("service-overview").
		Tags([]string{"generated", "service"}).
		Refresh("30s").
		Time("now-6h", "now").
		Timezone(common.TimeZoneBrowser).
		WithRow(dashboard.NewRowBuilder("Golden signals")).
		WithPanel(
			stat.NewPanelBuilder().
				Title("Requests / sec").
				Datasource(ds).
				Unit(units.RequestsPerSecond).
				WithTarget(prometheus.NewDataqueryBuilder().
					Expr("sum(rate(http_requests_total[5m]))")).
				Span(6).Height(8),
		).
		WithPanel(
			timeseries.NewPanelBuilder().
				Title("Latency p95").
				Datasource(ds).
				Unit(units.Seconds).
				Min(0).
				WithTarget(prometheus.NewDataqueryBuilder().
					Expr("histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))").
					LegendFormat("p95")).
				Span(12).Height(8),
		)

	dash, err := builder.Build()
	if err != nil {
		panic(err)
	}
	out, _ := json.MarshalIndent(dash, "", "  ")
	fmt.Println(string(out))
}

func cogPtr[T any](v T) *T { return &v }
```

The same rules from the TypeScript section apply: stable `Uid`, a `Datasource` and at least one
`WithTarget` per panel, template variables over hard-coded values, and never hand-wrap the
output of `Build()`.

## Python builder pattern

Builders live under `grafana_foundation_sdk.builders.*`; methods are `snake_case`. Serialize
with the SDK's `JSONEncoder` rather than `json.dumps` so enums and nested models encode
correctly.

```python
from grafana_foundation_sdk.builders import dashboard, timeseries, stat, prometheus
from grafana_foundation_sdk.models.dashboard import DataSourceRef
from grafana_foundation_sdk.models import units
from grafana_foundation_sdk.models.common import TimeZoneBrowser
from grafana_foundation_sdk.cog.encoder import JSONEncoder

ds = DataSourceRef(type_val="prometheus", uid="${datasource}")

builder = (
    dashboard.Dashboard("Service Overview")
    .uid("service-overview")
    .tags(["generated", "service"])
    .refresh("30s")
    .time("now-6h", "now")
    .timezone(TimeZoneBrowser)
    .with_row(dashboard.Row("Golden signals"))
    .with_panel(
        stat.Panel()
        .title("Requests / sec")
        .datasource(ds)
        .unit(units.RequestsPerSecond)
        .with_target(
            prometheus.Dataquery().expr("sum(rate(http_requests_total[5m]))")
        )
        .span(6).height(8)
    )
    .with_panel(
        timeseries.Panel()
        .title("Latency p95")
        .datasource(ds)
        .unit(units.Seconds)
        .min_val(0)
        .with_target(
            prometheus.Dataquery()
            .expr("histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))")
            .legend_format("p95")
        )
        .span(12).height(8)
    )
)

print(JSONEncoder(sort_keys=True, indent=2).encode(builder.build()))
```

Same rules again: stable `uid`, a `datasource` and at least one `with_target` per panel,
template variables over hard-coded values, and let the SDK produce the model.

## Generating and provisioning JSON

- TypeScript: `npx tsx src/index.ts > dashboard.json` (or compile and run with node).
- Go: `go run . > dashboard.json`.
- Python: `python dashboard.py > dashboard.json`.
- Provision into Grafana with `scripts/provision-dashboard.sh dashboard.json`, which POSTs to
  `/api/dashboards/db` using the `grafana_url` / `grafana_token` plugin options. After
  provisioning, continue with the `dashboard-preview` skill.

See `reference.md` (in this skill directory) for the panel/query/variable/threshold API cheat
sheet, common units, and gotchas. Read it before writing non-trivial dashboards so method
names and import paths are exact rather than guessed.
