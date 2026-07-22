import type { MetadataRoute } from "next";

const siteUrl = "https://ai-shell-switch.bonahja.chatgpt.site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
    },
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
