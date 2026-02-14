import { getAuthUserId as getAuthUserIdFromSession } from "@convex-dev/auth/server";
import type { Doc, Id } from "../_generated/dataModel";
import type { MutationCtx, QueryCtx } from "../_generated/server";

export type AnyCtx = QueryCtx | MutationCtx;

export async function getAuthUserId(ctx: AnyCtx): Promise<Id<"users"> | null> {
  return getAuthUserIdFromSession(ctx);
}

export async function getProfileByUserId(
  ctx: AnyCtx,
  userId: Id<"users">,
): Promise<Doc<"userProfiles"> | null> {
  return ctx.db.query("userProfiles").withIndex("by_user", (q) => q.eq("userId", userId)).unique();
}

export async function requireSignedIn(ctx: AnyCtx): Promise<Id<"users">> {
  const userId = await getAuthUserId(ctx);
  if (!userId) {
    throw new Error("Authentication required.");
  }
  return userId;
}

export async function requireProfile(ctx: AnyCtx): Promise<Doc<"userProfiles">> {
  const userId = await requireSignedIn(ctx);
  const profile = await getProfileByUserId(ctx, userId);
  if (!profile) {
    throw new Error("User profile missing. Run users.ensureCurrentUser first.");
  }
  return profile;
}

export async function requireApprovedUser(ctx: AnyCtx): Promise<Doc<"userProfiles">> {
  const profile = await requireProfile(ctx);
  if (!profile.approved) {
    throw new Error("User is not approved.");
  }
  return profile;
}

export async function requireAdmin(ctx: AnyCtx): Promise<Doc<"userProfiles">> {
  const profile = await requireProfile(ctx);
  if (!profile.isAdmin) {
    throw new Error("Admin access required.");
  }
  return profile;
}

export async function requireAuthorityEditor(
  ctx: AnyCtx,
  authorityId: Id<"authorities">,
): Promise<Doc<"userProfiles">> {
  const profile = await requireApprovedUser(ctx);
  if (profile.isAdmin) {
    return profile;
  }

  const reps = await ctx.db
    .query("authorityRepresentatives")
    .withIndex("by_authority_status", (q) => q.eq("authorityId", authorityId).eq("status", "active"))
    .collect();

  const canEdit = reps.some((rep) => rep.userId === profile.userId);
  if (!canEdit) {
    throw new Error("Representative access required for this authority.");
  }

  return profile;
}
