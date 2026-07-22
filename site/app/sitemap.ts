import type { MetadataRoute } from "next";

const siteUrl = "https://trustdrivensystem.com/labs/ai-shell-switch/";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: siteUrl,
      lastModified: new Date("2026-07-22T00:00:00+09:00"),
      changeFrequency: "weekly",
      priority: 1,
    },
  ];
}
