import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import { mutation, query } from "./_generated/server";
import { requireAdmin, requireAuthorityEditor } from "./lib/authz";

const methodologyValidator = v.union(
  v.literal("moonsighting"),
  v.literal("calculated"),
  v.literal("hybrid"),
);

const monthStatusValidator = v.union(v.literal("confirmed"), v.literal("projected"));
const publicationTypeValidator = v.union(
  v.literal("full_year"),
  v.literal("moonsighting_update"),
);

const monthSourceTypeValidator = v.union(
  v.literal("full_year"),
  v.literal("moonsighting_update"),
  v.literal("manual_admin"),
);

function normalizeSlug(raw: string): string {
  return raw.trim().toLowerCase();
}

function assertValidMonth(value: number) {
  if (value < 1 || value > 12) {
    throw new Error("Hijri month must be between 1 and 12.");
  }
}

async function findAuthorityBySlug(ctx: QueryCtx | MutationCtx, slug: string) {
  return ctx.db.query("authorities").withIndex("by_slug", (q) => q.eq("slug", normalizeSlug(slug))).unique();
}

async function getAuthorityBySlugOrThrow(ctx: QueryCtx | MutationCtx, slug: string) {
  const authority = await findAuthorityBySlug(ctx, slug);
  if (!authority) {
    throw new Error("Authority not found.");
  }
  return authority;
}

async function upsertMonthStart(
  ctx: MutationCtx,
  args: {
    authorityId: Id<"authorities">;
    hijriYear: number;
    hijriMonth: number;
    gregorianStartDate: string;
    status: "confirmed" | "projected";
    sourceType: "full_year" | "moonsighting_update" | "manual_admin";
    publicationId?: Id<"authorityPublications">;
    updatedBy: Id<"users">;
  },
) {
  const existing = await ctx.db
    .query("authorityMonthStarts")
    .withIndex("by_authority_year_month", (q) =>
      q.eq("authorityId", args.authorityId)
        .eq("hijriYear", args.hijriYear)
        .eq("hijriMonth", args.hijriMonth),
    )
    .unique();

  const payload = {
    authorityId: args.authorityId,
    hijriYear: args.hijriYear,
    hijriMonth: args.hijriMonth,
    gregorianStartDate: args.gregorianStartDate,
    status: args.status,
    sourceType: args.sourceType,
    publicationId: args.publicationId,
    updatedBy: args.updatedBy,
    updatedAt: Date.now(),
  };

  if (existing) {
    await ctx.db.patch(existing._id, payload);
    return existing._id;
  }

  return ctx.db.insert("authorityMonthStarts", payload);
}

async function createPublication(
  ctx: MutationCtx,
  args: {
    authorityId: Id<"authorities">;
    type: "full_year" | "moonsighting_update";
    notes?: string;
    effectiveFromHijriYear?: number;
    effectiveFromHijriMonth?: number;
    publishedBy: Id<"users">;
  },
) {
  return ctx.db.insert("authorityPublications", {
    authorityId: args.authorityId,
    type: args.type,
    notes: args.notes,
    publishedBy: args.publishedBy,
    publishedAt: Date.now(),
    effectiveFromHijriYear: args.effectiveFromHijriYear,
    effectiveFromHijriMonth: args.effectiveFromHijriMonth,
  });
}

export const listAuthorities = query({
  args: {
    includeInactive: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const authorities = args.includeInactive
      ? await ctx.db.query("authorities").collect()
      : await ctx.db.query("authorities").withIndex("by_active", (q) => q.eq("isActive", true)).collect();

    return authorities
      .sort((a, b) => a.name.localeCompare(b.name))
      .map((authority) => ({
        id: authority._id,
        slug: authority.slug,
        name: authority.name,
        regionCode: authority.regionCode,
        methodology: authority.methodology,
        websiteUrl: authority.websiteUrl,
        isActive: authority.isActive,
        updatedAt: authority.updatedAt,
      }));
  },
});

export const getAuthorityBySlug = query({
  args: {
    slug: v.string(),
  },
  handler: async (ctx, args) => {
    const authority = await findAuthorityBySlug(ctx, args.slug);
    if (!authority) {
      return null;
    }

    return {
      id: authority._id,
      slug: authority.slug,
      name: authority.name,
      regionCode: authority.regionCode,
      methodology: authority.methodology,
      websiteUrl: authority.websiteUrl,
      isActive: authority.isActive,
      updatedAt: authority.updatedAt,
    };
  },
});

export const getAuthorityFeed = query({
  args: {
    slug: v.string(),
  },
  handler: async (ctx, args) => {
    const authority = await findAuthorityBySlug(ctx, args.slug);
    if (!authority || !authority.isActive) {
      return null;
    }

    const months = await ctx.db
      .query("authorityMonthStarts")
      .withIndex("by_authority_updatedAt", (q) => q.eq("authorityId", authority._id))
      .collect();

    const sortedMonths = months
      .sort((a, b) => {
        if (a.hijriYear === b.hijriYear) {
          return a.hijriMonth - b.hijriMonth;
        }
        return a.hijriYear - b.hijriYear;
      })
      .map((month) => ({
        hijriYear: month.hijriYear,
        hijriMonth: month.hijriMonth,
        gregorianStartDate: month.gregorianStartDate,
        status: month.status,
        updatedAt: month.updatedAt,
      }));

    return {
      authority: {
        slug: authority.slug,
        name: authority.name,
        regionCode: authority.regionCode,
        methodology: authority.methodology,
        updatedAt: authority.updatedAt,
      },
      months: sortedMonths,
    };
  },
});

export const listAuthorityMonths = query({
  args: {
    slug: v.string(),
  },
  handler: async (ctx, args) => {
    const authority = await getAuthorityBySlugOrThrow(ctx, args.slug);
    const months = await ctx.db
      .query("authorityMonthStarts")
      .withIndex("by_authority_updatedAt", (q) => q.eq("authorityId", authority._id))
      .collect();

    return months
      .sort((a, b) => {
        if (a.hijriYear === b.hijriYear) {
          return a.hijriMonth - b.hijriMonth;
        }
        return a.hijriYear - b.hijriYear;
      })
      .map((month) => ({
        id: month._id,
        hijriYear: month.hijriYear,
        hijriMonth: month.hijriMonth,
        gregorianStartDate: month.gregorianStartDate,
        status: month.status,
        sourceType: month.sourceType,
        updatedAt: month.updatedAt,
      }));
  },
});

export const createAuthority = mutation({
  args: {
    slug: v.string(),
    name: v.string(),
    regionCode: v.optional(v.string()),
    methodology: v.optional(methodologyValidator),
    websiteUrl: v.optional(v.string()),
    isActive: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    await requireAdmin(ctx);

    const slug = normalizeSlug(args.slug);
    if (!slug) {
      throw new Error("Authority slug is required.");
    }

    const existing = await findAuthorityBySlug(ctx, slug);
    if (existing) {
      throw new Error("Authority slug already exists.");
    }

    const now = Date.now();
    const id = await ctx.db.insert("authorities", {
      slug,
      name: args.name.trim(),
      regionCode: (args.regionCode ?? "GLOBAL").trim().toUpperCase(),
      methodology: args.methodology ?? "moonsighting",
      websiteUrl: args.websiteUrl,
      isActive: args.isActive ?? true,
      createdAt: now,
      updatedAt: now,
    });

    return { id, slug };
  },
});

export const assignAuthorityRepresentative = mutation({
  args: {
    authoritySlug: v.string(),
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await requireAdmin(ctx);
    const authority = await getAuthorityBySlugOrThrow(ctx, args.authoritySlug);
    const now = Date.now();

    const activeReps = await ctx.db
      .query("authorityRepresentatives")
      .withIndex("by_authority_status", (q) => q.eq("authorityId", authority._id).eq("status", "active"))
      .collect();

    for (const rep of activeReps) {
      if (rep.role === "representative") {
        await ctx.db.patch(rep._id, {
          status: "revoked",
          updatedAt: now,
        });
      }
    }

    await ctx.db.insert("authorityRepresentatives", {
      authorityId: authority._id,
      userId: args.userId,
      role: "representative",
      status: "active",
      createdAt: now,
      updatedAt: now,
    });

    return { ok: true };
  },
});

export const publishFullYear = mutation({
  args: {
    slug: v.string(),
    hijriYear: v.number(),
    months: v.array(
      v.object({
        hijriMonth: v.number(),
        gregorianStartDate: v.string(),
        status: v.optional(monthStatusValidator),
      }),
    ),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const authority = await getAuthorityBySlugOrThrow(ctx, args.slug);
    const profile = await requireAuthorityEditor(ctx, authority._id);

    const publicationId = await createPublication(ctx, {
      authorityId: authority._id,
      type: "full_year",
      notes: args.notes,
      effectiveFromHijriYear: args.hijriYear,
      effectiveFromHijriMonth: 1,
      publishedBy: profile.userId,
    });

    for (const month of args.months) {
      assertValidMonth(month.hijriMonth);
      await upsertMonthStart(ctx, {
        authorityId: authority._id,
        hijriYear: args.hijriYear,
        hijriMonth: month.hijriMonth,
        gregorianStartDate: month.gregorianStartDate,
        status: month.status ?? "projected",
        sourceType: "full_year",
        publicationId,
        updatedBy: profile.userId,
      });
    }

    await ctx.db.patch(authority._id, { updatedAt: Date.now() });

    return { ok: true, count: args.months.length };
  },
});

export const publishMoonsighting = mutation({
  args: {
    slug: v.string(),
    updates: v.array(
      v.object({
        hijriYear: v.number(),
        hijriMonth: v.number(),
        gregorianStartDate: v.string(),
        status: v.optional(monthStatusValidator),
      }),
    ),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const authority = await getAuthorityBySlugOrThrow(ctx, args.slug);
    const profile = await requireAuthorityEditor(ctx, authority._id);

    const first = args.updates[0];
    const publicationId = await createPublication(ctx, {
      authorityId: authority._id,
      type: "moonsighting_update",
      notes: args.notes,
      effectiveFromHijriYear: first?.hijriYear,
      effectiveFromHijriMonth: first?.hijriMonth,
      publishedBy: profile.userId,
    });

    for (const update of args.updates) {
      assertValidMonth(update.hijriMonth);
      await upsertMonthStart(ctx, {
        authorityId: authority._id,
        hijriYear: update.hijriYear,
        hijriMonth: update.hijriMonth,
        gregorianStartDate: update.gregorianStartDate,
        status: update.status ?? "confirmed",
        sourceType: "moonsighting_update",
        publicationId,
        updatedBy: profile.userId,
      });
    }

    await ctx.db.patch(authority._id, { updatedAt: Date.now() });

    return { ok: true, count: args.updates.length };
  },
});

export const upsertAuthorityMonth = mutation({
  args: {
    slug: v.string(),
    hijriYear: v.number(),
    hijriMonth: v.number(),
    gregorianStartDate: v.string(),
    status: v.optional(monthStatusValidator),
    sourceType: v.optional(monthSourceTypeValidator),
    publicationType: v.optional(publicationTypeValidator),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const authority = await getAuthorityBySlugOrThrow(ctx, args.slug);
    const profile = await requireAuthorityEditor(ctx, authority._id);
    assertValidMonth(args.hijriMonth);

    const publicationId = await createPublication(ctx, {
      authorityId: authority._id,
      type: args.publicationType ?? "moonsighting_update",
      notes: args.notes,
      effectiveFromHijriYear: args.hijriYear,
      effectiveFromHijriMonth: args.hijriMonth,
      publishedBy: profile.userId,
    });

    const id = await upsertMonthStart(ctx, {
      authorityId: authority._id,
      hijriYear: args.hijriYear,
      hijriMonth: args.hijriMonth,
      gregorianStartDate: args.gregorianStartDate,
      status: args.status ?? "confirmed",
      sourceType: args.sourceType ?? "moonsighting_update",
      publicationId,
      updatedBy: profile.userId,
    });

    await ctx.db.patch(authority._id, { updatedAt: Date.now() });

    return { id };
  },
});

export const deleteAuthorityMonth = mutation({
  args: {
    id: v.optional(v.id("authorityMonthStarts")),
    slug: v.optional(v.string()),
    hijriYear: v.optional(v.number()),
    hijriMonth: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    let monthRow = args.id ? await ctx.db.get(args.id) : null;

    if (!monthRow) {
      if (!args.slug || args.hijriYear === undefined || args.hijriMonth === undefined) {
        throw new Error("Pass id or (slug + hijriYear + hijriMonth) to delete month start.");
      }

      const authority = await getAuthorityBySlugOrThrow(ctx, args.slug);
      monthRow = await ctx.db
        .query("authorityMonthStarts")
        .withIndex("by_authority_year_month", (q) =>
          q.eq("authorityId", authority._id)
            .eq("hijriYear", args.hijriYear!)
            .eq("hijriMonth", args.hijriMonth!),
        )
        .unique();
    }

    if (!monthRow) {
      throw new Error("Month start not found.");
    }

    await requireAuthorityEditor(ctx, monthRow.authorityId);
    await ctx.db.delete(monthRow._id);
    await ctx.db.patch(monthRow.authorityId, { updatedAt: Date.now() });

    return { ok: true };
  },
});
