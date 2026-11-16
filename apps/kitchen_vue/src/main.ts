import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';
import LoginView from './views/LoginView.vue';
import StationBoardView from './views/StationBoardView.vue';
import { useAuthStore } from './stores/auth.store';
import { useQueueStore } from './stores/queue.store';
import { setRefreshHandler, setUnauthorizedHandler } from './core/api';
import './styles.css';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'login', component: LoginView },
    { path: '/estacion', name: 'station', component: StationBoardView, meta: { requiresAuth: true } },
  ],
});

const pinia = createPinia();
const app = createApp(App);
app.use(pinia).use(router);

const auth = useAuthStore(pinia);
const queue = useQueueStore(pinia);
setRefreshHandler(() => auth.refreshSession());
setUnauthorizedHandler(() => {
  auth.logout();
  queue.$reset();
  void router.replace({ name: 'login' });
});

router.beforeEach(async (to) => {
  if (!auth.token && !auth.restoreAttempted) await auth.restoreSession();
  const authenticated = Boolean(auth.token && auth.stationId);
  if (to.meta.requiresAuth && !authenticated) return { name: 'login' };
  if (to.name === 'login' && authenticated) return { name: 'station' };
});

app.mount('#app');
