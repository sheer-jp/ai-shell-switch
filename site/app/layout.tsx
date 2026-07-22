import type { Metadata } from "next";
import { headers } from "next/headers";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const siteUrl = "https://trustdrivensystem.com/labs/ai-shell-switch/";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host =
    requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host");
  const protocol = requestHeaders.get("x-forwarded-proto") ?? "https";
  const origin = host
    ? `${protocol}://${host}`
    : "https://github.com/sheer-jp/ai-shell-switch";
  const title = "AI Shell Switch — AIの実行環境を、止めない";
  const description =
    "Macのスリープ状態を、AIワークロードのために安全にコントロール。ローカルAIの長時間処理を支える、オープンソースのAI uptime layer。";

  return {
    metadataBase: new URL(siteUrl),
    title,
    description,
    alternates: {
      canonical: siteUrl,
    },
    icons: {
      icon: "/app-icon.png",
      shortcut: "/app-icon.png",
      apple: "/app-icon.png",
    },
    openGraph: {
      title,
      description,
      type: "website",
      locale: "ja_JP",
      images: [
        {
          url: `${origin}/og.png`,
          width: 1200,
          height: 630,
          alt: "AI Shell Switch — AIの実行環境を、止めない",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [`${origin}/og.png`],
    },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        {children}
      </body>
    </html>
  );
}
