# Foundation SDK reference (TypeScript, Go & Python)

Concise API cheat sheet. Method names are parallel across languages: TS uses `camelCase` +
`new XBuilder()`, Go uses `PascalCase` + `x.NewXBuilder()`, Python uses `snake_case` +
`x.Panel()` / `dashboard.Dashboard()`. Leaf package/module names are shared (`dashboard`,
`timeseries`, `stat`, `gauge`, `table`, `barchart`, `prometheus`, `loki`, `common`, `units`).

## Panel types → package

| Visualization | TS import subpath | Go package | Python builder module |
| --- | --- | --- | --- |
| Time series | `@grafana/grafana-foundation-sdk/timeseries` | `.../go/timeseries` | `builders.timeseries` |
| Stat (single value) | `.../stat` | `.../go/stat` | `builders.stat` |
| Gauge | `.../gauge` | `.../go/gauge` | `builders.gauge` |
| Bar gauge | `.../bargauge` | `.../go/bargauge` | `builders.bargauge` |
| Table | `.../table` | `.../go/table` | `builders.table` |
| Bar chart | `.../barchart` | `.../go/barchart` | `builders.barchart` |
| Pie chart | `.../piechart` | `.../go/piechart` | `builders.piechart` |
| Heatmap | `.../heatmap` | `.../go/heatmap` | `builders.heatmap` |
| Logs | `.../logs` | `.../go/logs` | `builders.logs` |
| Text/Markdown | `.../text` | `.../go/text` | `builders.text` |

## Dashboard-level methods

| Purpose | TS | Go | Python |
| --- | --- | --- | --- |
| Create | `new DashboardBuilder("Title")` | `dashboard.NewDashboardBuilder("Title")` | `dashboard.Dashboard("Title")` |
| Stable id | `.uid("x")` | `.Uid("x")` | `.uid("x")` |
| Tags | `.tags(["a","b"])` | `.Tags([]string{"a","b"})` | `.tags(["a","b"])` |
| Auto refresh | `.refresh("30s")` | `.Refresh("30s")` | `.refresh("30s")` |
| Time range | `.time({from:"now-6h",to:"now"})` | `.Time("now-6h","now")` | `.time("now-6h","now")` |
| Timezone | `.timezone(common.TimeZoneBrowser)` | `.Timezone(common.TimeZoneBrowser)` | `.timezone(TimeZoneBrowser)` |
| Editable | `.editable()` / `.readonly()` | `.Editable()` / `.Readonly()` | `.editable(True)` |
| Row | `.withRow(new RowBuilder("Name"))` | `.WithRow(dashboard.NewRowBuilder("Name"))` | `.with_row(dashboard.Row("Name"))` |
| Panel | `.withPanel(panel)` | `.WithPanel(panel)` | `.with_panel(panel)` |
| Variable | `.withVariable(v)` | `.WithVariable(v)` | `.with_variable(v)` |
| Link | `.links([...])` | `.Links([]dashboard.DashboardLink{...})` | `.links([...])` |
| Finalize | `.build()` → object | `.Build()` → `(model, error)` | `.build()` → model |

Python panel note: numeric bounds are `.min_val(n)` / `.max_val(n)` (not `min`/`max`), and the
datasource ref field is `DataSourceRef(type_val="prometheus", uid="...")` because `type` is a
reserved word.

## Panel methods (common to all panel builders)

`.title(s)` `.description(s)` `.datasource(ref)` `.unit(units.X)` `.decimals(n)`
`.min(n)` `.max(n)` `.span(1..24)` `.height(n)` `.transparent()` `.noValue(s)`
`.withTarget(query)` `.thresholds(builder)` `.mappings([...])` `.overrideByName(...)`.

Time series extras: `.lineWidth(n)`, `.fillOpacity(0..100)`, `.gradientMode(...)`,
`.drawStyle(common.GraphDrawStyleLine)`, `.stacking(...)`, `.legend(builder)`,
`.tooltip(builder)`.

Stat/gauge extras: `.reduceOptions({calcs:["lastNotNull"], fields:"", values:false})`,
`.colorMode(common.BigValueColorModeValue)`, `.graphMode(common.BigValueGraphModeArea)`,
`.orientation(common.VizOrientationAuto)`.

## Queries

Prometheus (TS):
```typescript
import { DataqueryBuilder as PromQuery } from '@grafana/grafana-foundation-sdk/prometheus';
new PromQuery()
  .expr('sum(rate(http_requests_total[5m])) by (status)')
  .legendFormat('{{status}}')
  .range()          // range query (default for time series)
  .instant()        // instant query (use for stat/table snapshots)
  .refId('A');
```

Prometheus (Go):
```go
prometheus.NewDataqueryBuilder().
    Expr("sum(rate(http_requests_total[5m])) by (status)").
    LegendFormat("{{status}}").
    Range().
    RefId("A")
```

Prometheus (Python):
```python
from grafana_foundation_sdk.builders import prometheus
prometheus.Dataquery() \
    .expr("sum(rate(http_requests_total[5m])) by (status)") \
    .legend_format("{{status}}") \
    .range() \
    .ref_id("A")
```

Loki swaps `prometheus` → `loki` and `.expr(...)` takes a LogQL string.

## Datasource reference

Prefer a `${datasource}` variable so the dashboard is portable:

TS: `const prometheus = { type: 'prometheus', uid: '${datasource}' };` then `.datasource(prometheus)`.

Go:
```go
ds := dashboard.DataSourceRef{Type: strPtr("prometheus"), Uid: strPtr("${datasource}")}
```

## Template variables

TS:
```typescript
import { QueryVariableBuilder, DatasourceVariableBuilder } from '@grafana/grafana-foundation-sdk/dashboard';

.withVariable(new DatasourceVariableBuilder('datasource').type('prometheus').label('Data source'))
.withVariable(
  new QueryVariableBuilder('job')
    .label('Job')
    .datasource({ type: 'prometheus', uid: '${datasource}' })
    .query({ query: 'label_values(up, job)', refId: 'job' })
    .refresh(2)          // 2 = on time range change
    .multi(true)
    .includeAll(true),
)
```

Go:
```go
dashboard.NewDatasourceVariableBuilder("datasource").Type("prometheus").Label("Data source")
dashboard.NewQueryVariableBuilder("job").
    Label("Job").
    Query(dashboard.StringOrMap{String: cog.ToPtr("label_values(up, job)")}).
    Multi(true).IncludeAll(true)
```

## Thresholds

TS:
```typescript
import { ThresholdsConfigBuilder } from '@grafana/grafana-foundation-sdk/dashboard';
import * as common from '@grafana/grafana-foundation-sdk/common';

.thresholds(
  new ThresholdsConfigBuilder()
    .mode(common.ThresholdsMode.Absolute)
    .steps([
      { value: null, color: 'green' },
      { value: 70,   color: 'yellow' },
      { value: 90,   color: 'red' },
    ]),
)
```

## Common units (`units.*`)

`Percent` (0–100), `PercentUnit` (0–1), `Seconds`, `Milliseconds`, `Short`, `Bytes`,
`BytesSI`, `BitsPerSecondSI`, `RequestsPerSecond`, `OpsPerSecond`, `Dollars`. When unsure,
use `units.Short` rather than leaving a panel unitless.

## Gotchas

- **Always set a `uid`.** Without it Grafana creates a new dashboard on every provision.
- A panel with no `datasource` or no target renders empty — set both.
- Grid: `span` is in 24ths of the row width; `height` is in grid rows (~30px). Keep panels
  on a tidy grid; don't overlap.
- The SDK output is already a complete dashboard model. Provision it as
  `{"dashboard": <model>, "overwrite": true, "folderUid": "..."}` via `/api/dashboards/db`
  (the `provision-dashboard.sh` script does this for you).
- Pin SDK version to the Grafana version. Mismatches surface as unknown-field errors on import.
