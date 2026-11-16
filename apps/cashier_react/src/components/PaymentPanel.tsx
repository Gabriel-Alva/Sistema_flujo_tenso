import { FormEvent, useState } from 'react';
import { Account, Order, OrderLine, PaymentMethod, ReceiptResponse, ReceiptType } from '../core/types';

type Props = {
  order: Order | null;
  account?: Account;
  items?: OrderLine[];
  accountError?: string;
  loading: boolean;
  sessionOpen: boolean;
  busy: boolean;
  phase: 'idle' | 'receipt' | 'payment';
  error?: string;
  onRetry?: () => void;
  receipt?: ReceiptResponse;
  receiptLocked?: boolean;
  onPay: (details: { receiptType: ReceiptType; method: PaymentMethod; amountReceived?: number }) => void;
};

const receiptTypes: { value: ReceiptType; label: string }[] = [
  { value: 'BOLETA', label: 'Boleta' },
  { value: 'FACTURA', label: 'Factura' },
  { value: 'NOTA_VENTA', label: 'Nota de venta' },
];

const paymentMethods: { value: PaymentMethod; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'TARJETA', label: 'Tarjeta' },
  { value: 'YAPE', label: 'Yape' },
  { value: 'PLIN', label: 'Plin' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
];

export function PaymentPanel({
  order, account, items = [], accountError, loading, sessionOpen, busy, phase, error, onRetry, receipt, receiptLocked, onPay,
}: Props) {
  const [receiptType, setReceiptType] = useState<ReceiptType>('BOLETA');
  const [method, setMethod] = useState<PaymentMethod>('EFECTIVO');
  const [amountReceived, setAmountReceived] = useState('');
  const parsedTotal = Number(account?.saldo_pendiente ?? account?.total ?? 0);
  const total = Number.isFinite(parsedTotal) ? parsedTotal : 0;
  const visibleItems = items.filter((item) => item.id_detalle !== null && item.estado_item !== 'CANCELADO');

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    onPay({
      receiptType,
      method,
      amountReceived: method === 'EFECTIVO' ? Number(amountReceived) : undefined,
    });
  }

  return (
    <section className="card payment-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">COBRO</p>
          <h2>{order ? `Pedido #${order.id_pedido}` : 'Detalle de cuenta'}</h2>
        </div>
      </div>

      {!order ? (
        <div className="empty-state payment-empty">
          <span className="empty-icon">S/</span>
          <strong>Selecciona una cuenta</strong>
          <p className="muted">El total y las opciones de cobro se mostrarán aquí.</p>
        </div>
      ) : loading ? (
        <p className="muted">Calculando total de la cuenta…</p>
      ) : accountError ? (
        <p className="notice notice--error" role="alert">{accountError} <button className="text-button" type="button" onClick={onRetry}>Reintentar</button></p>
      ) : !account ? (
        <p className="muted">No hay información de cuenta disponible.</p>
      ) : (
        <>
          <div className="total-block">
            <span>Saldo pendiente</span>
            <strong>{formatCurrency(total)}</strong>
            <div className="total-breakdown">
              <span>Base imponible <b>{formatCurrency(account.base_imponible)}</b></span>
              <span>Impuestos <b>{formatCurrency(account.impuestos)}</b></span>
              <span>Total de cuenta <b>{formatCurrency(account.total)}</b></span>
              {Number(account.total_pagado ?? 0) > 0 && (
                <span>Pagado <b>{formatCurrency(account.total_pagado ?? 0)}</b></span>
              )}
            </div>
          </div>
          <section className="bill-items" aria-label="Detalle de productos">
            <h3>Productos</h3>
            {visibleItems.length ? (
              <ul>
                {visibleItems.map((item) => {
                  const quantity = Number(item.cantidad ?? 0);
                  const unitPrice = Number(item.precio_unitario_venta ?? 0);
                  return (
                    <li key={item.id_detalle}>
                      <span className="bill-item-name">
                        <strong>{quantity} × {item.nombre_snapshot || 'Producto'}</strong>
                        {item.nota && <small>{item.nota}</small>}
                      </span>
                      <span>{formatCurrency(quantity * unitPrice)}</span>
                    </li>
                  );
                })}
              </ul>
            ) : (
              <p className="muted">No hay productos activos en esta cuenta.</p>
            )}
          </section>
          {!sessionOpen && (
            <p className="notice notice--warning">Abre una sesión de caja antes de registrar el pago.</p>
          )}
          {receipt && (
            <p className="notice notice--success">
              Comprobante {receipt.serie}-{String(receipt.correlativo).padStart(8, '0')} emitido.
              Se conservará para reintentar el pago.
            </p>
          )}
          {error && <p className="notice notice--error" role="alert">{error}</p>}
          <form className="payment-form" onSubmit={submit}>
            <label className="form-field">
              Comprobante
              <select
                value={receiptType}
                disabled={busy || Boolean(receipt) || Boolean(receiptLocked)}
                onChange={(event) => setReceiptType(event.target.value as ReceiptType)}
              >
                {receiptTypes.map((option) => (
                  <option key={option.value} value={option.value} disabled={option.value === 'FACTURA'}>
                    {option.value === 'FACTURA' ? 'Factura (requiere cliente con RUC)' : option.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="form-field">
              Medio de pago
              <select value={method} disabled={busy} onChange={(event) => setMethod(event.target.value as PaymentMethod)}>
                {paymentMethods.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
              </select>
            </label>
            {method === 'EFECTIVO' && (
              <label className="form-field">
                Efectivo recibido (S/)
                <input
                  type="number"
                  min={total}
                  step="0.01"
                  required
                  value={amountReceived}
                  onChange={(event) => setAmountReceived(event.target.value)}
                />
              </label>
            )}
            <button
              className="button button--primary button--wide"
              type="submit"
              disabled={!sessionOpen || busy || total <= 0 || (method === 'EFECTIVO' && Number(amountReceived) < total)}
            >
              {phase === 'receipt' ? 'Emitiendo comprobante…' : phase === 'payment' ? 'Registrando pago…' : 'Emitir comprobante y cobrar'}
            </button>
            {busy && <p className="muted retry-hint">No cierres esta pantalla mientras se confirma la operación.</p>}
          </form>
        </>
      )}
    </section>
  );
}

function formatCurrency(value: string | number) {
  return new Intl.NumberFormat('es-PE', { style: 'currency', currency: 'PEN' }).format(Number(value) || 0);
}
