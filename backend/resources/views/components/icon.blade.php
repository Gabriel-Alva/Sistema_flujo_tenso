@props(['name' => 'logo', 'size' => 22])
<svg {{ $attributes->merge(['class' => 'sipan-icon']) }} width="{{ $size }}" height="{{ $size }}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
@switch($name)
    @case('logo')
        <path d="M4 14c1.5 4 5 6 8 6s6.5-2 8-6"/><path d="M5 14h14"/><path d="M8 9c.5-2 2-4 4-4s3.5 2 4 4"/><path d="M12 5V3"/>
        @break
    @case('dashboard')
        <rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="3" width="8" height="5" rx="2"/><rect x="13" y="10" width="8" height="11" rx="2"/><rect x="3" y="13" width="8" height="8" rx="2"/>
        @break
    @case('catalog')
        <path d="M4 5h12a3 3 0 0 1 3 3v11H7a3 3 0 0 1-3-3V5z"/><path d="M7 5v14"/><path d="M11 9h5M11 13h5"/>
        @break
    @case('salon')
        <circle cx="12" cy="11" r="6"/><path d="M8 21v-4M16 21v-4M12 17v4"/>
        @break
    @case('audit')
        <path d="M8 3h8v4H8z"/><rect x="5" y="7" width="14" height="14" rx="2"/><path d="M9 13h6M9 17h4"/>
        @break
    @case('logout')
        <path d="M10 7V5a2 2 0 0 1 2-2h7v18h-7a2 2 0 0 1-2-2v-2"/><path d="M4 12h10M12 9l3 3-3 3"/>
        @break
    @case('user')
        <circle cx="12" cy="8" r="3.5"/><path d="M5 20c1.2-3.5 3.7-5 7-5s5.8 1.5 7 5"/>
        @break
    @case('lock')
        <rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>
        @break
    @case('eye')
        <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>
        @break
    @case('eye-off')
        <path d="m3 3 18 18"/><path d="M10.6 10.6a2 2 0 0 0 2.8 2.8"/><path d="M9.9 5.2A10.7 10.7 0 0 1 12 5c6.5 0 10 7 10 7a14 14 0 0 1-3.1 3.9M6.2 6.2A16 16 0 0 0 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4.1-.8"/>
        @break
    @case('kitchen')
        <path d="M8 10a4 4 0 0 1 8 0"/><path d="M6 10h12v2a6 6 0 0 1-12 0z"/><path d="M12 4v2M9 5v2M15 5v2"/>
        @break
    @case('cash')
        <rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M7 10v4M17 10v4"/>
        @break
    @case('waiter')
        <circle cx="12" cy="5" r="2"/><path d="M8 22V12h8v10"/><path d="M5 12h14"/>
        @break
    @case('refresh')
        <path d="M20 12a8 8 0 1 1-2.3-5.6"/><path d="M20 4v6h-6"/>
        @break
    @case('clock')
        <circle cx="12" cy="12" r="8"/><path d="M12 8v5l3 2"/>
        @break
    @case('check')
        <circle cx="12" cy="12" r="8"/><path d="M8.5 12.5 11 15l4.5-5"/>
        @break
    @case('flame')
        <path d="M12 3s5 5 5 9a5 5 0 1 1-10 0c0-2 2-4 3-6 1 2 2 2 2 2s-1-3 0-5z"/>
        @break
    @case('order')
        <path d="M7 3h10v18H7z"/><path d="M10 7h4M10 11h4M10 15h2"/>
        @break
    @case('table')
        <path d="M4 10h16v2H4z"/><path d="M7 12v8M17 12v8M12 12v8"/>
        @break
    @case('staff')
        <circle cx="9" cy="8" r="3"/><path d="M3 20c.7-3.1 2.7-4.8 6-4.8s5.3 1.7 6 4.8"/><path d="M16 5.5a3 3 0 0 1 0 5.8M18 15c1.7.7 2.6 2.2 3 5"/>
        @break
    @case('finance')
        <rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 9h18M7 15h4"/>
        @break
    @case('reports')
        <path d="M4 20V4M4 20h17"/><path d="m7 15 4-4 3 2 5-6"/>
        @break
    @case('settings')
        <circle cx="12" cy="12" r="3"/><path d="m19.4 15 .1.1 1.4 1.1-1.4 2.4-1.7-.7a8 8 0 0 1-1.8 1l-.3 1.8h-2.8l-.3-1.8a8 8 0 0 1-1.8-1l-1.7.7-1.4-2.4 1.4-1.1a7 7 0 0 1 0-2l-1.4-1.1 1.4-2.4 1.7.7a8 8 0 0 1 1.8-1l.3-1.8h2.8l.3 1.8a8 8 0 0 1 1.8 1l1.7-.7 1.4 2.4-1.4 1.1a7 7 0 0 1 0 2z"/>
        @break
    @default
        <circle cx="12" cy="12" r="8"/>
@endswitch
</svg>
