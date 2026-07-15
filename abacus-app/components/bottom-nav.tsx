'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Gamepad2, User, ShoppingBag, GraduationCap, Sparkles } from 'lucide-react';

const ITEMS = [
  { href: '/', label: 'Home', icon: Home },
  { href: '/modes', label: 'Modes', icon: Gamepad2 },
  { href: '/coach', label: 'Coach', icon: Sparkles },
  { href: '/profile', label: 'Profile', icon: User },
  { href: '/education', label: 'Learn', icon: GraduationCap },
];

export function BottomNav() {
  const pathname = usePathname() ?? '/';
  return (
    <nav className="fixed bottom-0 inset-x-0 z-50 border-t border-white/10 bg-[#0F0F13]/90 backdrop-blur-md">
      <div className="mx-auto max-w-3xl grid grid-cols-5">
        {ITEMS.map((item) => {
          const Icon = item.icon;
          const active = item.href === '/' ? pathname === '/' : pathname?.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex flex-col items-center gap-1 py-2.5 text-[11px] font-medium transition-colors ${
                active ? 'text-[#00E5FF]' : 'text-white/45 hover:text-white/80'
              }`}
            >
              <Icon className={`h-5 w-5 ${active ? 'drop-shadow-[0_0_8px_rgba(0,229,255,0.8)]' : ''}`} />
              {item.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
