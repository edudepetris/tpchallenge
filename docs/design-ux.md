# Design UX

ASCII mockups for tpchallenge views. Each section captures a single view: its purpose, the mockup, and notes on states/interactions.

## Conventions

- Mockups use box-drawing characters; treat them as low-fidelity layout sketches, not pixel-perfect specs.
- `[ Button ]` = action. `< field >` = input. `…` = truncated/variable content.
- States worth mocking: empty, loading, error, populated.

---

## Views

<!-- Add one subsection per view as we go. Template below. -->

### Search — multi-source streaming results

**Purpose:** User submits a query; the app dispatches three concurrent background jobs that scrape different sources via Playwright (real browser). Each source's results stream back to the UI independently as it completes — no waiting for the slowest one.

**Route:** `GET /` — single page. Submitting the form posts to a non-redirecting endpoint (e.g. `POST /search` returning a `turbo_stream` response / `204`) and dispatches jobs scoped to an **ephemeral `run_id`** generated per submit. No DB record is created; results render into the same page via a Turbo Stream subscription on that `run_id`.

**Architecture sketch:**

```
  Single page                 Rails                 Jobs (Playwright)
  -----------                 -----                 -----------------
   submit form ──► POST /search ──► enqueue ──┬──► SourceA job ──► browser ──► broadcast ──┐
        ▲           (no record,               ├──► SourceB job ──► browser ──► broadcast ──┤──► Turbo Stream
        │            no redirect)             └──► SourceC job ──► browser ──► broadcast ──┘     (channel:
        │                                                                                         ephemeral run_id)
        └──── Turbo Stream subscription on same page; panels update in-place ─────────────────┘
```

**Mockup — initial submit / all pending:**

```
+--------------------------------------------------------------------+
|                                                                    |
|   < blue running shoes size 10                          >  [ Go ]  |
|                                                                    |
|   +--------------------+ +--------------------+ +----------------+ |
|   |  Source A          | |  Source B          | |  Source C      | |
|   |  ⠋ launching…      | |  ⠋ launching…      | |  ⠋ launching… | |
|   |                    | |                    | |                | |
|   |  ░░░░░░░░░░░░░░░░  | |  ░░░░░░░░░░░░░░░░  | |  ░░░░░░░░░░░░ | |
|   |  ░░░░░░░░░░░░░░░░  | |  ░░░░░░░░░░░░░░░░  | |  ░░░░░░░░░░░░ | |
|   |  ░░░░░░░░░░░░░░░░  | |  ░░░░░░░░░░░░░░░░  | |  ░░░░░░░░░░░░ | |
|   |                    | |                    | |                | |
|   +--------------------+ +--------------------+ +----------------+ |
|                                                                    |
+--------------------------------------------------------------------+
```

**Mockup — mid-stream (B done, A streaming, C still loading):**

```
+--------------------------------------------------------------------+
|                                                                    |
|   +--------------------+ +--------------------+ +----------------+ |
|   |  Source A   ⠴ 3/?  | |  Source B   ✓ 5    | |  Source C  ⠋  | |
|   |--------------------| |--------------------| |----------------| |
|   |  • Item A1   $42   | |  • Item B1   $39   | |  navigating…  | |
|   |  • Item A2   $51   | |  • Item B2   $45   | |                | |
|   |  • Item A3   $48   | |  • Item B3   $50   | |  ░░░░░░░░░░░░ | |
|   |  ⠴ fetching more…  | |  • Item B4   $55   | |  ░░░░░░░░░░░░ | |
|   |                    | |  • Item B5   $60   | |                | |
|   |                    | |  done · 1.8s       | |                | |
|   +--------------------+ +--------------------+ +----------------+ |
+--------------------------------------------------------------------+
```

**Mockup — all complete, with one error:**

```
+--------------------------------------------------------------------+
|                                                                    |
|   +--------------------+ +--------------------+ +----------------+ |
|   |  Source A   ✓ 6    | |  Source B   ✓ 5    | |  Source C  ✗  | |
|   |--------------------| |--------------------| |----------------| |
|   |  • Item A1   $42   | |  • Item B1   $39   | |  ⚠ timeout    | |
|   |  • Item A2   $51   | |  • Item B2   $45   | |    after 30s  | |
|   |  • Item A3   $48   | |  • Item B3   $50   | |                | |
|   |  • Item A4   $44   | |  • Item B4   $55   | |  [ Retry ]    | |
|   |  • Item A5   $47   | |  • Item B5   $60   | |                | |
|   |  • Item A6   $53   | |                    | |                | |
|   |  done · 4.2s       | |  done · 1.8s       | |  failed · 30s | |
|   +--------------------+ +--------------------+ +----------------+ |
+--------------------------------------------------------------------+
```

**Per-panel states:**

| State       | Indicator                                  |
|-------------|--------------------------------------------|
| queued      | `⠋ queued`                                 |
| launching   | `⠋ launching…` (Playwright spinning up)    |
| navigating  | `⠴ navigating…` (page load)                |
| streaming   | `⠴ N/?` rows appearing incrementally       |
| done        | `✓ N · Ts` final count + duration          |
| error       | `✗` + message + `[ Retry ]`                |

**Interactions:**

- Submitting the form mints an ephemeral `run_id`, subscribes the page to a Turbo Stream for that id, and enqueues three `SourceScrapeJob`s tagged with `run_id`. No `Search` record is created and no navigation occurs.
- The three panels render in-place under the form in `queued` state.
- Each job broadcasts updates to the `run_id` channel; panels update independently.
- `[ Retry ]` re-enqueues only the failing source for the current `run_id`.
- Submitting a new query mints a new `run_id`, replaces the panels, and abandons/cancels the prior run's in-flight jobs. Nothing is persisted between submits — refreshing the page clears results.

**Open questions:**

- Show a unified "merged" view alongside the per-source panels, or only per-source for now?
- Cancel semantics: hard-kill the Playwright context, or let it finish and discard?
- Should `run_id` live in the URL as a query param (`?run=…`) for debugging, or stay fully client/session-side?

---
