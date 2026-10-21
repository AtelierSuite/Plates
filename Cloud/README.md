# PlatesCloud

The server side of Plates: one Cloudflare Worker that writes recipes with Gemma 4 on Workers AI and, when the cook taps Decide for me, asks Cloudflare's Clef-flash on Workers AI to pick one of the recipe ideas. Clef-flash also says which seasonings and garnishes can be seen on a finished dish, for its icon. Every call is signed with App Attest, and each device has a Durable Object that holds its key, its assertion counter, and its daily counts.

## Develop and deploy

```bash
npm install && npm test
npm run dev
npm run deploy
```

Cloudflare Workers Builds deploys `plates-cloud` from this repository. The Worker is connected to the repository's `main` branch with these build settings:

| Setting | Value |
| --- | --- |
| Root directory | `Cloud` |
| Build watch paths | Include `Cloud/*` |
| Build command | `npm ci && npm run typecheck && npm test` |
| Deploy command | `npx cf deploy` |

A push to `main` that changes `Cloud/` is tested and deployed. A push that changes nothing in `Cloud/` does not start a build.

## Settings

Plain vars are read from the environment by `cloudflare.config.ts` at deploy time, and are empty until set. In Workers Builds they are build variables on the Worker, alongside `NODE_VERSION` set to `24`. An endpoint that needs a missing setting answers 503 rather than running unchecked.

| Var | Meaning |
| --- | --- |
| `APPLE_TEAM_ID` | The 10-character Apple team ID |
| `APP_BUNDLE_ID` | The app's bundle ID, `com.tsubuzaki.Plates` |
| `APP_ATTEST_ENVIRONMENT` | `development` for debug builds, `production` for TestFlight and the App Store |
| `WRITE_DAILY_LIMIT` | Recipes Gemma writes per device per day |
| `IDEATE_DAILY_LIMIT` | Sets of ideas Gemma writes per device per day |
| `DECIDE_DAILY_LIMIT` | Decide for me picks per device per day |
| `TOPPINGS_DAILY_LIMIT` | Dish icon questions per device per day |

Daily quotas use the server’s UTC date and reset at midnight UTC. The four limits are defaults. A device whose Durable Object has a row in its `limits` table (`kind` is `write`, `ideate`, `decide`, or `toppings`, `daily` a whole number) uses that instead, so one device can be given more or fewer calls without a deploy. Each device's Durable Object is named by its key ID in base64url, and `limits` is its only SQL table: the key, the counter, and the daily counts stay in its key-value storage.

For example, `INSERT OR REPLACE INTO limits (kind, daily) VALUES ('write', 50)` gives a device 50 Gemma calls a day.

Secrets are set once on the Worker, under Settings, Variables and Secrets, and carry over to each new deploy. For `npm run dev` they are kept in a gitignored `.dev.vars` copied from `.dev.vars.example`:

| Secret | Where it comes from |
| --- | --- |
| `CHALLENGE_SECRET` | Any long random string; signs attestation challenges |
| `SKIP_APP_ATTEST` | `true` to accept unsigned requests to `localhost`, so a debug build in Simulator can call `npm run dev`. Ignored on any other host; never set it in a deploy |

Workers AI needs no key: the `AI` binding runs on the account the Worker is deployed to.

## Endpoints

Everything is `POST` except `/health`. The signed endpoints take three headers:

| Header | Value |
| --- | --- |
| `X-Plates-Key-Id` | The App Attest key ID, base64 |
| `X-Plates-Assertion` | `DCAppAttestService.generateAssertion` over the SHA-256 of the exact request body, base64 |
| `X-Plates-UTC-Offset` | Optional legacy client offset, validated but not used for quotas; days end at midnight UTC |

| Path | Signed | What it does |
| --- | --- | --- |
| `/v1/challenge` | No | Returns `{ "challenge" }`, good for five minutes |
| `/v1/attest` | No | Takes `{ keyId, attestation, challenge }`. The attestation's client data hash is the SHA-256 of the challenge string's UTF-8 bytes. Registers the key once |
| `/v1/chat/completions` | Yes | OpenAI Chat Completions in and out, streamed when `stream` is true. Always Gemma 4 26B A4B; `max_tokens` is capped at 1,400 |
| `/v1/ideate` | Yes | The same as `/v1/chat/completions`, for the dish ideas: counted against `IDEATE_DAILY_LIMIT`, with `max_tokens` capped at 500 |
| `/v1/decide` | Yes | Takes `{ requestId, request, ingredients, tools, ideas: [{ title, summary }] }` and returns `{ index, confidence, probabilities, remaining }` |
| `/v1/toppings` | Yes | Takes `{ dish, steps: [{ title, points }], ingredients }` and returns `{ visible, remaining }`, where `visible` holds Clef-flash's probability, line by line, that the ingredient can be seen on the dish as it is served |
| `/v1/limits` | Yes | Returns today's `{ limit, remaining }` for each of `write`, `ideate`, `decide`, and `toppings`, without counting anything |

A metered call that fails upstream is given back. A retried Decide for me with the same `requestId` returns the first answer without counting again. Every metered response carries `X-Plates-Remaining`, and a call past the limit gets 429.
