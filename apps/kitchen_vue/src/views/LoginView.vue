<template>
  <div class="login-body kds-login">
    <form class="login-card kds-card" @submit.prevent="onSubmit">
      <div class="login-mark">
        <img src="/favicon.png" alt="Logo de Chifa Sipán" width="64" height="64" />
      </div>
      <div class="login-intro">
        <p class="login-eyebrow">CHIFA SIPÁN · OPERACIONES</p>
        <h1>Monitor de cocina</h1>
        <p class="lead">Inicia sesión con tu cuenta de cocinero para acceder a tu estación.</p>
      </div>
      <label for="login-username">Usuario
        <div class="field">
          <SipanIcon name="user" />
          <input id="login-username" v-model="username" name="username" autocomplete="username" autofocus required />
        </div>
      </label>
      <label for="login-password">Contraseña
        <div class="field">
          <SipanIcon name="lock" />
          <input id="login-password" v-model="password" name="password" :type="showPassword ? 'text' : 'password'" autocomplete="current-password" required />
          <button
            class="password-toggle"
            type="button"
            :aria-label="showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'"
            :aria-pressed="showPassword"
            aria-controls="login-password"
            @click="showPassword = !showPassword"
          >
            <SipanIcon :name="showPassword ? 'eye-off' : 'eye'" :size="18" />
          </button>
        </div>
      </label>
      <label class="remember-option">
        <input v-model="rememberUsername" type="checkbox" />
        <span>Recordar usuario en este dispositivo</span>
      </label>
      <p class="credential-note">La contraseña no se guarda en la aplicación. Puedes guardarla de forma segura con tu navegador.</p>
      <p v-if="storageWarning" class="storage-warning" role="status">{{ storageWarning }}</p>
      <p v-if="auth.restoreError" class="error" role="alert">
        {{ auth.restoreError }}
        <button class="btn-ghost" type="button" @click="onRetryRestore">Reintentar restauración</button>
      </p>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
      <button class="btn-primary" type="submit" :disabled="loading">
        <SipanIcon name="check" /> {{ loading ? 'Validando…' : 'Iniciar sesión' }}
      </button>
    </form>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { getApiErrorMessage } from '../core/api';
import { useAuthStore } from '../stores/auth.store';
import SipanIcon from '../components/SipanIcon.vue';

const username = ref('');
const password = ref('');
const showPassword = ref(false);
const rememberUsername = ref(false);
const storageWarning = ref('');
const error = ref('');
const loading = ref(false);
const auth = useAuthStore();
const router = useRouter();
const rememberedUsernameKey = 'sipan.kitchen.remembered-username';

onMounted(() => {
  try {
    const savedUsername = localStorage.getItem(rememberedUsernameKey);
    if (savedUsername) {
      username.value = savedUsername;
      rememberUsername.value = true;
    }
  } catch {
    storageWarning.value = 'Este navegador no permite recordar el usuario.';
  }
});

function updateRememberedUsername() {
  try {
    if (rememberUsername.value) {
      localStorage.setItem(rememberedUsernameKey, username.value.trim());
    } else {
      localStorage.removeItem(rememberedUsernameKey);
    }
    storageWarning.value = '';
  } catch {
    storageWarning.value = 'No se pudo guardar el usuario en este navegador.';
  }
}

async function onSubmit() {
  if (loading.value) return;
  error.value = '';
  updateRememberedUsername();
  loading.value = true;
  try {
    await auth.login(username.value.trim(), password.value);
    await router.replace({ name: 'station' });
  } catch (cause) {
    error.value = getApiErrorMessage(cause, 'No se pudo iniciar sesión. Verifica tus credenciales y la estación asignada.');
  } finally {
    loading.value = false;
  }
}

async function onRetryRestore() {
  await auth.retryRestore();
  if (auth.token && auth.stationId) await router.replace({ name: 'station' });
}
</script>
