import { Plugin } from "@opencode/plugin";

const SEARXNG_URL = "http://minix:10008/search";
const MAX_RESULTS = 10;

export default Plugin.define({
  id: "searxng",
  async setup(ctx) {
    await ctx.websearch.transform((editor) => {
      editor.add({
        id: "searxng",
        name: "SearXNG",
        execute: async ({ query }, { signal }) => {
          const url = new URL(SEARXNG_URL);
          url.searchParams.set("q", query);
          url.searchParams.set("format", "json");

          const response = await fetch(url, { signal });
          if (!response.ok) {
            throw new Error(`SearXNG HTTP ${response.status}`);
          }

          const data = await response.json();
          return (data.results ?? []).slice(0, MAX_RESULTS).map((item) => {
            const published = item.publishedDate
              ? Date.parse(item.publishedDate)
              : NaN;
            return {
              url: item.url,
              ...(item.title ? { title: item.title } : {}),
              ...(item.content ? { content: item.content } : {}),
              time: Number.isFinite(published) ? { published } : {},
            };
          });
        },
      });
    });
  },
});
