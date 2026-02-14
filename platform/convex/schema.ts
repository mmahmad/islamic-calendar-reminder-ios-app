import { authTables } from "@convex-dev/auth/server";
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

const authorityMethodology = v.union(
  v.literal("moonsighting"),
  v.literal("calculated"),
  v.literal("hybrid"),
);

const representativeRole = v.union(v.literal("representative"), v.literal("admin"));
const representativeStatus = v.union(v.literal("active"), v.literal("revoked"));

const publicationType = v.union(
  v.literal("full_year"),
  v.literal("moonsighting_update"),
);

const monthStatus = v.union(v.literal("confirmed"), v.literal("projected"));
const monthSourceType = v.union(
  v.literal("full_year"),
  v.literal("moonsighting_update"),
  v.literal("manual_admin"),
);

const subscriptionStatus = v.union(v.literal("active"), v.literal("inactive"));

export default defineSchema({
  ...authTables,

  userProfiles: defineTable({
    userId: v.id("users"),
    email: v.string(),
    name: v.optional(v.string()),
    approved: v.boolean(),
    isAdmin: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_approved", ["approved"])
    .index("by_email", ["email"]),

  authorities: defineTable({
    slug: v.string(),
    name: v.string(),
    regionCode: v.string(),
    methodology: authorityMethodology,
    websiteUrl: v.optional(v.string()),
    isActive: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_slug", ["slug"])
    .index("by_region", ["regionCode"])
    .index("by_active", ["isActive"]),

  authorityRepresentatives: defineTable({
    authorityId: v.id("authorities"),
    userId: v.id("users"),
    role: representativeRole,
    status: representativeStatus,
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_authority_status", ["authorityId", "status"])
    .index("by_user_status", ["userId", "status"]),

  authorityPublications: defineTable({
    authorityId: v.id("authorities"),
    type: publicationType,
    title: v.optional(v.string()),
    notes: v.optional(v.string()),
    publishedBy: v.id("users"),
    publishedAt: v.number(),
    effectiveFromHijriYear: v.optional(v.number()),
    effectiveFromHijriMonth: v.optional(v.number()),
  }).index("by_authority_publishedAt", ["authorityId", "publishedAt"]),

  authorityMonthStarts: defineTable({
    authorityId: v.id("authorities"),
    hijriYear: v.number(),
    hijriMonth: v.number(),
    gregorianStartDate: v.string(),
    status: monthStatus,
    sourceType: monthSourceType,
    publicationId: v.optional(v.id("authorityPublications")),
    updatedBy: v.id("users"),
    updatedAt: v.number(),
  })
    .index("by_authority_year_month", ["authorityId", "hijriYear", "hijriMonth"])
    .index("by_authority_updatedAt", ["authorityId", "updatedAt"]),

  userAuthoritySubscriptions: defineTable({
    userId: v.id("users"),
    authorityId: v.id("authorities"),
    status: subscriptionStatus,
    subscribedAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user_status", ["userId", "status"])
    .index("by_authority_status", ["authorityId", "status"]),
});
