import Link from "next/link";
import Footer from "../components/Footer";

export const metadata = { title: "Privacy Policy — Us." };

export default function Privacy() {
  return (
    <main>
      <div className="mx-auto max-w-3xl px-6 py-16">
        <Link href="/" className="text-sm text-[#ff6b6b]">← Back</Link>
        <h1 className="mt-4 text-4xl font-black">Privacy Policy</h1>
        <p className="mt-2 text-neutral-500">Last updated: {new Date().getFullYear()}</p>

        <div className="mt-8 space-y-6 text-neutral-700 leading-relaxed">
          <p>
            Us. is a private, two-person app. We collect only what we need to connect you with your
            partner and run the features you use. We never sell your data.
          </p>

          <section>
            <h2 className="text-xl font-bold text-neutral-900">What we store</h2>
            <ul className="mt-3 list-disc pl-6 space-y-1">
              <li>Account details: your name, and your email or Sign in with Apple identifier.</li>
              <li>Couple content you create: photos, notes, anniversaries, and messages — visible only to you and your partner.</li>
              <li>Location: only when you explicitly turn on sharing. It is stored while sharing is active and deleted when you turn it off or enable &ldquo;ghost mode&rdquo;.</li>
              <li>Device push tokens, so we can deliver notifications.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-neutral-900">Your rights (GDPR)</h2>
            <p className="mt-3">
              You can export or permanently delete your account and data from within the app at any
              time. To request help, email{" "}
              <a href="mailto:dev@sharepact.com" className="text-[#ff6b6b]">dev@sharepact.com</a>.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-neutral-900">Security</h2>
            <p className="mt-3">
              All traffic is encrypted in transit (HTTPS). Passwords are hashed. Your shared content
              is accessible only to you and your paired partner.
            </p>
          </section>
        </div>
      </div>
      <Footer />
    </main>
  );
}
