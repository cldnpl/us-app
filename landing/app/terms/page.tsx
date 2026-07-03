import Link from "next/link";
import Footer from "../components/Footer";

export const metadata = { title: "Terms of Service — Us." };

export default function Terms() {
  return (
    <main>
      <div className="mx-auto max-w-3xl px-6 py-16">
        <Link href="/" className="text-sm text-[#ff6b6b]">← Back</Link>
        <h1 className="mt-4 text-4xl font-black">Terms of Service</h1>
        <p className="mt-2 text-neutral-500">Last updated: {new Date().getFullYear()}</p>

        <div className="mt-8 space-y-6 text-neutral-700 leading-relaxed">
          <p>
            By using Us., you agree to these terms. Us. is provided for personal, non-commercial use
            between two paired partners.
          </p>
          <section>
            <h2 className="text-xl font-bold text-neutral-900">Your account</h2>
            <p className="mt-3">
              You&apos;re responsible for keeping your login secure and for the content you share.
              Don&apos;t upload anything illegal or that you don&apos;t have the right to share.
            </p>
          </section>
          <section>
            <h2 className="text-xl font-bold text-neutral-900">Premium subscription</h2>
            <p className="mt-3">
              Premium is an auto-renewing subscription billed at €0.99/month through your App Store
              account. It renews unless cancelled at least 24 hours before the end of the period.
              Manage or cancel anytime in your Apple ID settings.
            </p>
          </section>
          <section>
            <h2 className="text-xl font-bold text-neutral-900">Availability</h2>
            <p className="mt-3">
              We work hard to keep Us. running, but the service is provided &ldquo;as is&rdquo;
              without warranty. We may update these terms; we&apos;ll note changes here.
            </p>
          </section>
        </div>
      </div>
      <Footer />
    </main>
  );
}
