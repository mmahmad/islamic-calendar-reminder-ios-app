# Authority Platform Re-Plan (Backend)

Date: February 13, 2026

## Goal
Build a general Authority Platform where:
- authority representatives publish calendar data,
- users subscribe to one authority for their active calendar,
- users can browse other authority calendars without switching.

## Product Rules
1. One representative per authority in v1 (can expand later).
2. Authorities can publish either:
   - full-year month starts, or
   - moonsighting updates for current/next month boundaries.
3. A user can subscribe to exactly one active authority at a time.
4. Browsing and subscribing are separate actions.
5. If subscribed authority has unknown future month boundaries, fallback to calculated calendar for unknown months.

## Core Domain Model (Convex)

### `authorities`
- `slug: string` (unique, public identifier)
- `name: string`
- `regionCode: string` (country/region code)
- `methodology: "moonsighting" | "calculated" | "hybrid"`
- `websiteUrl?: string`
- `isActive: boolean`
- `createdAt: number`
- `updatedAt: number`

Indexes:
- `by_slug` (unique)
- `by_region`

### `authority_representatives`
- `authorityId: Id<"authorities">`
- `userId: Id<"users">`
- `role: "representative" | "admin"`
- `status: "active" | "revoked"`
- `createdAt: number`
- `updatedAt: number`

Invariants:
- v1: max one `active` representative with role `representative` per authority.

Indexes:
- `by_authority_status`
- `by_user_status`

### `authority_publications`
Tracks publish events for auditability.

- `authorityId: Id<"authorities">`
- `type: "full_year" | "moonsighting_update"`
- `title?: string`
- `notes?: string`
- `publishedBy: Id<"users">`
- `publishedAt: number`
- `effectiveFromHijriYear?: number`
- `effectiveFromHijriMonth?: number`

Indexes:
- `by_authority_publishedAt`

### `authority_month_starts`
Canonical month-start records consumed by client feeds.

- `authorityId: Id<"authorities">`
- `hijriYear: number`
- `hijriMonth: number` (1..12)
- `gregorianStartDate: string` (`YYYY-MM-DD`)
- `status: "confirmed" | "projected"`
- `sourceType: "full_year" | "moonsighting_update" | "manual_admin"`
- `publicationId?: Id<"authority_publications">`
- `updatedBy: Id<"users">`
- `updatedAt: number`

Invariants:
- unique month row per `(authorityId, hijriYear, hijriMonth)`.

Indexes:
- `by_authority_year_month` (unique)
- `by_authority_updatedAt`

### `user_authority_subscriptions`
- `userId: Id<"users">`
- `authorityId: Id<"authorities">`
- `status: "active" | "inactive"`
- `subscribedAt: number`
- `updatedAt: number`

Invariants:
- at most one `active` subscription per user.

Indexes:
- `by_user_status`
- `by_authority_status`

## API Contract

## Public APIs (no auth required)

### `GET /authorities`
List available authorities for browse/subscribe UI.

Response:
```json
{
  "authorities": [
    {
      "slug": "chc",
      "name": "Central Hilal Committee",
      "regionCode": "US",
      "methodology": "moonsighting",
      "isActive": true,
      "updatedAt": 1739480000000
    }
  ]
}
```

### `GET /authority/{slug}`
Public feed consumed by iOS for that authority.

Response:
```json
{
  "authority": {
    "slug": "chc",
    "name": "Central Hilal Committee",
    "regionCode": "US",
    "methodology": "moonsighting",
    "updatedAt": 1739480000000
  },
  "months": [
    {
      "hijriYear": 1447,
      "hijriMonth": 8,
      "gregorianStartDate": "2026-01-20",
      "status": "confirmed",
      "updatedAt": 1739479900000
    }
  ]
}
```

### `GET /authority/{slug}/preview?from=YYYY-MM-DD&to=YYYY-MM-DD`
Optional endpoint for compare mode. Returns effective merged calendar for that authority (authority-confirmed months + calculated fallback for unknown months).

## Authenticated User APIs

### `GET /me/subscription`
Returns active subscription if present.

### `PUT /me/subscription`
Set or replace active subscription.

Request:
```json
{
  "authoritySlug": "chc"
}
```

### `DELETE /me/subscription`
Clear active subscription (fallback to calculated-only mode).

## Representative Console APIs

### `POST /authority/{slug}/publish/full-year`
Bulk upsert year data.

Request:
```json
{
  "hijriYear": 1448,
  "months": [
    {"hijriMonth": 1, "gregorianStartDate": "2026-06-16", "status": "projected"}
  ],
  "notes": "Annual projection"
}
```

### `POST /authority/{slug}/publish/moonsighting`
Publish a moonsighting update (usually current month end / next month start confirmation).

Request:
```json
{
  "updates": [
    {"hijriYear": 1447, "hijriMonth": 9, "gregorianStartDate": "2026-02-18", "status": "confirmed"}
  ],
  "notes": "Ramadan confirmed"
}
```

### `DELETE /authority/{slug}/month-start?hijriYear=...&hijriMonth=...`
Remove incorrect month start (admin/rep with audit event).

## Authorization Rules
- Public users: read authority list/feed.
- Authenticated users: manage own subscription.
- Representative: publish only for their authority.
- Admin: create authority, assign representative, approve users, override any month start.

## Effective Calendar Resolution (Server + iOS)
Given an authority feed and calculated baseline:
1. Start with calculated month definitions.
2. Overlay authority month starts where available.
3. Keep authority month starts as source of truth for known months.
4. For unknown months, retain calculated dates.
5. Derive month length from next known month start when possible; otherwise use baseline month length.

This preserves the required moonsighting behavior: confirmed boundaries override baseline, future uncertainty stays calculated.

## iOS Integration Changes
1. Replace `authorityFeedURLString` setting with `activeAuthoritySlug` and derived feed URL.
2. Add authority directory fetch.
3. Add compare/browse views using non-active authority feeds.
4. Keep existing merge logic in `AppState.applyOverrides(...)`; only change how authority feed is selected.

## Risks and Mitigations
- Data conflicts from late moonsighting updates:
  - Mitigation: immutable publication log + explicit overwrite semantics in month-start table.
- Representative misuse:
  - Mitigation: strict auth checks + audit trail + admin override path.

## Immediate Implementation Order
1. Implement schema + indexes.
2. Implement representative auth guard.
3. Implement `GET /authorities` and `GET /authority/{slug}`.
4. Implement publish endpoints.
5. Implement user subscription endpoints.
6. Implement iOS authority selection/subscription flow.
