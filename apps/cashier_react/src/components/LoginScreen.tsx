import { FormEvent, useState } from 'react';
import { SipanIcon } from '../shared/SipanIcon';

type Props = {
  busy: boolean;
  error?: string;
  restoreError?: string;
  onRetryRestore?: () => void;
  onLogin: (username: string, password: string) => void;
};

const rememberedUsernameKey = 'sipan.cashier.remembered-username';

function readRememberedUsername() {
  try {
    return { username: localStorage.getItem(rememberedUsernameKey) ?? '', unavailable: false };
  } catch {
    return { username: '', unavailable: true };
  }
}

export function LoginScreen({ busy, error, restoreError, onRetryRestore, onLogin }: Props) {
  const [savedLogin] = useState(readRememberedUsername);
  const [username, setUsername] = useState(savedLogin.username);
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberUsername, setRememberUsername] = useState(Boolean(savedLogin.username));
  const [storageWarning, setStorageWarning] = useState(savedLogin.unavailable
    ? 'Este navegador no permite recordar el usuario.'
    : '');

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    try {
      if (rememberUsername) {
        localStorage.setItem(rememberedUsernameKey, username.trim());
      } else {
        localStorage.removeItem(rememberedUsernameKey);
      }
      setStorageWarning('');
    } catch {
      setStorageWarning('No se pudo guardar el usuario en este navegador.');
    }
    onLogin(username.trim(), password);
  }

  function toggleRememberUsername(remember: boolean) {
    setRememberUsername(remember);
    if (!remember) {
      try {
        localStorage.removeItem(rememberedUsernameKey);
        setStorageWarning('');
      } catch {
        setStorageWarning('No se pudo borrar el usuario guardado en este navegador.');
      }
    }
  }

  return (
    <main className="login-page">
      <form className="login-card" onSubmit={submit}>
        <div className="login-mark"><SipanIcon name="cash" size={34} /></div>
        <p className="eyebrow">CHIFA SIPÁN · OPERACIONES</p>
        <h1>Terminal de caja</h1>
        <p className="muted">Ingresa con tu cuenta de cajero para comenzar.</p>
        {restoreError && (
          <p className="notice notice--error" role="alert">
            {restoreError} <button className="text-button" type="button" onClick={onRetryRestore}>Reintentar</button>
          </p>
        )}
        <label className="form-field">
          Usuario
          <input
            name="username"
            autoComplete="username"
            autoFocus
            required
            value={username}
            onChange={(event) => setUsername(event.target.value)}
          />
        </label>
        <label className="form-field">
          Contraseña
          <span className="login-password-field">
            <input
              id="login-password"
              name="password"
              autoComplete="current-password"
              required
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
            <button
              className="password-toggle"
              type="button"
              aria-label={showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'}
              aria-pressed={showPassword}
              aria-controls="login-password"
              onClick={() => setShowPassword((visible) => !visible)}
            >
              <SipanIcon name={showPassword ? 'eye-off' : 'eye'} size={18} />
            </button>
          </span>
        </label>
        <label className="remember-option">
          <input
            checked={rememberUsername}
            type="checkbox"
            onChange={(event) => toggleRememberUsername(event.target.checked)}
          />
          <span>Recordar usuario en este dispositivo</span>
        </label>
        <p className="credential-note">La contraseña no se guarda en la aplicación. Puedes guardarla de forma segura con tu navegador.</p>
        {storageWarning && <p className="storage-warning" role="status">{storageWarning}</p>}
        {error && <p className="notice notice--error" role="alert">{error}</p>}
        <button className="button button--primary button--wide" disabled={busy} type="submit">
          {busy ? 'Validando…' : 'Iniciar sesión'}
        </button>
      </form>
    </main>
  );
}
