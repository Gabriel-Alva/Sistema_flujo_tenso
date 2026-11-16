import { useState } from 'react';
import { CompletedCashierOrder, Order } from '../core/types';

type Props = {
  orders: Order[];
  completedOrders: CompletedCashierOrder[];
  selectedId: number | null;
  loading: boolean;
  completedLoading: boolean;
  disabled?: boolean;
  error?: string;
  completedError?: string;
  onRetry?: () => void;
  onRetryCompleted?: () => void;
  onSelect: (order: Order) => void;
};

export function OrderList({
  orders, completedOrders, selectedId, loading, completedLoading, disabled = false,
  error, completedError, onRetry, onRetryCompleted, onSelect,
}: Props) {
  const [activeList, setActiveList] = useState<'CONCLUIDAS' | 'PENDIENTES'>('CONCLUIDAS');
  const readyIds = new Set(completedOrders.map((order) => order.id_pedido));
  const pendingOrders = orders.filter((order) => !readyIds.has(order.id_pedido));
  const visibleOrders = activeList === 'CONCLUIDAS'
    ? completedOrders
    : pendingOrders;
  const listLoading = activeList === 'CONCLUIDAS' ? completedLoading : loading;
  const listError = activeList === 'CONCLUIDAS' ? completedError : error;
  const retry = activeList === 'CONCLUIDAS' ? onRetryCompleted : onRetry;

  return (
    <section className="card orders-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">CUENTAS</p>
          <h2>Pedidos por cobrar</h2>
        </div>
      </div>
      <div className="order-tabs" role="tablist" aria-label="Filtrar pedidos por estado de cocina">
        <button
          type="button"
          role="tab"
          aria-selected={activeList === 'CONCLUIDAS'}
          className={activeList === 'CONCLUIDAS' ? 'order-tab order-tab--active' : 'order-tab'}
          onClick={() => setActiveList('CONCLUIDAS')}
        >
          Listas para cobrar <span>{completedOrders.length}</span>
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeList === 'PENDIENTES'}
          className={activeList === 'PENDIENTES' ? 'order-tab order-tab--active' : 'order-tab'}
          onClick={() => setActiveList('PENDIENTES')}
        >
          Otros pedidos <span>{pendingOrders.length}</span>
        </button>
      </div>
      {listError && <p className="notice notice--error" role="alert">{listError} <button className="text-button" type="button" onClick={retry}>Reintentar</button></p>}
      {listLoading ? (
        <p className="muted">Cargando pedidos…</p>
      ) : visibleOrders.length ? (
        <ul className="order-list">
          {visibleOrders.map((order) => {
            const completed = activeList === 'CONCLUIDAS'
              ? completedOrders.find((item) => item.id_pedido === order.id_pedido)
              : undefined;
            return (
              <li key={order.id_pedido}>
                <button
                  type="button"
                  className={`order-row ${selectedId === order.id_pedido ? 'order-row--selected' : ''}`}
                  aria-pressed={selectedId === order.id_pedido}
                  disabled={disabled}
                  onClick={() => onSelect(order)}
                >
                  <span className="order-number">#{order.id_pedido}</span>
                  <span className="order-info">
                    <strong>{order.numero_mesa ? `Mesa ${order.numero_mesa}` : order.tipo || 'Pedido'}</strong>
                    <small>
                      {order.tipo} · {activeList === 'CONCLUIDAS' ? 'Lista para cobrar' : order.estado}
                      {order.fecha ? ` · ${formatDate(order.fecha)}` : ''}
                    </small>
                  </span>
                  {completed && (
                    <span className="order-payment-summary">
                      <small>{completed.items_concluidos} ítems</small>
                      <strong>{formatCurrency(completed.saldo_pendiente)}</strong>
                    </span>
                  )}
                  {activeList === 'CONCLUIDAS' && <span className="ready-badge">Lista</span>}
                  <span className="order-chevron" aria-hidden>›</span>
                </button>
              </li>
            );
          })}
        </ul>
      ) : listError ? null : (
        <div className="empty-state">
          <span className="empty-icon">{activeList === 'CONCLUIDAS' ? '✓' : '…'}</span>
          <strong>{activeList === 'CONCLUIDAS' ? 'No hay comandas listas para cobrar' : 'No hay otros pedidos pendientes'}</strong>
          <p className="muted">
            {activeList === 'CONCLUIDAS'
              ? 'Cuando todos los ítems estén listos o entregados, aparecerán aquí para cobrar.'
              : 'Los pedidos que aún esperan a cocina aparecerán en esta pestaña.'}
          </p>
        </div>
      )}
    </section>
  );
}

function formatDate(value: string) {
  const date = new Date(value.replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString('es-PE', { dateStyle: 'short', timeStyle: 'short' });
}

function formatCurrency(value: string | number) {
  return new Intl.NumberFormat('es-PE', { style: 'currency', currency: 'PEN' }).format(Number(value) || 0);
}
