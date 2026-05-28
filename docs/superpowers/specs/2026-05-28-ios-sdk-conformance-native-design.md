# OpenCoven Feedback iOS SDK — Conformance + Native Layer (Plan B)

**Date:** 2026-05-28
**Status:** Design approved, pending spec review
**Author:** Andrew Peltekci (with Claude)

## 1. Summary

The `feedback-mobile` repo ships an iOS SDK (`OpenCovenFeedback`) that wraps the
OpenCoven Feedback web widget in a `WKWebView` and bridges native↔web over
`postMessage`. An audit found the SDK is **functionally dead against a real
instance**: a botched "Quackback → OpenCoven" rebrand renamed the *wire
protocol*, but the web widget's protocol is frozen on the `quackback:` namespace.
Every command is sent on the wrong channel, wrapped in invalid JavaScript, and
the demo app does not compile.

This plan restores conformance to the canonical widget contract, then adds the
native ergonomics that justify a native SDK over a raw WebView: typed Swift
events, a SwiftUI surface, hardened identity (including anonymous→identified
merge), config-driven behavior, robust WebView UX, and the contract tests + CI
that would have caught these bugs.

The widget remains the rendering and network layer. The SDK stays a thin,
provably-correct native host. Native REST screens, push, Android, and offline
caching are explicitly out of scope (that is Plan C).

## 2. Goals / Non-goals

### Goals
- The SDK conforms to the canonical widget protocol and provably communicates
  with a live instance.
- Public event surface is strongly typed (no `[String: Any]` at the boundary).
- Identity supports verified (JWT), unverified named, anonymous, and clear, plus
  anonymous→identified session merge.
- Idiomatic SwiftUI entry point in addition to the imperative UIKit API.
- Server config (`config.json`) gates behavior (tabs, image upload, verified-only).
- Contract tests execute the bridge JS; CI builds the package *and* the app target.
- A publishable, tagged 1.0 SPM package.

### Non-goals (YAGNI)
- Native REST-driven screens for boards/posts/comments/changelog (Plan C).
- Push notifications, offline content caching.
- Android SDK changes.
- Any change to the web `OpenCoven/feedback` repo. The contract there is the
  source of truth; we conform to it, we do not modify it.

## 3. Canonical contract (source of truth)

Defined in `OpenCoven/feedback`. These are the facts the SDK must match. The
wire protocol stays `quackback:`-namespaced even though the product is rebranded.

### Native bridge (`apps/web/src/lib/client/widget-bridge.ts`)
- The widget calls `window.__quackbackNative.dispatch(eventType, message)` when
  present (two arguments: the event type string with the `quackback:` prefix
  stripped, and the full message object). Otherwise it falls back to
  `window.parent.postMessage` — which goes nowhere in a top-frame WKWebView.
- Native context is detected by the `?source=native` query param (the SDK
  already sets `source=native&platform=ios`).

### Inbound — host → widget (`WidgetInboundMessages`)
- `quackback:identify` — `{ anonymous: true } | { id, email, name?, avatarURL? } | { ssoToken } | null`
- `quackback:metadata` — `Record<string, string>` (null value on a key = delete)
- `quackback:locale` — `string`
- `quackback:open` — `{ view?: 'home' | 'new-post', title?, board? } | undefined`
- There is **no** `init` message. Theme/config is delivered via `config.json`
  and URL params, not a postMessage.

### Outbound — widget → host (`WidgetOutboundMessages`)
- `quackback:ready` — handshake; flush the queued commands on receipt.
- `quackback:close` — user closed the widget.
- `quackback:navigate` — `{ url }`.
- `quackback:identify-result` — `{ success, user | null, error? }`.
- `quackback:auth-change` — `{ user: { id, name, email, avatarUrl } | null }`.
- `quackback:event` — `{ name, payload }` where `name` ∈ `WidgetEventName`.

### Event names + payloads (`WidgetEventMap`)
- `ready` — `{}`
- `open` — `{}`
- `close` — `{}`
- `post:created` — `{ id, title, board: { id, name, slug }, statusId: string | null }`
- `vote` — `{ postId, voted, voteCount }`
- `comment:created` — `{ postId, commentId, parentId: string | null }`
- `identify` — `{ success, user: { id, name, email } | null, anonymous, error? }`

### Identity (`routes/api/widget/identify.ts`, `lib/server/widget/identity-token.ts`)
- `ssoToken` is an **HS256 JWT** signed with the widget secret. Claims:
  `{ sub|id, email, name?, avatarURL?, iat, exp }`; non-reserved claims become
  user attributes. Default TTL 5 minutes. This is the verified path.
- Unverified named identify (`{ id, email, name?, avatarURL? }`) is accepted
  **only** when verified-identity-only mode is off.
- `{ anonymous: true }` starts/continues an anonymous session.
- `null` clears (logout).
- `previousToken` (a prior widget session token) merges anonymous activity
  (votes, comments) into the identified user.
- The SDK does **not** call `/api/widget/identify` directly; it sends
  `quackback:identify` and the widget performs the network call.

### Config (`routes/api/widget/config[.]json.ts`)
- `GET {instanceUrl}/api/widget/config.json` →
  `{ enabled, theme?: { lightPrimary, lightPrimaryForeground, darkPrimary, darkPrimaryForeground, radius, themeMode }, tabs?: { feedback, changelog, help }, imageUploadsInWidget?, hmacRequired? }`.
- Colors are normalized to hex server-side for cross-client (web/iOS/Android)
  consumption. The SDK already reads `theme.lightPrimary` correctly.

## 4. Current-state gaps (what changes)

| Concern | Contract | SDK today | Action |
|---|---|---|---|
| Message prefix | `quackback:` | `opencoven-feedback:` | restore `quackback:` |
| Native global | `window.__quackbackNative` | `window.__opencoven-feedbackNative` (invalid JS) | restore + fix JS |
| Bridge JS validity | callable `dispatch` | hyphen → SyntaxError | rewrite with valid identifiers / bracket access |
| `init` command | none | SDK sends theme via `init` | remove |
| `open` views | `home`, `new-post` | adds `changelog` | drop `changelog` as a view; gate tabs |
| Events | ready, open, close, post:created, vote, comment:created, identify | ready, vote, submit, close, navigate | re-map to contract |
| `submit` | `post:created` | `submit` | rename/map |
| `navigate` | outbound `{ url }` | treated as `event` | parse as message, typed `{ url }` |
| `identify-result` / `auth-change` | outbound | unhandled | surface as events |
| `.open` event | exists | missing enum case (compile error) | add typed `open` event |
| `previousToken` merge | supported | unhandled | persist + send |
| verified-only | `hmacRequired` | ignored | gate + error event |

What is already correct and stays: `?source=native&platform=ios`, the
`config.json` theme fetch (`lightPrimary`), `avatarURL` field naming, SPM
structure, and the security tooling (gitleaks, swiftlint, xcconfig blocking).

## 5. Architecture

Reorganize into focused units, each independently understandable and testable.

- **Protocol layer** (replaces `Internal/JSBridge.swift`): the single source of
  truth for the `quackback:` contract. Builds inbound command strings; parses
  outbound messages into typed values. Pure, Foundation-only. This is where the
  contract lives and where contract tests point.
- **Bridge layer** (`Internal/FeedbackWebView.swift` + injected JS): owns the
  `WKWebView`, injects a *valid* script defining
  `window.__quackbackNative.dispatch`, registers the message handler, runs the
  `ready` handshake and command queue, and manages loading/offline/error states
  and external-link handling.
- **Identity** (`Identity.swift` + session-token store): models ssoToken /
  named / anonymous / clear, and persists the widget session token for
  `previousToken` merge.
- **Events** (`OpenCovenFeedbackEvent.swift`): a typed enum with associated,
  decoded payload structs. Delivered through callback tokens **and** an
  `AsyncStream`.
- **Public API** (`OpenCovenFeedback.swift`): the imperative facade
  (configure / identify / metadata / open / close / launcher / on / off /
  destroy), preserved where already correct.
- **SwiftUI surface** (new): a `.feedbackLauncher(config:)` view modifier and a
  `FeedbackButton`, wrapping the imperative API so SwiftUI hosts never touch
  window plumbing.
- **Config** (`OpenCovenFeedbackConfig.swift` + a `ServerConfig` model): the
  fetched `config.json` (theme, `tabs`, `imageUploadsInWidget`, `hmacRequired`)
  consumed to gate behavior.

The cross-platform `#else` (non-UIKit) stub in `OpenCovenFeedback.swift` stays so
the package builds and unit-tests on macOS hosts (and so the Foundation-only
protocol/event/identity layers are testable without a simulator).

## 6. Detailed work by milestone

### M1 — Foundation (conformance + safety net)
Deliverable: the SDK provably talks to a live instance, and CI prevents
regressions.

1. **Wire protocol**: restore `quackback:` prefix across all inbound commands;
   remove `init`. Update all string assertions in `JSBridgeTests` to the
   `quackback:` namespace.
2. **Bridge JS**: rewrite the injected script so it is valid JavaScript —
   `window.__quackbackNative = { dispatch: function(type, msg) { ... } }` and
   `window.webkit.messageHandlers["quackback"].postMessage(...)` (bracket
   access; no hyphenated member names). Register the handler under a valid name
   (`quackback`) matching what the script posts to.
3. **Handshake**: on `quackback:ready`, flush queued commands and notify ready
   (theme already arrives via `config.json`; no `init` send).
4. **Events re-map**: parse outbound `quackback:event{name,payload}`,
   `quackback:close`, `quackback:navigate{url}`, `quackback:identify-result`,
   `quackback:auth-change`. Replace the `submit` case with `post:created`; add
   `open`, `identify`, `comment:created`. Fix the `.open` compile error in
   `FeedbackApp/.../AppConfiguration.swift` and `README.md` by introducing the
   real `open` event.
5. **OpenView**: constrain to `home` / `new-post`; update `HomeView.swift`'s
   `.changelog` open call (changelog is reached as a tab, not an open-view).
6. **Contract tests**: execute the bridge JS in JavaScriptCore to prove
   `window.__quackbackNative.dispatch` is defined and callable, and that built
   command strings parse to the expected `quackback:` shapes. Add a
   parse-roundtrip test per outbound message type using fixtures shaped like
   `types.ts`.
7. **CI**: GitHub Actions on a macOS runner running `swift test`,
   `swiftlint --strict`, and `xcodegen generate` + `xcodebuild` of the
   `FeedbackApp` target so app-target compile breaks are caught.

### M2 — Native value
Deliverable: the SDK is worth choosing over a raw WebView.

1. **Typed events**: each public event carries a decoded Swift struct — e.g.
   `vote(VoteEvent{ postId, voted, voteCount })`,
   `postCreated(PostCreatedEvent{ id, title, board, statusId })`,
   `commentCreated(...)`, `identify(IdentifyEvent{ success, user, anonymous, error })`,
   `navigate(URL)`. Decode centrally in the protocol layer.
2. **AsyncStream**: expose `OpenCovenFeedback.events` as an
   `AsyncStream<OpenCovenFeedbackEvent>` alongside the existing `on`/`off`
   callbacks.
3. **Identity hardening**:
   - Surface `identify-result` and `auth-change` so hosts learn who is signed in
     and why an identify failed.
   - Persist the widget session token; send it as `previousToken` on the next
     named identify to merge anonymous activity.
   - Consume `hmacRequired` from `config.json`: if a host calls unverified named
     identify while the server requires a token, emit a clear error event
     instead of silently failing.
4. **Config gating**: model the full `config.json`; expose `tabs` so hosts and
   the demo can avoid opening disabled surfaces; honor `imageUploadsInWidget`.

### M3 — Polish + release
Deliverable: a shippable 1.0.

1. **SwiftUI surface**: `.feedbackLauncher(config:)` modifier + `FeedbackButton`.
2. **WebView UX**: loading indicator, offline/load-failure state with retry,
   correct safe-area, accessibility (launcher label/traits, Dynamic Type).
3. **Image upload**: verify file-input → photo-picker works in `WKWebView` with
   the right Info.plist entitlements when `imageUploadsInWidget` is on.
4. **Cleanup**: collapse `Example/` and `FeedbackApp/` into one demo that
   doubles as the integration harness; fix the duplicate `AppConfiguration`
   (singleton vs `@StateObject`); correct the stray `quackback-android` README
   link.
5. **Docs + release**: update `README.md` to the corrected API surface; tag a
   1.0.0 SPM release.

## 7. Testing strategy

- **Protocol unit tests**: command builders produce exact `quackback:` strings;
  outbound parsers decode each message/event type from `types.ts`-shaped
  fixtures into typed values.
- **Contract/bridge tests (new)**: run the injected bridge script in
  JavaScriptCore; assert `window.__quackbackNative.dispatch` exists, is callable
  with `(type, msg)`, and routes to the handler. This is the test class that
  would have caught the invalid-JS and wrong-prefix bugs that string
  `contains()` checks missed.
- **Protocol snapshot**: a checked-in list of contract message/event names
  (mirroring `types.ts`) that tests assert against, so future web-contract drift
  surfaces as a test failure rather than silent breakage.
- **App-target build in CI**: `xcodegen` + `xcodebuild` so `.open`-style compile
  breaks in the host app cannot recur.
- **Identity precedence tests**: anonymous/named/clear/`previousToken` behavior
  mirrors the web `identify-precedence.ts` rules.

## 8. Risks & mitigations

- **Live-instance verification needs a running widget.** Mitigation: contract
  tests cover protocol correctness offline; manual verification against a
  self-hosted or `localhost:3000` instance gates M1 sign-off.
- **Contract drift.** The web protocol could change. Mitigation: the protocol
  snapshot test makes drift visible; the SDK pins to documented `quackback:`
  shapes and treats unknown events as ignorable.
- **JavaScriptCore vs WKWebView differences.** Contract tests prove the script
  parses and `dispatch` is callable, not full WebKit behavior. Mitigation: pair
  with a manual WKWebView smoke test in the demo harness during M1.
- **xcodegen/Xcode availability on CI runners.** Mitigation: pin runner image +
  install `xcodegen` in the workflow; the package layer still tests via
  `swift test` independently.

## 9. Open questions

- Distribution: SPM only for 1.0, or also CocoaPods? (Assumed SPM-only.)
- Minimum iOS: stay at 15.0? (Assumed yes.)
- Should the SDK expose `tabs`/`config.json` to hosts as public API, or consume
  it internally only? (Assumed internal for M2, can promote later.)

## 10. Definition of done

- `swift test` and the new contract tests pass; `swiftlint --strict` clean.
- CI builds the package and the app target on macOS and runs all tests.
- A manual smoke test against a live instance shows the launcher opening the
  widget, identify taking effect, and at least one typed event (e.g. `vote`)
  reaching the host.
- `README.md` matches the real API; a 1.0.0 tag is cut.
