<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Ingreso administración — Chifa Sipán</title>
    <link rel="icon" type="image/jpeg" href="{{ asset('images/logo.jpg') }}">
    <link rel="apple-touch-icon" href="{{ asset('images/logo.jpg') }}">
    <link rel="stylesheet" href="{{ asset('css/sipan.css') }}">
</head>
<body class="login-body">
<form class="login-card" method="post" action="{{ url('/login') }}" autocomplete="on">
    @csrf
    <div class="login-mark">
        <img src="{{ asset('images/logo.jpg') }}" alt="Logo de Chifa Sipán" width="72" height="72">
    </div>
    <h1>Administración</h1>
    <p class="lead">Chifa Sipán — panel interno</p>
    <label>Usuario
        <div class="field">
            <x-icon name="user" />
            <input name="username" value="{{ old('username') }}" autocomplete="username" required>
        </div>
    </label>
    <label>Contraseña
        <div class="field">
            <x-icon name="lock" />
            <input id="admin-password" type="password" name="password" autocomplete="current-password" required>
            <button
                class="password-toggle"
                type="button"
                aria-label="Mostrar contraseña"
                aria-pressed="false"
                aria-controls="admin-password"
            >
                <span data-eye-show><x-icon name="eye" /></span>
                <span data-eye-hide hidden><x-icon name="eye-off" /></span>
            </button>
        </div>
    </label>
    <label class="remember-option">
        <input type="checkbox" name="remember" value="1" @checked(old('remember'))>
        <span>Recordarme en este dispositivo</span>
    </label>
    @error('username')
        <div class="error" role="alert">{{ $message }}</div>
    @enderror
    @error('password')
        <div class="error" role="alert">{{ $message }}</div>
    @enderror
    <button class="btn-primary" type="submit"><x-icon name="check" /> Iniciar sesión</button>
</form>
<script src="{{ asset('js/admin-login.js') }}" defer></script>
</body>
</html>
