type Props = { name: string; size?: number; className?: string };

const paths: Record<string, string> = {
  logo: '<path d="M4 14c1.5 4 5 6 8 6s6.5-2 8-6"/><path d="M5 14h14"/><path d="M8 9c.5-2 2-4 4-4s3.5 2 4 4"/><path d="M12 5V3"/>',
  cash: '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M7 10v4M17 10v4"/>',
  user: '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c1.2-3.5 3.7-5 7-5s5.8 1.5 7 5"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  'eye-off': '<path d="m3 3 18 18"/><path d="M10.6 10.6a2 2 0 0 0 2.8 2.8"/><path d="M9.9 5.2A10.7 10.7 0 0 1 12 5c6.5 0 10 7 10 7a14 14 0 0 1-3.1 3.9M6.2 6.2A16 16 0 0 0 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4.1-.8"/>',
  printer: '<path d="M6 9V3h12v6"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 14h12v7H6z"/><path d="M18 12h.01"/>',
  chart: '<path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-5 5"/>',
  check: '<circle cx="12" cy="12" r="8"/><path d="M8.5 12.5 11 15l4.5-5"/>',
  order: '<path d="M7 3h10v18H7z"/><path d="M10 7h4M10 11h4M10 15h2"/>',
  salon: '<circle cx="12" cy="11" r="6"/><path d="M8 21v-4M16 21v-4M12 17v4"/>',
};

export function SipanIcon({ name, size = 22, className = 'sipan-icon' }: Props) {
  const inner = paths[name] ?? paths.logo;
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      dangerouslySetInnerHTML={{ __html: inner }}
    />
  );
}
