import { defineStore } from 'pinia';
import axios from 'axios';
import { api, getApiErrorMessage, refreshAccessToken, setAccessToken } from '../core/api';

type LoginResponse = {
  access_token?: unknown;
  station_id?: unknown;
  id_estacion?: unknown;
  user?: {
    persona?: {
      nombres?: unknown;
    };
  };
};

let restorePromise: Promise<boolean> | null = null;

export const useAuthStore = defineStore('auth', {
  state: () => ({
    token: null as string | null,
    stationId: null as number | null,
    nombre: '',
    restoreAttempted: false,
    restoreError: null as string | null,
  }),
  actions: {
    async login(username: string, password: string) {
      this.logout();
      const { data } = await api.post<LoginResponse>('/auth/login', {
        username,
        password,
        context: 'COCINERO',
      });
      this.applyCredentials(data, username);
    },
    async refreshSession() {
      const { data } = await api.post<LoginResponse>('/auth/refresh', {}, { withCredentials: true });
      this.applyCredentials(data, this.nombre || 'Cocina');
    },
    restoreSession(): Promise<boolean> {
      if (this.token && this.stationId) return Promise.resolve(true);
      if (restorePromise) return restorePromise;
      if (this.restoreAttempted) return Promise.resolve(false);
      this.restoreAttempted = true;
      restorePromise = (async () => {
        try {
          await refreshAccessToken();
          this.restoreError = null;
          return Boolean(this.token && this.stationId);
        } catch (error) {
          this.logout();
          if (!axios.isAxiosError(error) || error.response?.status !== 401) {
            this.restoreError = getApiErrorMessage(error, 'No se pudo restaurar la sesión.');
          }
          return false;
        } finally {
          restorePromise = null;
        }
      })();
      return restorePromise;
    },
    async retryRestore() {
      this.restoreAttempted = false;
      return this.restoreSession();
    },
    applyCredentials(data: LoginResponse, fallbackName: string) {
      const token = data.access_token;
      const stationId = Number(data.station_id ?? data.id_estacion);
      if (typeof token !== 'string' || !token.trim() || !Number.isInteger(stationId) || stationId <= 0) {
        throw new Error('La respuesta de autenticación no incluye una estación válida.');
      }

      this.token = token;
      this.stationId = stationId;
      const displayName = data.user?.persona?.nombres;
      this.nombre = typeof displayName === 'string' ? displayName : fallbackName;
      this.restoreError = null;
      setAccessToken(token);
    },
    logout() {
      this.token = null;
      this.stationId = null;
      this.nombre = '';
      this.restoreAttempted = true;
      this.restoreError = null;
      setAccessToken(null);
    },
  },
});
