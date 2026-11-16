import { LoginResponse } from './types';

const base = import.meta.env.VITE_API_BASE ?? 'http://localhost:8000/api/v1';

let accessToken: string | null = null;
let refreshInFlight: Promise<LoginResponse> | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export async function restoreSession(): Promise<LoginResponse> {
  return refreshAccessToken();
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  return request<T>(path, options, false);
}

async function request<T>(path: string, options: RequestInit, alreadyRetried: boolean): Promise<T> {
  const tokenForRequest = accessToken;
  const headers = new Headers(options.headers);
  headers.set('Accept', 'application/json');
  if (options.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }
  if (tokenForRequest) {
    headers.set('Authorization', `Bearer ${tokenForRequest}`);
  } else {
    headers.delete('Authorization');
  }

  let response: Response;
  try {
    response = await fetch(`${base}${path}`, {
      ...options,
      headers,
      credentials: 'include',
    });
  } catch {
    throw new ApiError('No se pudo conectar con el servidor. Verifica tu conexión e inténtalo nuevamente.', 0);
  }

  const mayRefresh = !path.startsWith('/auth/login') && !path.startsWith('/auth/refresh');
  if (response.status === 401 && mayRefresh && !alreadyRetried) {
    try {
      if (!accessToken || accessToken === tokenForRequest) {
        await refreshAccessToken();
      }
      if (accessToken) return request<T>(path, options, true);
    } catch (error) {
      if (error instanceof ApiError && error.status !== 401) throw error;
    }
    setAccessToken(null);
  }

  return readResponse<T>(response);
}

async function refreshAccessToken(): Promise<LoginResponse> {
  if (!refreshInFlight) {
    refreshInFlight = (async () => {
      let response: Response;
      try {
        response = await fetch(`${base}/auth/refresh`, {
          method: 'POST',
          headers: { Accept: 'application/json' },
          credentials: 'include',
        });
      } catch {
        throw new ApiError('No se pudo renovar la sesión. Verifica tu conexión e inténtalo nuevamente.', 0);
      }

      const data = await readResponse<LoginResponse>(response);
      if (!data?.access_token) {
        throw new ApiError('El servidor no devolvió un token de acceso válido.', 502);
      }
      setAccessToken(data.access_token);
      return data;
    })().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

async function readResponse<T>(response: Response): Promise<T> {
  const payload = await response.json().catch(() => null) as
    | { message?: string; errors?: Record<string, string[]> }
    | null;
  if (!response.ok) {
    const validationMessage = payload?.errors
      ? Object.values(payload.errors).flat()[0]
      : undefined;
    throw new ApiError(
      validationMessage || payload?.message || `La solicitud no se pudo completar (HTTP ${response.status}).`,
      response.status,
    );
  }
  return payload as T;
}
