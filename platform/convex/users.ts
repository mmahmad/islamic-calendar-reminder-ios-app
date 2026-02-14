import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { isAdminEmail } from "./lib/env";
import { getAuthUserId, getProfileByUserId, requireAdmin, requireSignedIn } from "./lib/authz";

type PublicUser = {
  id: string;
  email: string;
  name: string;
  approved: boolean;
  isAdmin: boolean;
};

function normalizeAuthIdentity(authUser: Record<string, unknown> | null): {
  email: string;
  name: string;
} {
  const email = typeof authUser?.email === "string" ? authUser.email : "";
  const name = typeof authUser?.name === "string" ? authUser.name : "";
  return { email, name };
}

function toPublicUser(profile: {
  userId: string;
  email: string;
  name?: string;
  approved: boolean;
  isAdmin: boolean;
}): PublicUser {
  return {
    id: profile.userId,
    email: profile.email,
    name: profile.name ?? "",
    approved: profile.approved,
    isAdmin: profile.isAdmin,
  };
}

export const ensureCurrentUser = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await requireSignedIn(ctx);
    const authUser = (await ctx.db.get(userId)) as Record<string, unknown> | null;
    const { email, name } = normalizeAuthIdentity(authUser);
    const adminByEmail = isAdminEmail(email);
    const now = Date.now();

    const existing = await getProfileByUserId(ctx, userId);
    if (existing) {
      const shouldPromote = adminByEmail && (!existing.isAdmin || !existing.approved);
      if (
        existing.email !== email ||
        existing.name !== name ||
        shouldPromote
      ) {
        await ctx.db.patch(existing._id, {
          email,
          name,
          isAdmin: shouldPromote ? true : existing.isAdmin,
          approved: shouldPromote ? true : existing.approved,
          updatedAt: now,
        });
      }

      return toPublicUser({
        userId,
        email,
        name,
        approved: shouldPromote ? true : existing.approved,
        isAdmin: shouldPromote ? true : existing.isAdmin,
      });
    }

    await ctx.db.insert("userProfiles", {
      userId,
      email,
      name,
      approved: adminByEmail,
      isAdmin: adminByEmail,
      createdAt: now,
      updatedAt: now,
    });

    return toPublicUser({
      userId,
      email,
      name,
      approved: adminByEmail,
      isAdmin: adminByEmail,
    });
  },
});

export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) {
      return null;
    }

    const profile = await getProfileByUserId(ctx, userId);
    if (!profile) {
      return null;
    }

    return toPublicUser({
      userId,
      email: profile.email,
      name: profile.name,
      approved: profile.approved,
      isAdmin: profile.isAdmin,
    });
  },
});

export const listPendingUsers = query({
  args: {},
  handler: async (ctx) => {
    await requireAdmin(ctx);
    const profiles = await ctx.db
      .query("userProfiles")
      .withIndex("by_approved", (q) => q.eq("approved", false))
      .collect();

    return profiles
      .sort((a, b) => a.createdAt - b.createdAt)
      .map((profile) => ({
        id: profile.userId,
        email: profile.email,
        name: profile.name ?? "",
        createdAt: profile.createdAt,
      }));
  },
});

export const listApprovedUsers = query({
  args: {},
  handler: async (ctx) => {
    await requireAdmin(ctx);
    const profiles = await ctx.db
      .query("userProfiles")
      .withIndex("by_approved", (q) => q.eq("approved", true))
      .collect();

    return profiles
      .sort((a, b) => a.email.localeCompare(b.email))
      .map((profile) => ({
        id: profile.userId,
        email: profile.email,
        name: profile.name ?? "",
        isAdmin: profile.isAdmin,
        updatedAt: profile.updatedAt,
      }));
  },
});

export const approveUser = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    await requireAdmin(ctx);

    const profile = await getProfileByUserId(ctx, args.userId);
    if (!profile) {
      throw new Error("User profile not found.");
    }

    await ctx.db.patch(profile._id, {
      approved: true,
      updatedAt: Date.now(),
    });

    return { ok: true };
  },
});
