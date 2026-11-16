import { FormEvent, useState } from 'react';
import { CashMovementType } from '../core/types';

type Props = {
  sessionOpen: boolean;
  busy: boolean;
  locked?: boolean;
  error?: string;
  onRecord: (type: CashMovementType, amount: number, reason: string) => Promise<boolean>;
};

export function CashMovementPanel({ sessionOpen, busy, locked = false, error, onRecord }: Props) {
  const [type, setType] = useState<CashMovementType>('INGRESO');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const saved = await onRecord(type, Number(amount), reason.trim());
    if (saved) {
      setAmount('');
      setReason('');
    }
  }

  return (
    <section className="card movement-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">OPERACIÓN DE CAJA</p>
          <h2>Registrar movimiento</h2>
        </div>
        <span className="movement-symbol" aria-hidden>{type === 'INGRESO' ? '+' : '−'}</span>
      </div>
      {error && <p className="notice notice--error" role="alert">{error}</p>}
      {!sessionOpen ? (
        <p className="notice notice--warning">Abre una sesión para registrar ingresos o egresos.</p>
      ) : (
        <>
          {locked && <p className="notice notice--warning">Termina o reintenta el cobro pendiente antes de registrar otro movimiento.</p>}
          <form className="movement-form" onSubmit={submit}>
            <label className="form-field">
              Tipo
              <select value={type} disabled={busy || locked} onChange={(event) => setType(event.target.value as CashMovementType)}>
                <option value="INGRESO">Ingreso a caja</option>
                <option value="EGRESO">Egreso de caja</option>
              </select>
            </label>
            <label className="form-field">
              Monto (S/)
              <input
                type="number"
                min="0.01"
                max="9999999999.99"
                step="0.01"
                required
                value={amount}
                disabled={busy || locked}
                onChange={(event) => setAmount(event.target.value)}
              />
            </label>
            <label className="form-field movement-reason">
              Motivo
              <input
                maxLength={180}
                required
                value={reason}
                disabled={busy || locked}
                placeholder={type === 'INGRESO' ? 'Ej.: reposición de sencillo' : 'Ej.: compra de insumos'}
                onChange={(event) => setReason(event.target.value)}
              />
            </label>
            <button className="button button--secondary" type="submit" disabled={busy || locked}>
              {busy ? 'Guardando…' : `Registrar ${type === 'INGRESO' ? 'ingreso' : 'egreso'}`}
            </button>
          </form>
        </>
      )}
    </section>
  );
}
