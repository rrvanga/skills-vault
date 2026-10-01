# LMArena leaderboard — worked example (2026-08)

Goal: category Elo (Overall, Coding, Math, Creative Writing, Hard Prompts) for a set of models.

## Site vs API hosts
- Public site: `https://arena.ai` (also reachable via `https://lmarena.ai`).
- JSON API backend (discovered in a JS chunk, `60757-*.js`): `https://arena-api-stable.vercel.app`.
- The frontend proxies API calls through the site origin (`arena.ai/api/...`), but direct backend calls are the ones that matter.

## Direct JSON API — 403 (auth wall)
Both routes return HTTP **403** `{"error":{"code":"403","message":"Forbidden"}}` even with browser UA + `Accept: application/json` + Origin/Referer:

- `https://arena-api-stable.vercel.app/api/v2/leaderboard-sets/public/leaderboards/text-overall-style_control/leaderboard-snapshots/latest`
- `https://arena-api-stable.vercel.app/api/v1/leaderboard-sets/public/leaderboards/text-overall-style_control/leaderboard-snapshots/latest`

It is a Vercel firewall (client-token / `ddforward` signed-proxy) — do NOT keep reverse-engineering it. Use the SSR route below instead.

## Working route: server-rendered category pages
Each category page embeds the FULL leaderboard (rank + rating per model) in its Next.js RSC payload:

```
curl -s -A "Mozilla/5.0 ... Chrome/126.0 Safari/537.36" \
  "https://arena.ai/leaderboard/text/<category>" -o <cat>.html
```

### Category slug map (URL slug → embedded leaderboard-set ID)
The URL segment is hyphenated; the internal leaderboard-set id uses **underscores** and a `-style_control` suffix. This mismatch is the main gotcha — grep for the real id instead of guessing:

| Category | URL slug | leaderboard-set ID |
|---|---|---|
| Overall | `overall` | `text-overall-style_control` |
| Coding | `coding` | `text-coding-style_control` |
| Math | `math` | `text-math-style_control` |
| Creative Writing | `creative-writing` | `text-creative_writing-style_control` |
| Hard Prompts | `hard-prompts` | `text-hard_prompts-style_control` |

Discover the id set with: `grep -oE 'leaderboard-sets/public/leaderboards/[A-Za-z0-9_-]+' page.html`.

### Parsing the embedded entries
Entries live after `"entries":[` and before `"voteCutoffISOString"` in the double-escaped RSC text. Regex over the raw text (no need to unescape):

```python
pat = re.compile(
    r'\{\\"rank\\":(\d+),\\"rankUpper\\":(\d+),\\"rankLower\\":(\d+),'
    r'\\"modelKey\\":\\"([^"\\]+)\\",\\"modelDisplayName\\":\\"([^"\\]+)\\",'
    r'\\"rating\\":([0-9.]+)'
)
```

Fields of interest: `rank`, `modelKey` (internal key, often `<name>-text`), `modelDisplayName` (what users see), `rating` (Elo). Typical counts: ~376–391 entries per category.

## Naming quirks (requested name ≠ leaderboard name)
The board only carries specific display names. Examples where a requested name had NO exact match:

- `kimi-k3` → only `kimi-k3-max`
- `glm-5.2` → only `glm-5.2-max`
- `gpt-5.6-luna` → only `gpt-5.6-luna-xhigh` (luna/sol/terra are reasoning-effort tiers, all `-xhigh`)
- `kimi-k2.7-code` → absent entirely (closest: `kimi-k2.6`, `kimi-k3-max`)

Always dump all unique `modelDisplayName` values matching the relevant prefix and map requested → actual, flagging non-exact matches rather than silently substituting.
