import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";
import { auth } from "./auth";

const http = httpRouter();
auth.addHttpRoutes(http);

function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });
}

http.route({
  path: "/authorities",
  method: "GET",
  handler: httpAction(async (ctx) => {
    const authorities = await ctx.runQuery(api.authorities.listAuthorities, {});
    return json({ authorities });
  }),
});

http.route({
  pathPrefix: "/authority/",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const url = new URL(request.url);
    const segments = url.pathname.split("/").filter(Boolean);

    if (segments.length < 2 || segments[0] !== "authority") {
      return json({ error: "Not found." }, { status: 404 });
    }

    const slug = segments[1];

    if (segments.length === 2) {
      const feed = await ctx.runQuery(api.authorities.getAuthorityFeed, { slug });
      if (!feed) {
        return json({ error: "Authority not found." }, { status: 404 });
      }
      return json(feed);
    }

    if (segments.length === 3 && segments[2] === "preview") {
      // Preview currently mirrors feed output. The merged effective-calendar view can be
      // added later without changing this route contract.
      const feed = await ctx.runQuery(api.authorities.getAuthorityFeed, { slug });
      if (!feed) {
        return json({ error: "Authority not found." }, { status: 404 });
      }
      return json(feed);
    }

    return json({ error: "Not found." }, { status: 404 });
  }),
});

export default http;
