import { FormEvent, useState } from 'react';
import { CashSession, CashSummary } from '../core/types';

type Props = {
  session: CashSession | null;
  summary?: CashSummary | null;
  loading: boolean;
  busy: boolean;
  locked?: boolean;
  error?: string;
  loadError?: string;
  onRetry?: () => void;
  onOpen: (amount: number, notes: string) => void;
  onClose: (sessionId: number, amount: number, notes: string) => void;
};

export function CashSessionPanel({
  session, summary, loading, busy, locked = false, error, loadError, onRetry, onOpen, onClose,
}: Props) {
  const [openingAmount, setOpeningAmount] = useState('');
  const [openingNotes, setOpeningNotes] = useState('');
  const [closingAmount, setClosingAmount] = useState('');
  const [closingNotes, setClosingNotes] = useState('');
  const expectedCash = Number(summary?.saldo_teorico_gaveta ?? session?.monto_apertura ?? 0);
  const declaredCash = Number(closingAmount);
  const difference = Math.round((declaredCash - expectedCash) * 100) / 100;
  const closingHasDifference = closingAmount !== '' && Number.isFinite(difference) && Math.abs(difference) >= 0.01;

  function open(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    onOpen(Number(openingAmount), openingNotes.trim());
  }

  function close(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (session) onClose(session.id_caja_sesion, Number(closingAmount), closingNotes.trim());
  }

  return (
    <section className="card session-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">CONTROL DE CAJA</p>
          <h2>Sesión de caja</h2>
        </div>
        <span className={`status-pill ${session ? 'status-pill--open' : 'status-pill--closed'}`}>
          {loading ? 'Consultando…' : session ? 'Abierta' : 'Cerrada'}
        </span>
      </div>

      {loadError && <p className="notice notice--error" role="alert">{loadError} <button className="text-button" type="button" onClick={onRetry}>Reintentar</button></p>}
      {error && <p className="notice notice--error" role="alert">{error}</p>}
      {loading || loadError ? (
        <p className="muted">{loadError ? 'No fue posible consultar la sesión.' : 'Consultando la sesión actual…'}</p>
      ) : session ? (
        <>
          {locked && <p className="notice notice--warning">Completa o reintenta el cobro seleccionado antes de cerrar la caja.</p>}
          <div className="session-summary">
            <span>Sesión #{session.id_caja_sesion}{session.apertura_en ? ` · ${formatDate(session.apertura_en)}` : ''}</span>
            <strong>{formatCurrency(session.monto_apertura)}</strong>
            <small>Monto de apertura</small>
          </div>
          <div className="cash-summary-grid">
            <div className="cash-summary-item cash-summary-item--highlight">
              <span>Efectivo teórico en gaveta</span>
              <strong>{formatCurrency(summary?.saldo_teorico_gaveta ?? session.monto_apertura)}</strong>
            </div>
            <div className="cash-summary-item"><span>Ventas en efectivo</span><strong>{formatCurrency(summary?.total_efectivo ?? 0)}</strong></div>
            <div className="cash-summary-item"><span>Tarjeta</span><strong>{formatCurrency(summary?.total_tarjeta ?? 0)}</strong></div>
            <div className="cash-summary-item"><span>Yape / Plin / transferencia</span><strong>{formatCurrency(Number(summary?.total_yape ?? 0) + Number(summary?.total_plin ?? 0) + Number(summary?.total_transferencia ?? 0))}</strong></div>
            <div className="cash-summary-item"><span>Ingresos / egresos</span><strong>{formatCurrency(summary?.movimientos_ingreso ?? 0)} / {formatCurrency(summary?.movimientos_egreso ?? 0)}</strong></div>
          </div>
          <form className="inline-form" onSubmit={close}>
            <label className="form-field">
              Efectivo contado al cierre (S/)
              <input
                type="number"
                min="0"
                step="0.01"
                required
                value={closingAmount}
                onChange={(event) => setClosingAmount(event.target.value)}
              />
            </label>
            <label className="form-field">
              Observaciones {closingHasDifference ? <span className="required-hint">(obligatorias por diferencia)</span> : <span className="optional">(opcional)</span>}
              <input
                maxLength={2000}
                required={closingHasDifference}
                value={closingNotes}
                onChange={(event) => setClosingNotes(event.target.value)}
              />
            </label>
            {closingAmount !== '' && (
              <p className={`closing-difference ${closingHasDifference ? 'closing-difference--warning' : ''}`}>
                Diferencia de arqueo: {formatCurrency(difference)}
              </p>
            )}
            <button className="button button--secondary" type="submit" disabled={busy || locked}>
              {busy ? 'Procesando…' : locked ? 'Cobro pendiente' : 'Cerrar caja'}
            </button>
          </form>
        </>
      ) : (
        <form className="inline-form" onSubmit={open}>
          <p className="muted form-intro">Registra el fondo inicial para habilitar el cobro de cuentas.</p>
          <label className="form-field">
            Fondo de apertura (S/)
            <input
              type="number"
              min="0"
              step="0.01"
              required
              value={openingAmount}
              onChange={(event) => setOpeningAmount(event.target.value)}
            />
          </label>
          <label className="form-field">
            Observaciones <span className="optional">(opcional)</span>
            <input value={openingNotes} onChange={(event) => setOpeningNotes(event.target.value)} />
          </label>
          <button className="button button--primary" type="submit" disabled={busy}>
            {busy ? 'Procesando…' : 'Abrir caja'}
          </button>
        </form>
      )}
    </section>
  );
}

function formatCurrency(value: string | number) {
  return new Intl.NumberFormat('es-PE', { style: 'currency', currency: 'PEN' }).format(Number(value) || 0);
}

function formatDate(value: string) {
  const date = new Date(value.replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString('es-PE');
}
