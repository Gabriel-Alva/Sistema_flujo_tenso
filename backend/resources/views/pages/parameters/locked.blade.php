@extends('layouts.admin')
@section('title', 'Parámetros del sistema')
@section('content')
<section class="panel parameter-gate">
    <div class="parameter-gate__icon"><x-icon name="lock" size="32" /></div>
    <h2>Área protegida</h2>
    <p>Confirma la contraseña de tu cuenta administradora para consultar o cambiar parámetros del sistema.</p>
    <form class="parameter-gate__form" method="post" action="{{ route('admin.parameters.unlock') }}">
        @csrf
        <label for="parameter-password">Contraseña actual</label>
        <div class="parameter-gate__password-field">
            <input id="parameter-password" type="password" name="password" autocomplete="current-password" required>
            <button class="password-toggle" type="button" aria-controls="parameter-password" aria-pressed="false" aria-label="Mostrar contraseña">
                <span data-eye-show><x-icon name="eye" /></span>
                <span data-eye-hide hidden><x-icon name="eye-off" /></span>
            </button>
        </div>
        @error('password')
            <span class="error" role="alert">{{ $message }}</span>
        @enderror
        <button class="btn-primary btn-primary--teal" type="submit">Verificar y continuar</button>
    </form>
    <small>El acceso se bloquea automáticamente después de 10 minutos.</small>
</section>
@endsection
