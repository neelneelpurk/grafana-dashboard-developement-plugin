---
description: Build a Grafana dashboard as code (Foundation SDK) from a description, then preview and grade it.
argument-hint: <what to monitor, e.g. "my Prometheus-backed checkout service">
---

Create a Grafana dashboard for: **$ARGUMENTS**

Drive the full build-and-verify loop using this plugin's skills and agents:

1. **Plan the panels.** Use the `panel-selection-advisor` skill to map each metric to the right
   visualization. If the request is just "monitor service X", default to the golden signals
   (latency, traffic, errors, saturation).
2. **Build the dashboard** with the `grafana-foundation-sdk` skill in the configured language
   (`sdk_language` option; default TypeScript — but honor any language the user names). Set a
   stable `uid`, units, thresholds, template variables (`${datasource}`, `${job}`), and group
   panels into rows with the most important signal top-left. Read the skill's `reference.md` so
   method names are exact.
3. **Generate the JSON** by running the program.
4. **Provision & preview** with the `dashboard-preview` skill: push it to Grafana
   (`provision-dashboard.sh`) and screenshot it with Playwright MCP. Confirm panels load with
   data; fix empty/error panels at the source and re-provision.
5. **Grade** with the `dashboard-quality-rubric` skill and iterate on the weakest dimensions
   until the dashboard scores at least Ship-ready (≥ 80).

If no Grafana is running, offer the bundled `examples/observability-stack/` (Grafana +
Prometheus + sample metrics) so the dashboard can be previewed against real data.

Deliver: the SDK source, the generated dashboard JSON, the preview screenshot path, and the
final scorecard. You may delegate the build to the `grafana-dashboard-architect` agent and the
grading to the `dashboard-taste-critic` agent.
