import { CashierDashboardData } from '../core/types';
import { SipanIcon } from '../shared/SipanIcon';

type Props = {
  data?: CashierDashboardData;
  loading: boolean;
  error?: string;
  onRetry: () => void;
};

export function CashierDashboard({ data, loading, error, onRetry }: Props) {
  const maxSales = Math.max(0, ...(data?.ventas_7_dias.map((entry) => entry.ventas) ?? []));

  return (
    <section className="card dashboard-card" aria-labelledby="cashier-dashboard-title">
      <header className="dashboard-heading">
        <div>
          <p className="eyebrow">INDICADORES</p>
          <h2 id="cashier-dashboard-title">Resumen de caja</h2>
        </div>
        <span className="dashboard-date">{formatToday()}</span>
      </header>

      {error && (
        <p className="notice notice--error" role="alert">
          No se pudieron cargar las estadísticas: {error} <button className="text-button" type="button" onClick={onRetry}>Reintentar</button>
        </p>
      )}
      {loading && !data ? (
        <p className="muted">Consultando estadísticas de caja…</p>
      ) : data ? (
        <>
          <div className="dashboard-kpis">
            <article className="dashboard-kpi dashboard-kpi--sales">
              <span className="dashboard-kpi-icon"><SipanIcon name="cash" size={19} /></span>
              <div><small>Recaudado hoy</small><strong>{formatCurrency(data.resumen.ventas_hoy)}</strong></div>
              <p>{data.resumen.pedidos_cobrados_hoy} {plural(data.resumen.pedidos_cobrados_hoy, 'pedido cobrado', 'pedidos cobrados')}</p>
            </article>
            <article className="dashboard-kpi">
              <span className="dashboard-kpi-icon"><SipanIcon name="order" size={19} /></span>
              <div><small>Ticket promedio</small><strong>{formatCurrency(data.resumen.ticket_promedio)}</strong></div>
              <p>Por pedido cobrado hoy</p>
            </article>
            <article className="dashboard-kpi dashboard-kpi--ready">
              <span className="dashboard-kpi-icon"><SipanIcon name="check" size={19} /></span>
              <div><small>Comandas concluidas</small><strong>{data.resumen.comandas_concluidas}</strong></div>
              <p>Listas para cobrar</p>
            </article>
            <article className="dashboard-kpi">
              <span className="dashboard-kpi-icon"><SipanIcon name="salon" size={19} /></span>
              <div><small>Cuentas pendientes</small><strong>{data.resumen.pedidos_pendientes_cobro}</strong></div>
              <p>Con saldo por cobrar</p>
            </article>
          </div>

          <div className="dashboard-details">
            <section className="dashboard-chart" aria-labelledby="cashier-sales-chart-title">
              <div className="dashboard-section-heading">
                <div><SipanIcon name="chart" size={17} /><h3 id="cashier-sales-chart-title">Ventas de los últimos 7 días</h3></div>
                <span>Por fecha de pago</span>
              </div>
              {data.ventas_7_dias.length ? (
                <div className="sales-chart" role="img" aria-label="Ventas y pedidos cobrados durante los últimos siete días">
                  {data.ventas_7_dias.map((day) => {
                    const height = maxSales > 0 ? Math.max(day.ventas > 0 ? 8 : 0, (day.ventas / maxSales) * 100) : 0;
                    return (
                      <div className="sales-chart-day" key={day.fecha} title={`${day.etiqueta}: ${formatCurrency(day.ventas)}, ${day.pedidos} pedidos`}>
                        <strong>{formatCompactCurrency(day.ventas)}</strong>
                        <span className="sales-chart-track"><span style={{ height: `${height}%` }} /></span>
                        <span className="sales-chart-label">{day.etiqueta}</span>
                        <small>{day.pedidos} {day.pedidos === 1 ? 'pedido' : 'pedidos'}</small>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <p className="muted">No hay ventas registradas en este periodo.</p>
              )}
            </section>

            <section className="dashboard-methods" aria-labelledby="cashier-payment-methods-title">
              <div className="dashboard-section-heading">
                <div><SipanIcon name="cash" size={17} /><h3 id="cashier-payment-methods-title">Medios de pago hoy</h3></div>
              </div>
              <dl>
                <div><dt>Efectivo</dt><dd>{formatCurrency(data.resumen.efectivo_hoy)}</dd></div>
                <div><dt>Tarjeta</dt><dd>{formatCurrency(data.resumen.tarjeta_hoy)}</dd></div>
                <div><dt>Yape / Plin</dt><dd>{formatCurrency(data.resumen.yape_hoy + data.resumen.plin_hoy)}</dd></div>
                <div><dt>Transferencia</dt><dd>{formatCurrency(data.resumen.transferencia_hoy)}</dd></div>
              </dl>
            </section>
          </div>
        </>
      ) : null}
    </section>
  );
}

function formatToday() {
  return new Intl.DateTimeFormat('es-PE', { dateStyle: 'long' }).format(new Date());
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat('es-PE', { style: 'currency', currency: 'PEN' }).format(Number(value) || 0);
}

function formatCompactCurrency(value: number) {
  return new Intl.NumberFormat('es-PE', {
    style: 'currency',
    currency: 'PEN',
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(Number(value) || 0);
}

function plural(count: number, singular: string, pluralForm: string) {
  return count === 1 ? singular : pluralForm;
}
