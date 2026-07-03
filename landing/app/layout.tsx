import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Us. — Two people, one little world",
  description:
    "A private app for couples, built for long-distance and close relationships. Miss You, shared photos, partner map, countdowns, and more. Free — Premium just €0.99/mo.",
  openGraph: {
    title: "Us. — Two people, one little world",
    description:
      "A private app for couples. Miss You, shared gallery, partner map, countdowns and more.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
