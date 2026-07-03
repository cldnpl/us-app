import Footer from "./components/Footer";

const features = [
  { icon: "💜", title: "Miss You", body: "One tap sends a little heart to your partner's phone — and their home screen widget." },
  { icon: "📸", title: "Photo to widget", body: "Send a photo straight to your partner's home screen. A glance, and they're there." },
  { icon: "🗺️", title: "Partner map", body: "See where your partner is on Apple Maps — opt-in, private, and pausable anytime." },
  { icon: "🎨", title: "Draw & play together", body: "A shared live canvas and mini-games to play across any distance." },
  { icon: "⏳", title: "Countdowns", body: "Days together, anniversaries, and a countdown to your next reunion." },
  { icon: "💌", title: "Open-when letters", body: "Leave notes your partner opens when they're sad, missing you, or celebrating." },
];

const freePerks = [
  "Miss You, pairing & profile",
  "Shared gallery (up to 100 photos)",
  "Home & lock-screen widgets",
  "Draw together & mini-games",
  "Partner map (opt-in)",
  "Anniversaries & countdowns",
];

const premiumPerks = [
  "Unlimited photos & video (HD)",
  "Unlimited widgets & themes",
  "Live location + map widget",
  "Unlimited games & doodles",
  "Open-when letters & scheduled notes",
  "Bigger storage quota",
];

export default function Home() {
  return (
    <main>
      {/* Hero */}
      <section className="relative overflow-hidden bg-gradient-to-br from-[#ffb5c2] via-[#ff6b6b] to-[#ffd9ba]">
        <div className="mx-auto max-w-5xl px-6 pt-24 pb-28 text-center text-white">
          <h1 className="text-7xl sm:text-8xl font-black tracking-tight drop-shadow-sm">Us.</h1>
          <p className="mt-4 text-2xl sm:text-3xl font-medium">Two people, one little world.</p>
          <p className="mx-auto mt-5 max-w-xl text-lg text-white/90">
            A private app for couples — built for long-distance, lovely for close.
            Stay close with a tap, a photo, a glance at your widget.
          </p>
          <div className="mt-9 flex items-center justify-center gap-4">
            <span className="rounded-2xl bg-white px-6 py-3 font-semibold text-[#ff6b6b] shadow-lg">
               Coming to the App Store
            </span>
          </div>
          <p className="mt-4 text-sm text-white/80">Free to use — Premium just €0.99/month.</p>
        </div>
      </section>

      {/* Features */}
      <section className="mx-auto max-w-5xl px-6 py-20">
        <h2 className="text-center text-3xl font-bold">Everything you need to feel close</h2>
        <p className="mt-3 text-center text-neutral-500">
          Small, frequent moments of connection — designed to feel native on iPhone.
        </p>
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div key={f.title} className="rounded-3xl border border-black/5 bg-white p-7 shadow-sm transition hover:shadow-md">
              <div className="text-4xl">{f.icon}</div>
              <h3 className="mt-4 text-lg font-semibold">{f.title}</h3>
              <p className="mt-2 text-neutral-500">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Long distance */}
      <section className="bg-[#fff5f0]">
        <div className="mx-auto max-w-5xl px-6 py-20 grid gap-10 md:grid-cols-2 items-center">
          <div>
            <span className="rounded-full bg-[#ff6b6b]/10 px-3 py-1 text-sm font-semibold text-[#ff6b6b]">
              Made for long-distance
            </span>
            <h2 className="mt-4 text-3xl font-bold">The miles feel smaller.</h2>
            <p className="mt-4 text-neutral-600">
              Dual time zones so you always know their morning from their night. Distance and a
              partner map. A big countdown to the next time you&apos;re together. And &ldquo;open
              when&rdquo; letters for the moments in between.
            </p>
          </div>
          <div className="rounded-3xl bg-white p-8 shadow-sm">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-neutral-400">Alex · 4:12 AM</p>
                <p className="text-lg font-semibold">good night 💜</p>
              </div>
              <div className="text-right">
                <p className="text-sm text-neutral-400">You · 11:12 PM</p>
                <p className="text-lg font-semibold">good morning ☀️</p>
              </div>
            </div>
            <div className="mt-6 rounded-2xl bg-gradient-to-br from-[#ffb5c2] to-[#ffd9ba] p-6 text-center text-white">
              <p className="text-sm/relaxed opacity-90">Next reunion in</p>
              <p className="text-4xl font-black">7 days ✈️</p>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section className="mx-auto max-w-5xl px-6 py-20">
        <h2 className="text-center text-3xl font-bold">Completely freemium</h2>
        <p className="mt-3 text-center text-neutral-500">
          Every feature is free — Premium just raises the limits.
        </p>
        <div className="mt-12 grid gap-6 md:grid-cols-2">
          <div className="rounded-3xl border border-black/5 bg-white p-8 shadow-sm">
            <h3 className="text-xl font-bold">Free</h3>
            <p className="mt-1 text-3xl font-black">€0</p>
            <ul className="mt-6 space-y-3 text-neutral-600">
              {freePerks.map((p) => (
                <li key={p} className="flex gap-3"><span className="text-[#ff6b6b]">✓</span>{p}</li>
              ))}
            </ul>
          </div>
          <div className="rounded-3xl border-2 border-[#ff6b6b] bg-white p-8 shadow-md">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">Premium</h3>
              <span className="rounded-full bg-[#ff6b6b]/10 px-3 py-1 text-sm font-semibold text-[#ff6b6b]">Best for two</span>
            </div>
            <p className="mt-1 text-3xl font-black">€0.99<span className="text-lg font-medium text-neutral-400">/month</span></p>
            <ul className="mt-6 space-y-3 text-neutral-600">
              {premiumPerks.map((p) => (
                <li key={p} className="flex gap-3"><span className="text-[#ff6b6b]">✓</span>{p}</li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <Footer />
    </main>
  );
}
