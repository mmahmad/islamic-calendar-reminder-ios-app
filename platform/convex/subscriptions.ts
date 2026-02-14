import { v } from "convex/values";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import { mutation, query } from "./_generated/server";
import { getAuthUserId, requireSignedIn } from "./lib/authz";

async function getAuthorityBySlug(ctx: QueryCtx | MutationCtx, slug: string) {
  return ctx.db
    .query("authorities")
    .withIndex("by_slug", (q) => q.eq("slug", slug.trim().toLowerCase()))
    .unique();
}

export const getMySubscription = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) {
      return null;
    }

    const active = await ctx.db
      .query("userAuthoritySubscriptions")
      .withIndex("by_user_status", (q) => q.eq("userId", userId).eq("status", "active"))
      .first();

    if (!active) {
      return null;
    }

    const authority = await ctx.db.get(active.authorityId);
    if (!authority) {
      return null;
    }

    return {
      id: active._id,
      authority: {
        id: authority._id,
        slug: authority.slug,
        name: authority.name,
        regionCode: authority.regionCode,
        methodology: authority.methodology,
        isActive: authority.isActive,
      },
      subscribedAt: active.subscribedAt,
      updatedAt: active.updatedAt,
    };
  },
});

export const setMySubscription = mutation({
  args: {
    authoritySlug: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireSignedIn(ctx);
    const authority = await getAuthorityBySlug(ctx, args.authoritySlug);

    if (!authority || !authority.isActive) {
      throw new Error("Authority not found or inactive.");
    }

    const now = Date.now();
    const activeSubscriptions = await ctx.db
      .query("userAuthoritySubscriptions")
      .withIndex("by_user_status", (q) => q.eq("userId", userId).eq("status", "active"))
      .collect();

    for (const row of activeSubscriptions) {
      await ctx.db.patch(row._id, {
        status: "inactive",
        updatedAt: now,
      });
    }

    const id = await ctx.db.insert("userAuthoritySubscriptions", {
      userId,
      authorityId: authority._id,
      status: "active",
      subscribedAt: now,
      updatedAt: now,
    });

    return {
      id,
      authoritySlug: authority.slug,
    };
  },
});

export const clearMySubscription = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await requireSignedIn(ctx);
    const now = Date.now();

    const activeSubscriptions = await ctx.db
      .query("userAuthoritySubscriptions")
      .withIndex("by_user_status", (q) => q.eq("userId", userId).eq("status", "active"))
      .collect();

    for (const row of activeSubscriptions) {
      await ctx.db.patch(row._id, {
        status: "inactive",
        updatedAt: now,
      });
    }

    return { ok: true };
  },
});
