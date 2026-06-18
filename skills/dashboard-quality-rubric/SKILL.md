---
name: dashboard-quality-rubric
description: Grade a Grafana dashboard against a quality-and-taste rubric and produce an actionable scorecard. Use after building and previewing a dashboard to score it across correctness, layout, visualization choice, readability, consistency, performance, and visual taste, then recommend the highest-impact fixes. Requires the dashboard JSON and (ideally) a Playwright screenshot from the dashboard-preview skill.
---

# Dashboard quality & taste rubric

A dashboard can be schema-valid and still be bad: wrong viz, no units, unreadable at a glance,
panels that don't load. This skill scores a dashboard against a fixed rubric and returns a
scorecard with concrete fixes, so quality is judged consistently instead of by vibes.

## Inputs

- **Required:** the dashboard JSON (Foundation SDK output or exported from Grafana).
- **Strongly recommended:** a rendered screenshot from the `dashboard-preview` skill. Taste and
  readability dimensions can only be judged honestly from the rendered result — grade those from
  the screenshot, not from the JSON.
- Optional: the user's intent (audience, purpose) to weight relevance.

## How to grade

1. Read the rubric in `rubric.md` (this skill directory). It defines 8 weighted dimensions, each
   scored 0–5 with explicit anchor descriptions.
2. For each dimension, assign a 0–5 score grounded in **specific evidence** — cite the panel
   title, the JSON field, or what you see in the screenshot. No score without a reason.
3. Compute the weighted total out of 100. Map to a grade band (see rubric).
4. Produce the scorecard in the format below.
5. List fixes ordered by impact (weight × points lost). Be specific enough to act on
   ("Panel 'Latency' has no unit — set `unit(units.Seconds)`"), not generic ("improve units").
6. Offer to apply the top fixes via the `grafana-foundation-sdk` skill and re-grade. Treat one
   build → preview → grade → fix loop as the unit of work; iterate until the score clears the
   user's bar (default: ≥ 80 / "Ship-ready").

## Scoring honesty

- Do not inflate. If there's no screenshot, say which dimensions you could not fully verify and
  grade them conservatively from the JSON.
- A dashboard with any panel showing "No data" or a datasource error cannot score above
  "Needs work" overall, regardless of other dimensions — broken data is disqualifying.
- Taste is real but must be defended: tie every taste deduction to a concrete, nameable issue
  (clutter, inconsistent color, misleading axis), never "feels off".

## Scorecard format

```
# Dashboard Quality Scorecard — <dashboard title>
Overall: <score>/100  ·  Grade: <band>  ·  Screenshot: <path or "none — JSON only">

| # | Dimension              | Weight | Score /5 | Weighted | Evidence |
|---|------------------------|--------|----------|----------|----------|
| 1 | Data correctness       |  20    |   x      |   xx     | ...      |
| 2 | Visualization choice   |  15    |   x      |   xx     | ...      |
| 3 | Layout & structure     |  15    |   x      |   xx     | ...      |
| 4 | Readability at a glance|  15    |   x      |   xx     | ...      |
| 5 | Units, thresholds, legends | 10 |   x      |   xx     | ...      |
| 6 | Consistency            |  10    |   x      |   xx     | ...      |
| 7 | Performance & query hygiene | 5 |   x      |   xx     | ...      |
| 8 | Visual taste & polish  |  10    |   x      |   xx     | ...      |

## Top fixes (highest impact first)
1. ...
2. ...
3. ...

## What's already good
- ...
```

See `rubric.md` for the full dimension definitions, 0–5 anchors, and grade bands.
