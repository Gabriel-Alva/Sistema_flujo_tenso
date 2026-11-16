<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Admin') — Chifa Sipán</title>
    <link rel="icon" type="image/jpeg" href="{{ asset('images/logo.jpg') }}">
    <link rel="apple-touch-icon" href="{{ asset('images/logo.jpg') }}">
    <link rel="stylesheet" href="{{ asset('css/sipan.css') }}">
</head>
<body>
<div class="shell">
    <aside class="sidebar">
        <div class="brand">
            <x-icon name="logo" size="28" class="sipan-icon sipan-icon--lg" />
            <div>Chifa Sipán<small>Administración</small></div>
        </div>
        <nav>
            <a class="nav-link {{ request()->routeIs('admin.dashboard') ? 'is-active' : '' }}" href="{{ route('admin.dashboard') }}">
                <x-icon name="dashboard" /> Dashboard
            </a>
            <a class="nav-link {{ request()->routeIs('admin.catalog') ? 'is-active' : '' }}" href="{{ route('admin.catalog') }}">
                <x-icon name="catalog" /> Catálogo
            </a>
            <a class="nav-link {{ request()->routeIs('admin.salon') ? 'is-active' : '' }}" href="{{ route('admin.salon') }}">
                <x-icon name="salon" /> Salón
            </a>
            <a class="nav-link {{ request()->routeIs('admin.staff*') ? 'is-active' : '' }}" href="{{ route('admin.staff') }}">
                <x-icon name="staff" /> Personal
            </a>
            <a class="nav-link {{ request()->routeIs('admin.finance') ? 'is-active' : '' }}" href="{{ route('admin.finance') }}">
                <x-icon name="finance" /> Finanzas
            </a>
            <a class="nav-link {{ request()->routeIs('admin.reports') ? 'is-active' : '' }}" href="{{ route('admin.reports') }}">
                <x-icon name="reports" /> Reportes
            </a>
            <a class="nav-link {{ request()->routeIs('admin.audit') ? 'is-active' : '' }}" href="{{ route('admin.audit') }}">
                <x-icon name="audit" /> Auditoría
            </a>
            <a class="nav-link {{ request()->routeIs('admin.parameters*') ? 'is-active' : '' }}" href="{{ route('admin.parameters') }}">
                <x-icon name="settings" /> Parámetros
            </a>
        </nav>
        <form class="logout" method="post" action="{{ route('logout') }}">
            @csrf
            <button type="submit"><x-icon name="logout" /> Salir</button>
        </form>
    </aside>
    <main class="content">
        <header class="topbar">
            <h1>@yield('title')</h1>
            <span class="user-chip"><x-icon name="user" /> {{ auth()->user()?->username }}</span>
        </header>
        @if (session('status'))
            <div class="notice notice--success" role="status">{{ session('status') }}</div>
        @endif
        @if ($errors->any())
            <div class="notice notice--error" role="alert">
                <strong>Revisa los datos ingresados:</strong>
                <ul>
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif
        @yield('content')
    </main>
</div>
<dialog class="admin-modal" id="admin-confirm-dialog" aria-labelledby="admin-confirm-title">
    <section class="admin-modal__content admin-modal__content--compact">
        <header class="admin-modal__header">
            <div><p class="eyebrow">Confirmación</p><h2 id="admin-confirm-title">¿Continuar con esta acción?</h2></div>
            <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
        </header>
        <p data-confirm-message>Confirma para continuar.</p>
        <footer class="admin-modal__footer">
            <button class="btn-secondary" type="button" data-modal-close>Cancelar</button>
            <button class="btn-primary" type="button" data-confirm-accept>Confirmar</button>
        </footer>
    </section>
</dialog>
<script src="{{ asset('js/admin-ui.js') }}" defer></script>
</body>
</html>
