---
name: analyst-runbook
kind: workflow
description: >
  The analyst process to run before and around building anything: triage the
  request, reuse existing work first, choose the right response shape, hand off to
  the build/design/report skills, then verify the answer. Use at the START of any
  analytical request ("what's our…", "show me…", "why did X change", "build a
  dashboard for…") to decide what to do. Do NOT use for chart-type or layout
  decisions (use dashboard-design) or for error diagnosis after a failed render
  (use dataface-troubleshooting).
metadata:
  author: fivetran
---
# Analyst Runbook

The process a senior analyst follows. Run the **intake triage** first, every time —
it decides what you build and prevents redundant or wrong-shaped answers. Then hand
off to the build skills, and **verify the answer** before you deliver it.

## 1. Intake triage (first, every request)

**Reuse first.** Call `dft search` for faces that already answer
this or come close. Adapt an existing dashboard instead of building from scratch
whenever one fits — and say which you reused.

1. **Pick the response shape.** Match the deliverable to the ask; don't default to a
   dashboard:
   - **a number / short answer** — one metric or a one-line factual answer
   - **one chart** — a single trend, ranking, or breakdown
   - **a dashboard** — several related charts that explore a topic together
   - **a report** — narrative plus charts that walk through an analysis
2. **Clarify only what blocks you.** If the metric, grain, time window, or filters
   are ambiguous *and* the choice changes the answer, ask one focused question.
   Otherwise state the assumption and proceed.

## 2. Do the analysis

Explore the data, then build incrementally — hand off to the skill that owns each step:

- **`dft skills dashboard-build`** — build/edit faces (explore schema → write → validate → render)
- **`dft skills dashboard-design`** — chart-type, layout, and color decisions
- **`dft skills report-design`** — narrative reports
- Use `dft schema` / `dft schema -s` to find the real vocabulary, and
  `dft query SOURCE SQL` to confirm values before you claim them.

## 3. Verify the answer (not only the artifact)

`dft skills dashboard-review` checks the *artifact* — does it render, is it well formed.
Before delivering, also verify the *answer*:

- **Right source.** Numbers come from the table that actually owns this metric, not a
  lookalike column. Confirm with `dft query SOURCE SQL`.
- **Right question.** The result answers what was asked — right grain, right filters,
  right time window — with no extra or missing slices.
- **Sanity.** Totals, row counts, and units are plausible; nulls, duplicates, or
  fan-out haven't silently skewed the number.
- **Stated assumptions.** Any choice you made (window, definition, exclusions) is
  surfaced to the user, not hidden.

If a check fails, fix it before delivering — never ship a number you can't stand behind.

## Analysis-method patterns

Methods, not layouts (layout lives in dashboard-design). Reach for the right shape:

- **Retention / cohort.** Group entities by their first-activity period (the cohort),
  then measure the active fraction at each later period. Anchor on the cohort, not the
  calendar; report as a retention curve or triangle.
- **Funnel / conversion.** Order the steps, count distinct entities reaching each, and
  report step-to-step conversion. Define the entity and the window once — don't mix
  per-step windows — and watch for entities that skip or re-enter steps.
- **Rate decomposition.** When a ratio (e.g. revenue per user) moves, split the change
  into numerator vs denominator (and mix vs within-segment) so you can say *why* it
  moved, not just that it did.
