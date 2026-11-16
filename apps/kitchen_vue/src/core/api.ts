import axios, { type InternalAxiosRequestConfig } from 'axios';

type RetriableRequestConfig = InternalAxiosRequestConfig & { _sipanRetried?: boolean };

let accessToken: string | null = null;
let unauthorizedHandler: (() => void) | null = null;
let refreshHandler: (() => Promise<void>) | null = null;
let refreshPromise: Promise<void> | null = null;

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || 'http://localhost:8000/api/v1',
  withCredentials: true,
});

function isAuthEndpoint(url?: string) {
  return /\/auth\/(?:login|refresh)(?:$|\?)/.test(url ?? '');
}

api.interceptors.request.use((config) => {
  if (accessToken && !isAuthEndpoint(config.url)) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error: unknown) => {
    if (!axios.isAxiosError(error) || error.response?.status !== 401 || !error.config) {
      return Promise.reject(error);
    }

    const request = error.config as RetriableRequestConfig;
    if (isAuthEndpoint(request.url)) {
      return Promise.reject(error);
    }
    if (request._sipanRetried) {
      setAccessToken(null);
      unauthorizedHandler?.();
      return Promise.reject(error);
    }

    request._sipanRetried = true;
    try {
      await refreshAccessToken();
      if (!accessToken) throw new Error('No se pudo renovar la sesión.');
      request.headers.Authorization = `Bearer ${accessToken}`;
      return await api.request(request);
    } catch (refreshError) {
      if (axios.isAxiosError(refreshError) && refreshError.response?.status === 401) {
        setAccessToken(null);
        unauthorizedHandler?.();
      }
      return Promise.reject(refreshError);
    }
  },
);

export function setAccessToken(token: string | null) {
  accessToken = token;
}

export function setUnauthorizedHandler(handler: (() => void) | null) {
  unauthorizedHandler = handler;
}

export function setRefreshHandler(handler: (() => Promise<void>) | null) {
  refreshHandler = handler;
}

export function refreshAccessToken(): Promise<void> {
  if (!refreshHandler) return Promise.reject(new Error('No está disponible la renovación de sesión.'));
  if (!refreshPromise) {
    refreshPromise = Promise.resolve()
      .then(() => refreshHandler?.())
      .then(() => undefined)
      .finally(() => {
        refreshPromise = null;
      });
  }
  return refreshPromise;
}

export function getApiErrorMessage(error: unknown, fallback: string): string {
  if (axios.isAxiosError(error)) {
    const body = error.response?.data as { message?: unknown; detail?: unknown } | undefined;
    if (typeof body?.message === 'string' && body.message.trim()) return body.message;
    if (typeof body?.detail === 'string' && body.detail.trim()) return body.detail;
    if (!error.response) return 'No se pudo conectar con el servidor.';
  }
  return fallback;
}
