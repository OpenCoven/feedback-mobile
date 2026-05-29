# Track 1 — Public End-User API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public `/api/public/v1/*` REST surface to `OpenCoven/feedback` — anonymous reads + end-user (better-auth bearer) writes — so a native app can browse boards/posts, vote, comment, submit, and read changelog + help, reusing existing domain services.

**Architecture:** New routes under `apps/web/src/routes/api/public/v1/`, structurally cloning the admin `/api/v1/*` routes but swapping `withApiKeyAuth` for a portal-session helper (`optionalPortalSession` / `requirePortalSession`) that reuses the existing bearer→session→principal lookup from `getWidgetSession`. Writes are attributed to the session's principal. One genuinely new service query (`listPublicPosts`) powers the anonymous feed; everything else calls existing services. A parallel OpenAPI document is published at `/api/public/v1/openapi.json`.

**Tech Stack:** TanStack Start (`createFileRoute` server handlers), Zod, better-auth (`bearer` plugin + `session` table), Drizzle, `zod-openapi`, Vitest.

**Repo:** This plan executes in `OpenCoven/feedback` (clone it; this is NOT the `feedback-mobile` repo). All paths below are relative to that repo root.

---

## File Structure

- Create `apps/web/src/lib/server/domains/api/portal-auth.ts` — `optionalPortalSession()` / `requirePortalSession()`. Owns end-user (portal) bearer auth for public routes. Wraps the existing session-by-token lookup.
- Create `apps/web/src/lib/server/domains/posts/post.public-list.ts` — `listPublicPosts(...)`, the anonymous-safe feed query (public boards, visible posts only). Kept separate from `post.inbox.ts` (admin) so admin/public visibility rules never tangle.
- Create read routes: `apps/web/src/routes/api/public/v1/{config,boards/index,posts/index,posts/$postId,posts/$postId.comments,changelog/index,changelog/$entryId,help/categories/index,help/articles/$slug,help/search}.ts`
- Create write routes: `apps/web/src/routes/api/public/v1/posts/$postId.vote.ts`, `apps/web/src/routes/api/public/v1/posts/$postId.comments.ts` (POST handler co-located with the GET in the same file), `posts/index.ts` (POST co-located with feed GET).
- Create `apps/web/src/routes/api/public/v1/openapi[.]json.ts` — serves the public spec.
- Create `apps/web/src/lib/server/domains/api/public-openapi.ts` — registers public paths, builds the public document (separate from the admin doc in `openapi.ts`).
- Tests co-located in `__tests__/` beside each route, mirroring `apps/web/src/routes/api/v1/posts/__tests__/index.test.ts`.

Each route file owns exactly one URL path; the auth helper and the feed query are the only shared new units.

---

## Task 1: Portal-session auth helper

**Files:**
- Create: `apps/web/src/lib/server/domains/api/portal-auth.ts`
- Test: `apps/web/src/lib/server/domains/api/__tests__/portal-auth.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const mockFindFirst = vi.fn()
vi.mock('@/lib/server/db', () => ({
  db: { query: { session: { findFirst: (...a: unknown[]) => mockFindFirst(...a) } } },
  session: { token: 'token', expiresAt: 'expiresAt' },
  principal: { userId: 'user_id' },
  eq: vi.fn(), and: vi.fn(), gt: vi.fn(),
}))

import { optionalPortalSession, requirePortalSession } from '../portal-auth'
import { UnauthorizedError } from '@/lib/shared/errors'

function req(auth?: string): Request {
  return new Request('http://t/x', { headers: auth ? { authorization: auth } : {} })
}

describe('portal-auth', () => {
  beforeEach(() => mockFindFirst.mockReset())

  it('returns null when no bearer token is present', async () => {
    expect(await optionalPortalSession(req())).toBeNull()
  })

  it('returns null when the session token is unknown/expired', async () => {
    mockFindFirst.mockResolvedValue(undefined)
    expect(await optionalPortalSession(req('Bearer nope'))).toBeNull()
  })

  it('returns the principal + user for a valid session', async () => {
    mockFindFirst.mockResolvedValue({
      userId: 'user_1',
      user: { id: 'user_1', name: 'Val', email: 'v@x.com', image: null },
      principal: { id: 'principal_1', role: 'user', type: 'user' },
    })
    const ctx = await optionalPortalSession(req('Bearer good'))
    expect(ctx?.principal.id).toBe('principal_1')
    expect(ctx?.user.email).toBe('v@x.com')
  })

  it('requirePortalSession throws UnauthorizedError when anonymous', async () => {
    await expect(requirePortalSession(req())).rejects.toBeInstanceOf(UnauthorizedError)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/lib/server/domains/api/__tests__/portal-auth.test.ts`
Expected: FAIL — `Cannot find module '../portal-auth'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/lib/server/domains/api/portal-auth.ts
import type { PrincipalId, UserId } from '@opencoven-feedback/ids'
import type { Role } from '@/lib/server/auth'
import { db, session, principal, eq, and, gt } from '@/lib/server/db'
import { UnauthorizedError } from '@/lib/shared/errors'

export interface PortalSession {
  user: { id: UserId; email: string; name: string; image: string | null }
  principal: { id: PrincipalId; role: Role; type: string }
}

function bearer(request: Request): string | null {
  const h = request.headers.get('authorization')
  if (!h?.startsWith('Bearer ')) return null
  const t = h.slice(7).trim()
  return t.length ? t : null
}

/** Resolve an end-user session from a bearer token, or null if absent/invalid. */
export async function optionalPortalSession(request: Request): Promise<PortalSession | null> {
  const token = bearer(request)
  if (!token) return null

  const row = await db.query.session.findFirst({
    where: and(eq(session.token, token), gt(session.expiresAt, new Date())),
    with: { user: true, principal: true },
  })
  if (!row?.user || !row.principal) return null

  return {
    user: {
      id: row.user.id as UserId,
      email: row.user.email!,
      name: row.user.name,
      image: row.user.image ?? null,
    },
    principal: {
      id: row.principal.id as PrincipalId,
      role: row.principal.role as Role,
      type: row.principal.type ?? 'user',
    },
  }
}

/** Like optionalPortalSession but throws UnauthorizedError when anonymous. */
export async function requirePortalSession(request: Request): Promise<PortalSession> {
  const s = await optionalPortalSession(request)
  if (!s) throw new UnauthorizedError('Sign in required. Provide Authorization: Bearer <session token>.')
  return s
}
```

> NOTE: `getWidgetSession` (`lib/server/functions/widget-auth.ts`) does the same token→session→principal lookup using `getRequestHeaders()` and lazily creates a missing principal. This helper takes the `request` directly (route handlers already have it) and assumes the `session.principal` relation exists. If the Drizzle `session` relation has no `principal`, mirror `getWidgetSession`'s principal-by-`userId` lookup (`db.query.principal.findFirst({ where: eq(principal.userId, userId) })`) plus its create-if-missing block instead of the `with: { principal: true }` include.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/lib/server/domains/api/__tests__/portal-auth.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/server/domains/api/portal-auth.ts apps/web/src/lib/server/domains/api/__tests__/portal-auth.test.ts
git commit -m "feat(public-api): portal-session bearer auth helper"
```

---

## Task 2: Public config endpoint (anonymous read)

**Files:**
- Create: `apps/web/src/routes/api/public/v1/config.ts`
- Test: `apps/web/src/routes/api/public/v1/__tests__/config.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'

const mockGetPublicWidgetConfig = vi.fn()
vi.mock('@tanstack/react-router', () => ({
  createFileRoute: vi.fn(() => (opts: unknown) => ({ options: opts })),
}))
vi.mock('@/lib/server/domains/settings/settings.widget', () => ({
  getPublicWidgetConfig: (...a: unknown[]) => mockGetPublicWidgetConfig(...a),
}))

import { Route } from '../config'
type Opts = { server: { handlers: { GET: () => Promise<Response> } } }
const GET = (Route as unknown as { options: Opts }).options.server.handlers.GET

describe('GET /api/public/v1/config', () => {
  it('returns the public config payload', async () => {
    mockGetPublicWidgetConfig.mockResolvedValue({ enabled: true, tabs: { feedback: true }, defaultBoard: 'b1' })
    const res = await GET()
    expect(res.status).toBe(200)
    const json = await res.json()
    expect(json.data.tabs.feedback).toBe(true)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/__tests__/config.test.ts`
Expected: FAIL — `Cannot find module '../config'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/routes/api/public/v1/config.ts
import { createFileRoute } from '@tanstack/react-router'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'

export const Route = createFileRoute('/api/public/v1/config')({
  server: {
    handlers: {
      GET: async () => {
        try {
          const { getPublicWidgetConfig } = await import('@/lib/server/domains/settings/settings.widget')
          const config = await getPublicWidgetConfig()
          return successResponse(config)
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/__tests__/config.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/config.ts apps/web/src/routes/api/public/v1/__tests__/config.test.ts
git commit -m "feat(public-api): GET /api/public/v1/config"
```

---

## Task 3: `listPublicPosts` feed query (the one new service)

**Files:**
- Create: `apps/web/src/lib/server/domains/posts/post.public-list.ts`
- Test: `apps/web/src/lib/server/domains/posts/__tests__/post.public-list.test.ts`

The admin feed uses `listInboxPosts` (`post.inbox.ts`), which includes deleted/private posts — wrong for anonymous users. Add a public-scoped list.

- [ ] **Step 1: Write the failing test**

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const mockFindMany = vi.fn()
vi.mock('@/lib/server/db', () => ({
  db: { query: { post: { findMany: (...a: unknown[]) => mockFindMany(...a) } } },
  post: {}, board: {}, eq: vi.fn(), and: vi.fn(), desc: vi.fn(), asc: vi.fn(), lt: vi.fn(),
}))

import { listPublicPosts } from '../post.public-list'

describe('listPublicPosts', () => {
  beforeEach(() => mockFindMany.mockReset())

  it('requests only public, non-deleted posts and maps the result', async () => {
    mockFindMany.mockResolvedValue([
      { id: 'post_1', title: 'A', voteCount: 5, deletedAt: null, board: { isPublic: true } },
    ])
    const result = await listPublicPosts({ limit: 20 })
    expect(result.items).toHaveLength(1)
    expect(result.items[0].id).toBe('post_1')
    expect(mockFindMany).toHaveBeenCalledTimes(1)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/lib/server/domains/posts/__tests__/post.public-list.test.ts`
Expected: FAIL — `Cannot find module '../post.public-list'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/lib/server/domains/posts/post.public-list.ts
import type { BoardId } from '@opencoven-feedback/ids'
import { db, post, board, and, eq, desc, lt } from '@/lib/server/db'

export interface PublicPostsParams {
  boardId?: BoardId
  sort?: 'newest' | 'votes'
  cursor?: string
  limit: number
}

export interface PublicPostSummary {
  id: string
  title: string
  voteCount: number
  statusId: string | null
  boardId: string
  createdAt: string
}

/** Lists posts visible to anonymous end users: public boards, not deleted. */
export async function listPublicPosts(
  params: PublicPostsParams
): Promise<{ items: PublicPostSummary[]; cursor: string | null; hasMore: boolean }> {
  const rows = await db.query.post.findMany({
    where: and(
      eq(post.deletedAt, null as unknown as Date),
      params.boardId ? eq(post.boardId, params.boardId) : undefined
    ),
    with: { board: true },
    orderBy: params.sort === 'votes' ? desc(post.voteCount) : desc(post.createdAt),
    limit: params.limit + 1,
  })

  const visible = rows.filter((r) => r.board?.isPublic)
  const page = visible.slice(0, params.limit)
  const hasMore = visible.length > params.limit

  return {
    items: page.map((r) => ({
      id: r.id,
      title: r.title,
      voteCount: r.voteCount,
      statusId: r.statusId ?? null,
      boardId: r.boardId,
      createdAt: r.createdAt.toISOString(),
    })),
    cursor: hasMore ? page[page.length - 1].id : null,
    hasMore,
  }
}
```

> NOTE: Match column names to the actual Drizzle `post` schema in `apps/web/src/lib/server/db/schema*`. If soft-delete is a boolean (`isDeleted`) rather than `deletedAt`, and/or cursor pagination uses a keyset on `createdAt`+`id`, adjust the `where`/`orderBy` to mirror `listInboxPosts` in `post.inbox.ts`. The contract (params in, `{items,cursor,hasMore}` out) stays fixed.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/lib/server/domains/posts/__tests__/post.public-list.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/server/domains/posts/post.public-list.ts apps/web/src/lib/server/domains/posts/__tests__/post.public-list.test.ts
git commit -m "feat(public-api): listPublicPosts feed query"
```

---

## Task 4: GET `/api/public/v1/posts` (feed) + GET `/boards`

**Files:**
- Create: `apps/web/src/routes/api/public/v1/posts/index.ts` (feed GET; POST added in Task 9)
- Create: `apps/web/src/routes/api/public/v1/boards/index.ts`
- Test: `apps/web/src/routes/api/public/v1/posts/__tests__/index.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'

const mockList = vi.fn()
const mockOptional = vi.fn()
const mockVoted = vi.fn()
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
vi.mock('@/lib/server/domains/posts/post.public-list', () => ({ listPublicPosts: (...a: unknown[]) => mockList(...a) }))
vi.mock('@/lib/server/domains/api/portal-auth', () => ({ optionalPortalSession: (...a: unknown[]) => mockOptional(...a) }))
vi.mock('@/lib/server/domains/posts/post.public', () => ({ getAllUserVotedPostIds: (...a: unknown[]) => mockVoted(...a) }))

import { Route } from '../index'
type Opts = { server: { handlers: { GET: (a: { request: Request }) => Promise<Response> } } }
const GET = (Route as unknown as { options: Opts }).options.server.handlers.GET

describe('GET /api/public/v1/posts', () => {
  it('returns a feed and marks hasVoted when authed', async () => {
    mockOptional.mockResolvedValue({ principal: { id: 'principal_1' } })
    mockVoted.mockResolvedValue(new Set(['post_1']))
    mockList.mockResolvedValue({ items: [{ id: 'post_1', title: 'A', voteCount: 2, statusId: null, boardId: 'b1', createdAt: '2026-01-01T00:00:00.000Z' }], cursor: null, hasMore: false })
    const res = await GET({ request: new Request('http://t/api/public/v1/posts?limit=20') })
    expect(res.status).toBe(200)
    const json = await res.json()
    expect(json.data[0].hasVoted).toBe(true)
    expect(json.meta.pagination.hasMore).toBe(false)
  })

  it('works anonymously (hasVoted false)', async () => {
    mockOptional.mockResolvedValue(null)
    mockList.mockResolvedValue({ items: [{ id: 'post_2', title: 'B', voteCount: 0, statusId: null, boardId: 'b1', createdAt: '2026-01-01T00:00:00.000Z' }], cursor: null, hasMore: false })
    const res = await GET({ request: new Request('http://t/api/public/v1/posts') })
    const json = await res.json()
    expect(json.data[0].hasVoted).toBe(false)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/index.test.ts`
Expected: FAIL — `Cannot find module '../index'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/routes/api/public/v1/posts/index.ts
import { createFileRoute } from '@tanstack/react-router'
import type { BoardId } from '@opencoven-feedback/ids'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'
import { optionalPortalSession } from '@/lib/server/domains/api/portal-auth'
import { listPublicPosts } from '@/lib/server/domains/posts/post.public-list'

export const Route = createFileRoute('/api/public/v1/posts/')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          const url = new URL(request.url)
          const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get('limit') ?? '20', 10) || 20))
          const sort = (url.searchParams.get('sort') as 'newest' | 'votes') ?? 'newest'
          const boardId = (url.searchParams.get('boardId') ?? undefined) as BoardId | undefined
          const cursor = url.searchParams.get('cursor') ?? undefined

          const result = await listPublicPosts({ boardId, sort, cursor, limit })

          const session = await optionalPortalSession(request)
          let voted = new Set<string>()
          if (session) {
            const { getAllUserVotedPostIds } = await import('@/lib/server/domains/posts/post.public')
            voted = await getAllUserVotedPostIds(session.principal.id)
          }

          return successResponse(
            result.items.map((p) => ({ ...p, hasVoted: voted.has(p.id) })),
            { pagination: { cursor: result.cursor, hasMore: result.hasMore } }
          )
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

```ts
// apps/web/src/routes/api/public/v1/boards/index.ts
import { createFileRoute } from '@tanstack/react-router'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'

export const Route = createFileRoute('/api/public/v1/boards/')({
  server: {
    handlers: {
      GET: async () => {
        try {
          const { listBoardsWithDetails } = await import('@/lib/server/domains/boards/board.service')
          const boards = await listBoardsWithDetails()
          return successResponse(
            boards
              .filter((b) => b.isPublic)
              .map((b) => ({ id: b.id, name: b.name, slug: b.slug, description: b.description, postCount: b.postCount }))
          )
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

> NOTE: Confirm `getAllUserVotedPostIds(principalId)` returns a `Set<string>` (it is used by `api/widget/identify.ts`); if it returns an array, wrap with `new Set(...)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/index.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/posts/index.ts apps/web/src/routes/api/public/v1/boards/index.ts apps/web/src/routes/api/public/v1/posts/__tests__/index.test.ts
git commit -m "feat(public-api): GET posts feed + boards"
```

---

## Task 5: GET `/posts/:id` and GET `/posts/:id/comments`

**Files:**
- Create: `apps/web/src/routes/api/public/v1/posts/$postId.ts`
- Create: `apps/web/src/routes/api/public/v1/posts/$postId.comments.ts` (GET; POST added in Task 11)
- Test: `apps/web/src/routes/api/public/v1/posts/__tests__/detail.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'

const mockGetPost = vi.fn()
const mockOptional = vi.fn()
const mockVoted = vi.fn()
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
vi.mock('@/lib/server/domains/posts/post.query', () => ({ getPostWithDetails: (...a: unknown[]) => mockGetPost(...a) }))
vi.mock('@/lib/server/domains/api/portal-auth', () => ({ optionalPortalSession: (...a: unknown[]) => mockOptional(...a) }))
vi.mock('@/lib/server/domains/posts/post.public', () => ({ getAllUserVotedPostIds: (...a: unknown[]) => mockVoted(...a) }))
vi.mock('@/lib/server/domains/api/validation', () => ({ parseTypeId: (v: string) => v }))

import { Route } from '../$postId'
type Opts = { server: { handlers: { GET: (a: { request: Request; params: { postId: string } }) => Promise<Response> } } }
const GET = (Route as unknown as { options: Opts }).options.server.handlers.GET

describe('GET /api/public/v1/posts/:id', () => {
  it('returns the post', async () => {
    mockOptional.mockResolvedValue(null)
    mockGetPost.mockResolvedValue({ id: 'post_1', title: 'A', content: 'x', voteCount: 3, statusId: null, boardId: 'b1', createdAt: new Date('2026-01-01') })
    const res = await GET({ request: new Request('http://t/api/public/v1/posts/post_1'), params: { postId: 'post_1' } })
    expect(res.status).toBe(200)
    expect((await res.json()).data.id).toBe('post_1')
  })

  it('404s when missing', async () => {
    mockOptional.mockResolvedValue(null)
    mockGetPost.mockResolvedValue(null)
    const res = await GET({ request: new Request('http://t/x'), params: { postId: 'post_x' } })
    expect(res.status).toBe(404)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/detail.test.ts`
Expected: FAIL — `Cannot find module '../$postId'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/routes/api/public/v1/posts/$postId.ts
import { createFileRoute } from '@tanstack/react-router'
import type { PostId } from '@opencoven-feedback/ids'
import { successResponse, notFoundResponse, handleDomainError } from '@/lib/server/domains/api/responses'
import { parseTypeId } from '@/lib/server/domains/api/validation'
import { optionalPortalSession } from '@/lib/server/domains/api/portal-auth'

export const Route = createFileRoute('/api/public/v1/posts/$postId')({
  server: {
    handlers: {
      GET: async ({ request, params }) => {
        try {
          const postId = parseTypeId<PostId>(params.postId, 'post', 'post ID')
          const { getPostWithDetails } = await import('@/lib/server/domains/posts/post.query')
          const post = await getPostWithDetails(postId)
          if (!post) return notFoundResponse('Post not found')

          const session = await optionalPortalSession(request)
          let hasVoted = false
          if (session) {
            const { getAllUserVotedPostIds } = await import('@/lib/server/domains/posts/post.public')
            hasVoted = (await getAllUserVotedPostIds(session.principal.id)).has(post.id)
          }

          return successResponse({
            id: post.id, title: post.title, content: post.content,
            voteCount: post.voteCount, statusId: post.statusId ?? null,
            boardId: post.boardId, createdAt: post.createdAt.toISOString(), hasVoted,
          })
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

```ts
// apps/web/src/routes/api/public/v1/posts/$postId.comments.ts
import { createFileRoute } from '@tanstack/react-router'
import type { PostId } from '@opencoven-feedback/ids'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'
import { parseTypeId } from '@/lib/server/domains/api/validation'

export const Route = createFileRoute('/api/public/v1/posts/$postId/comments')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        try {
          const postId = parseTypeId<PostId>(params.postId, 'post', 'post ID')
          const { getCommentsWithReplies } = await import('@/lib/server/domains/posts/post.query')
          const comments = await getCommentsWithReplies(postId)
          const serialize = (c: { id: string; content: string; authorName: string; createdAt: Date; replies: unknown[] }): unknown => ({
            id: c.id, content: c.content, authorName: c.authorName,
            createdAt: c.createdAt.toISOString(),
            replies: (c.replies as typeof comments).map(serialize),
          })
          return successResponse(comments.map(serialize))
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

> NOTE: `notFoundResponse` is exported from `responses.ts` (the admin routes use `NotFoundError` + `handleDomainError`; either is fine — if `notFoundResponse` doesn't exist, `throw new NotFoundError('Post not found')` and let `handleDomainError` map it to 404). Mirror the comment field names from `apps/web/src/routes/api/v1/posts/$postId.comments.ts`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/detail.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/posts/\$postId.ts apps/web/src/routes/api/public/v1/posts/\$postId.comments.ts apps/web/src/routes/api/public/v1/posts/__tests__/detail.test.ts
git commit -m "feat(public-api): GET post detail + comments"
```

---

## Task 6: GET changelog (list + entry)

**Files:**
- Create: `apps/web/src/routes/api/public/v1/changelog/index.ts`, `apps/web/src/routes/api/public/v1/changelog/$entryId.ts`
- Test: `apps/web/src/routes/api/public/v1/changelog/__tests__/index.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'
const mockList = vi.fn()
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
vi.mock('@/lib/server/domains/changelog/changelog.query', () => ({ listChangelogs: (...a: unknown[]) => mockList(...a) }))
import { Route } from '../index'
type Opts = { server: { handlers: { GET: (a: { request: Request }) => Promise<Response> } } }
const GET = (Route as unknown as { options: Opts }).options.server.handlers.GET

describe('GET /api/public/v1/changelog', () => {
  it('lists only published entries', async () => {
    mockList.mockResolvedValue({ items: [{ id: 'cl_1', title: 'v1', publishedAt: new Date('2026-01-01') }], cursor: null, hasMore: false })
    const res = await GET({ request: new Request('http://t/api/public/v1/changelog') })
    expect(res.status).toBe(200)
    expect(mockList).toHaveBeenCalledWith(expect.objectContaining({ status: 'published' }))
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/changelog/__tests__/index.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/routes/api/public/v1/changelog/index.ts
import { createFileRoute } from '@tanstack/react-router'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'
import { listChangelogs } from '@/lib/server/domains/changelog/changelog.query'

export const Route = createFileRoute('/api/public/v1/changelog/')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          const url = new URL(request.url)
          const cursor = url.searchParams.get('cursor') ?? undefined
          const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get('limit') ?? '20', 10) || 20))
          // Anonymous users only ever see published entries.
          const result = await listChangelogs({ status: 'published', cursor, limit })
          return successResponse(
            result.items.map((e) => ({ id: e.id, title: e.title, publishedAt: e.publishedAt?.toISOString() ?? null })),
            { pagination: { cursor: result.cursor, hasMore: result.hasMore } }
          )
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

```ts
// apps/web/src/routes/api/public/v1/changelog/$entryId.ts
import { createFileRoute } from '@tanstack/react-router'
import { successResponse, notFoundResponse, handleDomainError } from '@/lib/server/domains/api/responses'

export const Route = createFileRoute('/api/public/v1/changelog/$entryId')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        try {
          const { getChangelog } = await import('@/lib/server/domains/changelog/changelog.query')
          const entry = await getChangelog(params.entryId)
          if (!entry || entry.status !== 'published') return notFoundResponse('Changelog entry not found')
          return successResponse({ id: entry.id, title: entry.title, content: entry.content, publishedAt: entry.publishedAt?.toISOString() ?? null })
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

> NOTE: Confirm `getChangelog` exists in `changelog.query.ts` (the admin `$entryId.ts` route imports the single-entry getter — use that exact name). Match `listChangelogs`'s param shape (`{ status, cursor, limit }`) — verified from `api/v1/changelog/index.ts`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/changelog/__tests__/index.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/changelog/ && git commit -m "feat(public-api): GET changelog list + entry"
```

---

## Task 7: GET help-center (categories, article, search)

**Files:**
- Create: `apps/web/src/routes/api/public/v1/help/categories/index.ts`, `apps/web/src/routes/api/public/v1/help/articles/$slug.ts`, `apps/web/src/routes/api/public/v1/help/search.ts`
- Test: `apps/web/src/routes/api/public/v1/help/__tests__/help.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'
const mockCats = vi.fn()
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
vi.mock('@/lib/server/domains/help-center/help-center.service', () => ({
  listCategories: (...a: unknown[]) => mockCats(...a),
  listArticles: vi.fn(), getArticleBySlug: vi.fn(),
}))
import { Route } from '../categories/index'
type Opts = { server: { handlers: { GET: () => Promise<Response> } } }
const GET = (Route as unknown as { options: Opts }).options.server.handlers.GET

describe('GET /api/public/v1/help/categories', () => {
  it('returns categories', async () => {
    mockCats.mockResolvedValue([{ id: 'cat_1', name: 'Getting Started', slug: 'getting-started' }])
    const res = await GET()
    expect(res.status).toBe(200)
    expect((await res.json()).data[0].slug).toBe('getting-started')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/help/__tests__/help.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/routes/api/public/v1/help/categories/index.ts
import { createFileRoute } from '@tanstack/react-router'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'
import { listCategories } from '@/lib/server/domains/help-center/help-center.service'

export const Route = createFileRoute('/api/public/v1/help/categories/')({
  server: {
    handlers: {
      GET: async () => {
        try {
          const cats = await listCategories()
          return successResponse(cats.map((c) => ({ id: c.id, name: c.name, slug: c.slug, description: c.description ?? null })))
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

```ts
// apps/web/src/routes/api/public/v1/help/articles/$slug.ts
import { createFileRoute } from '@tanstack/react-router'
import { successResponse, notFoundResponse, handleDomainError } from '@/lib/server/domains/api/responses'
import { getArticleBySlug } from '@/lib/server/domains/help-center/help-center.service'

export const Route = createFileRoute('/api/public/v1/help/articles/$slug')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        try {
          const article = await getArticleBySlug(params.slug)
          if (!article || article.status !== 'published') return notFoundResponse('Article not found')
          return successResponse({ id: article.id, slug: article.slug, title: article.title, content: article.content, categoryId: article.categoryId })
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

```ts
// apps/web/src/routes/api/public/v1/help/search.ts
import { createFileRoute } from '@tanstack/react-router'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'

export const Route = createFileRoute('/api/public/v1/help/search')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          const q = new URL(request.url).searchParams.get('q')?.trim() ?? ''
          if (!q) return successResponse([])
          const { searchKnowledgeBase } = await import('@/lib/server/domains/help-center/help-center.service')
          const results = await searchKnowledgeBase(q)
          return successResponse(results.map((r) => ({ id: r.id, slug: r.slug, title: r.title })))
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

> NOTE: `listCategories`/`listArticles` are confirmed in `help-center.service.ts`. For the single-article getter and search, use the exact names that file exports (the existing `api/widget/kb-search.ts` route already performs widget KB search — reuse the same service function it calls instead of `searchKnowledgeBase` if the name differs). Filter to `status === 'published'` for anonymous access.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/help/__tests__/help.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/help/ && git commit -m "feat(public-api): GET help categories, article, search"
```

---

## Task 8: POST `/posts` (submit) — auth required

**Files:**
- Modify: `apps/web/src/routes/api/public/v1/posts/index.ts` (add POST handler)
- Test: `apps/web/src/routes/api/public/v1/posts/__tests__/submit.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'
const mockRequire = vi.fn()
const mockCreate = vi.fn()
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
vi.mock('@/lib/server/domains/posts/post.public-list', () => ({ listPublicPosts: vi.fn() }))
vi.mock('@/lib/server/domains/api/portal-auth', () => ({
  optionalPortalSession: vi.fn(), requirePortalSession: (...a: unknown[]) => mockRequire(...a),
}))
vi.mock('@/lib/server/domains/posts/post.service', () => ({ createPost: (...a: unknown[]) => mockCreate(...a) }))
import { Route } from '../index'
import { UnauthorizedError } from '@/lib/shared/errors'
type Opts = { server: { handlers: { POST: (a: { request: Request }) => Promise<Response> } } }
const POST = (Route as unknown as { options: Opts }).options.server.handlers.POST
const body = (b: unknown) => new Request('http://t/api/public/v1/posts', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(b) })

describe('POST /api/public/v1/posts', () => {
  it('401s when anonymous', async () => {
    mockRequire.mockRejectedValue(new UnauthorizedError('Sign in required'))
    const res = await POST({ request: body({ boardId: 'b1', title: 'Hi' }) })
    expect(res.status).toBe(401)
  })
  it('creates a post attributed to the session principal', async () => {
    mockRequire.mockResolvedValue({ principal: { id: 'principal_1' } })
    mockCreate.mockResolvedValue({ id: 'post_new', title: 'Hi', boardId: 'b1', createdAt: new Date('2026-01-01') })
    const res = await POST({ request: body({ boardId: 'b1', title: 'Hi', content: 'x' }) })
    expect(res.status).toBe(201)
    expect(mockCreate).toHaveBeenCalledWith(expect.objectContaining({ authorPrincipalId: 'principal_1' }))
  })
  it('400s on invalid body', async () => {
    mockRequire.mockResolvedValue({ principal: { id: 'principal_1' } })
    const res = await POST({ request: body({ title: '' }) })
    expect(res.status).toBe(400)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/submit.test.ts`
Expected: FAIL — `POST is not a function`.

- [ ] **Step 3: Add the POST handler** (in `posts/index.ts`, alongside GET)

Add these imports at the top:

```ts
import { z } from 'zod'
import { createdResponse, badRequestResponse } from '@/lib/server/domains/api/responses'
import { requirePortalSession } from '@/lib/server/domains/api/portal-auth'

const submitSchema = z.object({
  boardId: z.string().min(1, 'Board ID is required'),
  title: z.string().min(1, 'Title is required').max(200),
  content: z.string().max(10000).optional().default(''),
})
```

Add the `POST` handler inside `handlers`:

```ts
POST: async ({ request }) => {
  try {
    const session = await requirePortalSession(request)
    const body = await request.json().catch(() => null)
    const parsed = submitSchema.safeParse(body)
    if (!parsed.success) {
      return badRequestResponse('Invalid request body', { errors: parsed.error.flatten().fieldErrors })
    }
    const { createPost } = await import('@/lib/server/domains/posts/post.service')
    const post = await createPost({
      boardId: parsed.data.boardId,
      title: parsed.data.title,
      content: parsed.data.content,
      authorPrincipalId: session.principal.id,
    })
    return createdResponse({ id: post.id, title: post.title, boardId: post.boardId, createdAt: post.createdAt.toISOString() })
  } catch (error) {
    return handleDomainError(error)
  }
},
```

> NOTE: Match `createPost`'s argument shape to `post.service.ts` (the admin `POST /api/v1/posts` calls `createPost(...)` then resolves the author principal — mirror exactly how it passes the author). `handleDomainError` must map `UnauthorizedError`→401, `ValidationError`→400; confirm in `responses.ts` (the admin routes rely on this).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/submit.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/posts/index.ts apps/web/src/routes/api/public/v1/posts/__tests__/submit.test.ts
git commit -m "feat(public-api): POST submit post (auth required)"
```

---

## Task 9: POST `/posts/:id/vote` (toggle) — auth required

**Files:**
- Create: `apps/web/src/routes/api/public/v1/posts/$postId.vote.ts`
- Test: `apps/web/src/routes/api/public/v1/posts/__tests__/vote.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'
const mockRequire = vi.fn()
const mockVote = vi.fn()
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
vi.mock('@/lib/server/domains/api/portal-auth', () => ({ requirePortalSession: (...a: unknown[]) => mockRequire(...a) }))
vi.mock('@/lib/server/domains/posts/post.voting', () => ({ voteOnPost: (...a: unknown[]) => mockVote(...a) }))
vi.mock('@/lib/server/domains/api/validation', () => ({ parseTypeId: (v: string) => v }))
import { Route } from '../$postId.vote'
type Opts = { server: { handlers: { POST: (a: { request: Request; params: { postId: string } }) => Promise<Response> } } }
const POST = (Route as unknown as { options: Opts }).options.server.handlers.POST

describe('POST /api/public/v1/posts/:id/vote', () => {
  it('toggles the vote for the session principal', async () => {
    mockRequire.mockResolvedValue({ principal: { id: 'principal_1' } })
    mockVote.mockResolvedValue({ voted: true, voteCount: 6 })
    const res = await POST({ request: new Request('http://t/x', { method: 'POST' }), params: { postId: 'post_1' } })
    expect(res.status).toBe(200)
    const json = await res.json()
    expect(json.data).toEqual({ voted: true, voteCount: 6 })
    expect(mockVote).toHaveBeenCalledWith('post_1', 'principal_1')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/vote.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/routes/api/public/v1/posts/$postId.vote.ts
import { createFileRoute } from '@tanstack/react-router'
import type { PostId } from '@opencoven-feedback/ids'
import { successResponse, handleDomainError } from '@/lib/server/domains/api/responses'
import { parseTypeId } from '@/lib/server/domains/api/validation'
import { requirePortalSession } from '@/lib/server/domains/api/portal-auth'
import { voteOnPost } from '@/lib/server/domains/posts/post.voting'

export const Route = createFileRoute('/api/public/v1/posts/$postId/vote')({
  server: {
    handlers: {
      POST: async ({ request, params }) => {
        try {
          const session = await requirePortalSession(request)
          const postId = parseTypeId<PostId>(params.postId, 'post', 'post ID')
          const result = await voteOnPost(postId, session.principal.id)
          return successResponse({ voted: result.voted, voteCount: result.voteCount })
        } catch (error) {
          return handleDomainError(error)
        }
      },
    },
  },
})
```

> NOTE: Confirm `voteOnPost`'s signature in `post.voting.ts` (the admin `$postId.vote.ts` calls `voteOnPost(...)`). Match its argument order and the shape of its return (`{ voted, voteCount }`); adjust the response mapping if the property names differ.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/vote.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/posts/\$postId.vote.ts apps/web/src/routes/api/public/v1/posts/__tests__/vote.test.ts
git commit -m "feat(public-api): POST toggle vote (auth required)"
```

---

## Task 10: POST `/posts/:id/comments` — auth required

**Files:**
- Modify: `apps/web/src/routes/api/public/v1/posts/$postId.comments.ts` (add POST)
- Test: `apps/web/src/routes/api/public/v1/posts/__tests__/comment-create.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'
const mockRequire = vi.fn()
const mockCreate = vi.fn()
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
vi.mock('@/lib/server/domains/posts/post.query', () => ({ getCommentsWithReplies: vi.fn() }))
vi.mock('@/lib/server/domains/api/portal-auth', () => ({ requirePortalSession: (...a: unknown[]) => mockRequire(...a) }))
vi.mock('@/lib/server/domains/api/validation', () => ({ parseTypeId: (v: string) => v }))
vi.mock('@/lib/server/domains/posts/post.comment', () => ({ createComment: (...a: unknown[]) => mockCreate(...a) }))
import { Route } from '../$postId.comments'
type Opts = { server: { handlers: { POST: (a: { request: Request; params: { postId: string } }) => Promise<Response> } } }
const POST = (Route as unknown as { options: Opts }).options.server.handlers.POST
const body = (b: unknown) => new Request('http://t/x', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(b) })

describe('POST /api/public/v1/posts/:id/comments', () => {
  it('creates a comment as the session principal', async () => {
    mockRequire.mockResolvedValue({ principal: { id: 'principal_1' } })
    mockCreate.mockResolvedValue({ id: 'comment_1', content: 'nice', createdAt: new Date('2026-01-01') })
    const res = await POST({ request: body({ content: 'nice' }), params: { postId: 'post_1' } })
    expect(res.status).toBe(201)
    expect(mockCreate).toHaveBeenCalledWith(expect.objectContaining({ authorPrincipalId: 'principal_1', content: 'nice' }))
  })
  it('400s on empty content', async () => {
    mockRequire.mockResolvedValue({ principal: { id: 'principal_1' } })
    const res = await POST({ request: body({ content: '' }), params: { postId: 'post_1' } })
    expect(res.status).toBe(400)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/comment-create.test.ts`
Expected: FAIL — `POST is not a function`.

- [ ] **Step 3: Add the POST handler** (in `$postId.comments.ts`)

Add imports:

```ts
import { z } from 'zod'
import { createdResponse, badRequestResponse } from '@/lib/server/domains/api/responses'
import { requirePortalSession } from '@/lib/server/domains/api/portal-auth'

const commentSchema = z.object({
  content: z.string().min(1, 'Content is required').max(10000),
  parentId: z.string().optional(),
})
```

Add the handler:

```ts
POST: async ({ request, params }) => {
  try {
    const session = await requirePortalSession(request)
    const postId = parseTypeId<PostId>(params.postId, 'post', 'post ID')
    const parsed = commentSchema.safeParse(await request.json().catch(() => null))
    if (!parsed.success) {
      return badRequestResponse('Invalid request body', { errors: parsed.error.flatten().fieldErrors })
    }
    const { createComment } = await import('@/lib/server/domains/posts/post.comment')
    const comment = await createComment({
      postId,
      content: parsed.data.content,
      parentId: parsed.data.parentId,
      authorPrincipalId: session.principal.id,
    })
    return createdResponse({ id: comment.id, content: comment.content, createdAt: comment.createdAt.toISOString() })
  } catch (error) {
    return handleDomainError(error)
  }
},
```

> NOTE: Find the comment-creation service used by the admin `POST /api/v1/posts/$postId/comments` (`apps/web/src/routes/api/v1/posts/$postId.comments.ts`) and import that exact function/module path here (the example assumes `createComment` in `post.comment`). Match its argument shape.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/posts/__tests__/comment-create.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/api/public/v1/posts/\$postId.comments.ts apps/web/src/routes/api/public/v1/posts/__tests__/comment-create.test.ts
git commit -m "feat(public-api): POST create comment (auth required)"
```

---

## Task 11: Public OpenAPI document

**Files:**
- Create: `apps/web/src/lib/server/domains/api/public-openapi.ts`
- Create: `apps/web/src/routes/api/public/v1/openapi[.]json.ts`
- Test: `apps/web/src/routes/api/public/v1/__tests__/openapi.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'
vi.mock('@tanstack/react-router', () => ({ createFileRoute: vi.fn(() => (o: unknown) => ({ options: o })) }))
import { Route } from '../openapi[.]json'
type Opts = { server: { handlers: { GET: () => Promise<Response> } } }
const GET = (Route as unknown as { options: Opts }).options.server.handlers.GET

describe('GET /api/public/v1/openapi.json', () => {
  it('serves an OpenAPI 3.x document covering public paths', async () => {
    const res = await GET()
    expect(res.status).toBe(200)
    const doc = await res.json()
    expect(doc.openapi).toMatch(/^3\./)
    expect(Object.keys(doc.paths)).toContain('/api/public/v1/posts')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/__tests__/openapi.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/web/src/lib/server/domains/api/public-openapi.ts
import 'zod-openapi'
import { createDocument } from 'zod-openapi'
import { z } from 'zod'

/** Builds the public end-user API document. Mirror the descriptor style in openapi.ts. */
export function buildPublicOpenApiDocument(baseUrl: string) {
  return createDocument({
    openapi: '3.1.0',
    info: { title: 'OpenCoven Feedback — Public API', version: '1.0.0' },
    servers: [{ url: baseUrl }],
    paths: {
      '/api/public/v1/config': { get: { summary: 'Public widget/portal config', responses: { 200: { description: 'OK' } } } },
      '/api/public/v1/boards': { get: { summary: 'List public boards', responses: { 200: { description: 'OK' } } } },
      '/api/public/v1/posts': {
        get: { summary: 'List feed posts', responses: { 200: { description: 'OK' } } },
        post: { summary: 'Submit a post (auth)', responses: { 201: { description: 'Created' }, 401: { description: 'Unauthorized' } } },
      },
      '/api/public/v1/posts/{postId}': { get: { summary: 'Get post detail', responses: { 200: { description: 'OK' }, 404: { description: 'Not found' } } } },
      '/api/public/v1/posts/{postId}/comments': {
        get: { summary: 'List comments', responses: { 200: { description: 'OK' } } },
        post: { summary: 'Add comment (auth)', responses: { 201: { description: 'Created' }, 401: { description: 'Unauthorized' } } },
      },
      '/api/public/v1/posts/{postId}/vote': { post: { summary: 'Toggle vote (auth)', responses: { 200: { description: 'OK' }, 401: { description: 'Unauthorized' } } } },
      '/api/public/v1/changelog': { get: { summary: 'List changelog', responses: { 200: { description: 'OK' } } } },
      '/api/public/v1/changelog/{entryId}': { get: { summary: 'Get changelog entry', responses: { 200: { description: 'OK' }, 404: { description: 'Not found' } } } },
      '/api/public/v1/help/categories': { get: { summary: 'List help categories', responses: { 200: { description: 'OK' } } } },
      '/api/public/v1/help/articles/{slug}': { get: { summary: 'Get help article', responses: { 200: { description: 'OK' }, 404: { description: 'Not found' } } } },
      '/api/public/v1/help/search': { get: { summary: 'Search help', responses: { 200: { description: 'OK' } } } },
    },
    components: {
      securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', description: 'better-auth session token' } },
    },
  })
  void z
}
```

```ts
// apps/web/src/routes/api/public/v1/openapi[.]json.ts
import { createFileRoute } from '@tanstack/react-router'
import { config } from '@/lib/server/config'
import { buildPublicOpenApiDocument } from '@/lib/server/domains/api/public-openapi'

export const Route = createFileRoute('/api/public/v1/openapi.json')({
  server: {
    handlers: {
      GET: async () => {
        const doc = buildPublicOpenApiDocument(config.baseUrl)
        return new Response(JSON.stringify(doc), {
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Cache-Control': 'public, max-age=3600' },
        })
      },
    },
  },
})
```

> NOTE: For a richer spec, attach the Zod response schemas via `.meta()` and `registerPath` exactly as `openapi.ts` does for the admin API. The minimal document above is enough to drive `swift-openapi-generator` in Track 2; enrich incrementally.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && pnpm vitest run src/routes/api/public/v1/__tests__/openapi.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/server/domains/api/public-openapi.ts apps/web/src/routes/api/public/v1/openapi\[.\]json.ts apps/web/src/routes/api/public/v1/__tests__/openapi.test.ts
git commit -m "feat(public-api): publish /api/public/v1/openapi.json"
```

---

## Task 12: Full suite + lint gate

- [ ] **Step 1: Run the public-API test suite**

Run: `cd apps/web && pnpm vitest run src/routes/api/public src/lib/server/domains/api/__tests__/portal-auth.test.ts src/lib/server/domains/posts/__tests__/post.public-list.test.ts`
Expected: all PASS.

- [ ] **Step 2: Typecheck + lint (match the repo's scripts)**

Run: `cd apps/web && pnpm typecheck && pnpm lint` (use the script names in `apps/web/package.json`; commonly `typecheck`/`lint`)
Expected: no errors.

- [ ] **Step 3: Open the PR**

```bash
git push -u origin feat/public-end-user-api
gh pr create --repo OpenCoven/feedback --base main \
  --title "feat: public end-user API (/api/public/v1)" \
  --body "Adds anonymous reads + better-auth bearer writes for native/portal end-user clients, reusing existing domain services. No new business logic or migrations. Backs the native iOS app."
```

---

## Self-Review

- **Spec coverage** (§4 of the design): config ✅ T2 · boards ✅ T4 · posts feed ✅ T3+T4 · post detail ✅ T5 · comments read ✅ T5 · changelog ✅ T6 · help ✅ T7 · submit ✅ T8 · vote ✅ T9 · comment create ✅ T10 · OpenAPI ✅ T11 · bearer auth (anon reads / session writes) ✅ T1. Rate-limiting is reused from existing middleware; if public routes need their own limiter, add `checkRateLimit(getClientIp(request))` (from `domains/api/rate-limit.ts`) at the top of each write handler — noted here so it isn't missed.
- **Placeholder scan:** No "TBD"/"handle later". The `> NOTE:` blocks are concrete "verify this exact name in file X / mirror route Y" instructions, not vague placeholders — they exist because exact service signatures must be confirmed against the live repo at execution time.
- **Type consistency:** `PortalSession.principal.id` (T1) is the principal passed to `createPost`/`voteOnPost`/`createComment` (T8/T9/T10) and `getAllUserVotedPostIds` (T4/T5). `listPublicPosts` returns `{items,cursor,hasMore}` (T3) consumed identically in T4.
