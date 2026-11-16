import { useEffect } from 'react';
import { Account, Order, OrderLine, PaymentMethod, ReceiptResponse, ReceiptType } from '../core/types';
import { SipanIcon } from '../shared/SipanIcon';

type Props = {
  receipt: ReceiptResponse;
  receiptType: ReceiptType;
  order: Order;
  account: Account;
  items: OrderLine[];
  method: PaymentMethod;
  amountReceived?: number;
  change: number;
  onClose: () => void;
};

const receiptLabels: Record<ReceiptType, string> = {
  BOLETA: 'Boleta de venta',
  FACTURA: 'Factura',
  NOTA_VENTA: 'Nota de venta',
};

const paymentLabels: Record<PaymentMethod, string> = {
  EFECTIVO: 'Efectivo',
  TARJETA: 'Tarjeta',
  YAPE: 'Yape',
  PLIN: 'Plin',
  TRANSFERENCIA: 'Transferencia',
};

export function ReceiptPreview({
  receipt, receiptType, order, account, items, method, amountReceived, change, onClose,
}: Props) {
  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') onClose();
    }

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const activeItems = items.filter((item) => item.id_detalle !== null && item.estado_item !== 'CANCELADO');

  return (
    <div className="receipt-backdrop" onMouseDown={(event) => {
      if (event.target === event.currentTarget) onClose();
    }}>
      <section className="receipt-dialog" role="dialog" aria-modal="true" aria-labelledby="receipt-title">
        <div className="receipt-toolbar">
          <div>
            <p className="eyebrow">PAGO REGISTRADO</p>
            <h2 id="receipt-title">Comprobante</h2>
          </div>
          <div className="receipt-toolbar-actions">
            <button className="button button--primary" type="button" onClick={() => window.print()}>
              <SipanIcon name="printer" size={17} /> Imprimir
            </button>
            <button className="button button--secondary" type="button" onClick={onClose}>Cerrar</button>
          </div>
        </div>
        <article className="receipt-paper">
          <header className="receipt-brand">
            <span className="brand-mark"><SipanIcon name="cash" size={22} /></span>
            <div><strong>CHIFA SIPÁN</strong><small>Comprobante de pago</small></div>
          </header>
          <div className="receipt-title">
            <strong>{receiptLabels[receiptType]}</strong>
            <span>{receipt.serie}-{String(receipt.correlativo).padStart(8, '0')}</span>
          </div>
          <dl className="receipt-meta">
            <div><dt>Pedido</dt><dd>#{order.id_pedido}</dd></div>
            <div><dt>Tipo de pedido</dt><dd>{order.tipo}</dd></div>
            {order.numero_mesa && <div><dt>Mesa</dt><dd>{order.numero_mesa}</dd></div>}
            <div><dt>Fecha de pago</dt><dd>{new Date().toLocaleString('es-PE')}</dd></div>
          </dl>
          <div className="receipt-lines">
            <div className="receipt-lines-heading"><span>Descripción</span><span>Importe</span></div>
            {activeItems.map((item) => {
              const quantity = Number(item.cantidad ?? 0);
              const unitPrice = Number(item.precio_unitario_venta ?? 0);
              return (
                <div className="receipt-line" key={item.id_detalle}>
                  <span>{quantity} × {item.nombre_snapshot || 'Producto'}</span>
                  <strong>{formatCurrency(quantity * unitPrice)}</strong>
                </div>
              );
            })}
          </div>
          <dl className="receipt-totals">
            <div><dt>Base imponible</dt><dd>{formatCurrency(account.base_imponible)}</dd></div>
            <div><dt>Impuestos</dt><dd>{formatCurrency(account.impuestos)}</dd></div>
            {Number(account.total_pagado ?? 0) > 0 && (
              <div><dt>Pagado anteriormente</dt><dd>{formatCurrency(account.total_pagado ?? 0)}</dd></div>
            )}
            <div className="receipt-total"><dt>Total de la cuenta</dt><dd>{formatCurrency(account.total)}</dd></div>
            <div className="receipt-total"><dt>Pago registrado</dt><dd>{formatCurrency(account.saldo_pendiente ?? account.total)}</dd></div>
          </dl>
          <footer className="receipt-payment">
            <div><span>Medio de pago</span><strong>{paymentLabels[method]}</strong></div>
            {amountReceived !== undefined && <div><span>Recibido</span><strong>{formatCurrency(amountReceived)}</strong></div>}
            {amountReceived !== undefined && <div><span>Vuelto</span><strong>{formatCurrency(change)}</strong></div>}
            <p>Gracias por su preferencia.</p>
          </footer>
        </article>
      </section>
    </div>
  );
}

function formatCurrency(value: string | number) {
  return new Intl.NumberFormat('es-PE', { style: 'currency', currency: 'PEN' }).format(Number(value) || 0);
}
