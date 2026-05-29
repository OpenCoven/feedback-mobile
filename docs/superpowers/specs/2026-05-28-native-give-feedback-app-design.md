# Native Give-Feedback iOS App + Public End-User API (Architecture C)

**Date:** 2026-05-28
**Status:** Design approved (sections), pending spec review
**Author:** Andrew Peltekci (with Claude)
**Related:** `2026-05-28-ios-sdk-conformance-native-design.md` (the embeddable SDK — a separate product)

## 1. Summary

Build a **standalone native iOS app for end users to give feedback** to an
OpenCoven Feedback instance: browse boards, vote, comment, submit posts, read
the changelog, and read the help-center docs — with content that **auto-updates**
as the web app changes, because everything is fetched live from an API.

The audit found OpenCoven exposes a rich, OpenAPI-documented REST API at
`/api/v1/*`, but it is **API-key authenticated for team/admin/integration use**
— unusable from a shipped consumer app. The only thing an anonymous/end-user
client can fetch today is the public widget config and `kb-search`; everything
else an end user reads or writes goes through server-rendered TanStack server
functions (portal) or the embedded widget iframe — neither a public contract a
native app can consume.

Therefore this is a **two-track program**:

- **Track 1 — Public End-User API** (in `OpenCoven/feedback`): a thin
  `/api/public/v1/*` surface — anonymous reads + end-user (better-auth bearer)
  writes — that **reuses the existing domain services**, adding no new business
  logic and no schema migrations.
- **Track 2 — Native iOS app** (in `feedback-mobile`): a SwiftUI app that
  consumes Track 1 via a client generated from its OpenAPI spec.

The API contract is the shared linchpin; this single design doc covers both
tracks. Implementation is sequenced API-first (Track 2 is untestable without
Track 1, though it can start against a spec-generated mock).

## 2. Goals / Non-goals

### Goals
- End users can browse boards, vote, comment, and submit posts natively.
- End users can read the changelog and help-center articles natively.
- Content auto-updates from the server with no app release (live API reads).
- End-user auth via better-auth **bearer token** (email-OTP primary).
- The iOS client is generated from a published OpenAPI spec, so contract
  evolution flows into the app via codegen rather than hand edits.
- The public API is additive to OpenCoven, reusing existing services — small,
  reviewable, logic-free, maximizing upstream-PR acceptance odds.

### Non-goals (v1 — all fast-follows)
- Anonymous writes (v1 requires sign-in for submit/vote/comment).
- Roadmap tab, notifications, push notifications.
- Offline write queue (writes require connectivity).
- Multi-instance support (the app points at one instance).
- Any change to the embeddable `OpenCovenFeedback` SDK (separate product).

## 3. Audit findings (why Architecture C)

- `/api/v1/*` is comprehensive and OpenAPI-documented (`/api/v1/openapi.json`,
  Swagger UI at `/api/v1/docs`) but every route (incl. reads) calls
  `withApiKeyAuth(request, { role: 'team' | 'admin' })` — a workspace API key
  (`Bearer qb_…`). Not shippable in a consumer app.
- End-user content (boards/posts/changelog/help/roadmap) is rendered by the
  **portal** via TanStack server functions, and interactions go through the
  **widget** (`/api/widget/*`: config, session, identify, search, kb-search,
  upload) using cookie sessions / host-signed `ssoToken`. No public REST CRUD.
- Auth stack is **better-auth** with the **`bearer` plugin enabled**, plus
  email-OTP, magic-link, OAuth, and separate portal (end-user) auth config — so
  a native app can authenticate end users with a bearer token.
- Conclusion: the product has every feature; what's missing is a public
  end-user API. Adding one (Track 1) unlocks a fully native app (Track 2).

## 4. Track 1 — Public End-User API (`OpenCoven/feedback`)

**Principle:** add a thin public surface, reuse all existing logic. Handlers
call the same domain services the portal/admin API already use
(`post.public`, `post.voting`, `comment.service`, `changelog.service`,
`help-center.service`, `getPublicWidgetConfig`). New code = an end-user auth
middleware, thin route handlers, response schemas, and OpenAPI entries. No new
business logic, no migrations.

### Auth
- Namespace `/api/public/v1/*`, distinct from admin `/api/v1/*` (API-key) and
  `/api/widget/*`.
- End-user auth = better-auth **bearer token** (`bearer` plugin already on).
  Sign-in via **email-OTP** (primary; no deep link needed) or OAuth. Token
  stored client-side, sent as `Authorization: Bearer <token>`.
- **Reads: anonymous allowed.** With a token, responses enrich with personal
  state (e.g. `hasVoted`).
- **Writes: require a valid session.** v1 = signed-in only; anonymous
  (widget-style throwaway session) writes are a documented fast-follow.
- Reuse the existing per-IP/per-session rate limiter and tenant scoping.
- Auth endpoints: reuse better-auth's existing `/api/auth/*` (email-OTP
  request/verify, OAuth) — no new auth endpoints.

### Endpoints
Reads (anonymous OK):
- `GET /api/public/v1/config` — public config (tabs, theme, defaultBoard) — reuses `getPublicWidgetConfig`
- `GET /api/public/v1/boards`
- `GET /api/public/v1/posts?boardId=&sort=&search=&cursor=&limit=` — feed (`voteCount`, `status`, `hasVoted`)
- `GET /api/public/v1/posts/:id`
- `GET /api/public/v1/posts/:id/comments?cursor=`
- `GET /api/public/v1/changelog?cursor=` · `GET /api/public/v1/changelog/:id`
- `GET /api/public/v1/help/categories` · `GET /api/public/v1/help/articles/:slug` · `GET /api/public/v1/help/search?q=` (reuses `kb-search`)

Writes (bearer session required):
- `POST /api/public/v1/posts` — `{ boardId, title, content }`
- `POST /api/public/v1/posts/:id/vote` — toggle vote
- `POST /api/public/v1/posts/:id/comments` — `{ content, parentId? }`

### Contract delivery
- Publish `/api/public/v1/openapi.json` (extend the existing OpenAPI generator
  or a parallel public spec). This is the single source of truth the iOS client
  is generated from.

### Error model
- Mirror the existing `{ error: { code, message } }` shape used by the widget
  and v1 responses. Standard codes: `UNAUTHORIZED`, `VALIDATION_ERROR`,
  `NOT_FOUND`, `RATE_LIMITED`, `WIDGET_DISABLED`/`DISABLED`.

## 5. Track 2 — Native iOS app (`feedback-mobile`)

**Navigation:** 4-tab bar — Feedback · Changelog · Help · Account.

**Relationship to the SDK:** the app does native reads + writes against the
public API and does **not** use the widget WebView. The `OpenCovenFeedback` SDK
remains a separate product (for third parties embedding the widget). The app
reuses the `FeedbackApp` demo *shell* — `AppConfiguration`'s instance-URL
plumbing and design tokens — replacing the single `HomeView` with the tabs.

**Modules** (each a SwiftUI view + observable model):
- **API client** — generated from `/api/public/v1/openapi.json` via
  **swift-openapi-generator**. Base URL = configured instance URL. Regenerating
  from the published spec is how contract evolution enters the app.
- **Auth** — `AuthStore` holding a better-auth bearer token in the **Keychain**.
  Email-OTP flow (email → code → token). Anonymous browsing by default; the
  first write triggers a sign-in sheet, then the action retries.
- **Feedback** — boards + feed (sort/filter), post detail (comments + vote),
  compose/submit.
- **Changelog** — list + detail (read-only).
- **Help** — categories → articles + search (read-only).
- **Account** — sign-in/out, profile.
- **Shared** — design system, OpenAPI-generated models, instance-URL config,
  loading/empty/error states.

**Data flow:** View ⇄ observable model ⇄ generated client ⇄ public API. Reads
anonymous (enriched with `hasVoted` when signed in); writes attach the bearer
token; a `401` opens the sign-in sheet then retries the action.

**Offline/caching (light):** `URLCache` + a small on-disk cache of the last
feed/changelog/help so the app opens to content offline (read-only). Writes
need connectivity; no offline write queue in v1.

**Config/scope:** single-instance, configured by instance URL (like the SDK).

## 6. Sequencing

**API-first, two tracks:**

- **Track 1 (web) — build/PR first.**
  1. End-user auth middleware (`optionalSession` / `requireSession`, bearer).
  2. Read endpoints (config, boards, posts, comments, changelog, help).
  3. Write endpoints (submit, vote, comment).
  4. `/api/public/v1/openapi.json`.
  5. Tests (below).

- **Track 2 (iOS) — start against a spec-generated mock, then the real API.**
  1. Client codegen + instance-URL config + email-OTP auth (`AuthStore`, Keychain).
  2. Feedback tab (feed, detail, vote, comment, submit).
  3. Changelog tab.
  4. Help tab.
  5. Account tab.
  6. Polish: offline cache, accessibility, error/empty states.

Each track ships as its own implementation plan (writing-plans), sharing this
design and the OpenAPI contract.

## 7. Testing

- **Web (Track 1):** per-endpoint integration tests (reuse existing patterns),
  auth tests for anonymous vs session paths, and an OpenAPI contract check.
- **iOS (Track 2):** view-model unit tests against the generated mock client,
  snapshot tests for key screens (feed, post detail, submit, sign-in), and one
  integration smoke against a live/staging instance.

## 8. Risks & mitigations

- **Upstream PR acceptance (biggest).** Track 1 is a PR to a repo we don't own.
  Mitigation: additive, logic-free, mirrors existing route/auth/schema patterns.
  Fallback: run the public API as a thin separate service over the same DB/API
  if upstream declines.
- **Email-OTP abuse.** Reuse the existing `signin-rate-limit`.
- **Cross-repo contract drift.** OpenAPI is the single source; iOS client is
  codegen'd; add a CI check that the committed spec matches the routes.
- **App Store wrapper rejection.** Low — this is a genuinely native app, not a
  WebView wrapper.

## 9. Decisions log (forks resolved during design)

- App audience: **end-user give-feedback app** (not admin/triage).
- Feature set: submit, browse + vote + comment, changelog, help-center.
- Web-repo access: **yes** — we can add a public API (Architecture C).
- Auth: better-auth **bearer**, **email-OTP** primary; **signed-in writes only**
  in v1 (anonymous writes deferred).
- Navigation: **4-tab bar** (Feedback · Changelog · Help · Account).
- The standalone app does **not** depend on the embeddable SDK.

## 10. Definition of done

- Track 1: `/api/public/v1/*` reads (anonymous) and writes (bearer session) pass
  integration + auth tests; `/api/public/v1/openapi.json` is published; PR open
  upstream.
- Track 2: the app builds in CI; a signed-in user can browse a board, vote,
  comment, submit a post, read the changelog, and read a help article against a
  live instance; content reflects server-side changes with no app release.
