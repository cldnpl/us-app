import Link from "next/link";
import Footer from "../components/Footer";

export const metadata = { title: "Support — Us." };

export default function Support() {
  return (
    <main>
      <div className="mx-auto max-w-3xl px-6 py-16">
        <Link href="/" className="text-sm text-[#ff6b6b]">← Back</Link>
        <h1 className="mt-4 text-4xl font-black">Support</h1>
        <p className="mt-4 text-neutral-700 leading-relaxed">
          Need a hand, or have an idea to make Us. better? We&apos;d love to hear from you.
        </p>

        <div className="mt-8 rounded-3xl border border-black/5 bg-white p-8 shadow-sm">
          <h2 className="text-lg font-semibold">Get in touch</h2>
          <p className="mt-2 text-neutral-600">
            Email us at{" "}
            <a href="mailto:dev@sharepact.com" className="font-semibold text-[#ff6b6b]">dev@sharepact.com</a>
            {" "}and we&apos;ll get back to you.
          </p>

          <h2 className="mt-8 text-lg font-semibold">Common questions</h2>
          <dl className="mt-3 space-y-4 text-neutral-600">
            <div>
              <dt className="font-medium text-neutral-900">How do I pair with my partner?</dt>
              <dd>Open Us., tap &ldquo;Invite your partner&rdquo; to generate a code, and have them enter it.</dd>
            </div>
            <div>
              <dt className="font-medium text-neutral-900">How do I cancel Premium?</dt>
              <dd>Manage your subscription in your Apple ID settings on your iPhone.</dd>
            </div>
            <div>
              <dt className="font-medium text-neutral-900">How do I delete my account?</dt>
              <dd>Go to Profile → delete account. This permanently removes your data.</dd>
            </div>
          </dl>
        </div>
      </div>
      <Footer />
    </main>
  );
}
