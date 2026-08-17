# Google Flights SSR extraction (no browser needed)

Worked recipe (2026-08-15): live fare research YVR→HYD across Nov 2026–Jan 2027,
14 date pairs, ~2MB/page, no browser, no API key, no JS execution.

## The fetch

GET with browser UA, currency param, freeform query:
```
https://www.google.com/travel/flights?curr=CAD&hl=en&gl=ca&q=Flights from YVR to HYD on 2026-12-01 returning on 2026-12-20
```
- `curr=CAD` forces `$` prices (CAD tokens in the page confirm the currency).
- Freeform is forgiving: "Flights from X to Y on DATE returning on DATE" or the
  terser "flights YVR to HYD 2026-11-08 returning 2026-11-22" both work.
- urllib + browser UA works (no curl needed); a default python UA may 403 —
  always send a browser UA.
- Response ~1.8–2.2MB; the first page of results is server-rendered into the HTML.

## Prices

- Regex `\$([0-9,]{3,})` over the whole page; parse ints.
- Each fare appears ~6× (SSR + repeated JSON state blocks) — DEDUPE by value.
- `min(unique)` = cheapest fare Google shows for that date pair.
- Document order is NOT price order (best-sort DOM ≠ price-sorted): take the
  min, never trust the first card.
- Premium cabins pollute the range ($17–18K on YVR–HYD = business via LHR):
  flag the outliers in the report, keep the min honest.

## Itinerary details (airlines / stops / hubs)

Flight cards embed a base64 attribute `data-gs="…"`; base64-decode it → airline
code + flight-number tokens (regex `([A-Z]{2})\s?\d{2,4}`), e.g. "AC7|CX627".
- 2 flight codes = 1 stop; 3 = 2 stops.
- Connection city = the airline's hub (TK→IST, EK→DXB, QR→DOH, EY→AUH, LH→FRA,
  BA→LHR, AF→CDG, KL→AMS, SQ→SIN, TG→BKK, AI→DEL, JL→NRT/HND, CX→HKG). Say
  "via <hub>" — never invent specific flight-number routes from memory.
- Cards also carry aria-labels "Departure time: …" / "Arrival time: …" with
  day-of-week dates; a "+N" badge = arrival +N days (timezone crossing).
  DON'T quote computed total durations: per-leg labels misread easily (a card
  looked like a 15h 1-stop YVR→HYD — impossible — before realizing the arrival
  label was a leg, not the final). Stick to price / airlines / stops / hubs.

## Sweep pattern ("cheapest when?")

- Month-level searches ("…in November 2026") return an EMPTY page — the
  flexible-date calendar is client-side, not SSR'd. Sample date pairs instead.
- Iterate departure dates at weekly granularity with ~14-day returns; fetch
  each; record min price; build the curve. Champion = global min.
- Retry odd failures: a date pair can return a 0-price ~1.8MB shell once and
  work on retry (transient). Retry with alternate phrasing before concluding
  "no flights".
- Bash inline quoting of these URLs breaks — write a small Python fetch script
  (urllib + browser UA, save HTML to /tmp, print min per file).

## Route-specific findings (YVR→HYD context)

- No direct route; every fare is 1–2 stops via a hub.
- One-way ≈ round-trip price on thin routes (Dec 1 OW $2,091 vs RT $2,261) —
  report the relationship; buying the round trip anyway can be rational.
- Season shape: early Nov & late Jan floor ~$1,967–2,031 (AC+SQ via SIN,
  AC+LH via FRA, AF via CDG); Christmas peak (Dec 20) ~$2,988 — +$1,000 on
  IDENTICAL routing (AC+SQ). "Same flights, different day" comparisons make
  the peak premium concrete for the user.
