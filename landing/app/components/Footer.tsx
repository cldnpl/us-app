import Link from "next/link";

export default function Footer() {
  return (
    <footer className="border-t border-black/5 bg-white">
      <div className="mx-auto max-w-5xl px-6 py-10 flex flex-col sm:flex-row items-center justify-between gap-4 text-sm text-neutral-500">
        <div className="flex items-center gap-2">
          <span className="text-xl font-bold text-[#ff6b6b]">Us.</span>
          <span>© {new Date().getFullYear()} · Two people, one little world.</span>
        </div>
        <nav className="flex items-center gap-6">
          <Link href="/privacy" className="hover:text-[#ff6b6b]">Privacy</Link>
          <Link href="/terms" className="hover:text-[#ff6b6b]">Terms</Link>
          <Link href="/support" className="hover:text-[#ff6b6b]">Support</Link>
        </nav>
      </div>
    </footer>
  );
}
