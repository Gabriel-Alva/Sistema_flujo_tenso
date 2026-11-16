import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ApiError, api, restoreSession, setAccessToken } from './core/api';
import {
  Account, CashierDashboardData, CashMovementType, CashSessionResponse, LoginResponse, Order,
  OrderDetail, OrderLine, PaymentMethod, PaymentResponse, ReceiptResponse, ReceiptType,
} from './core/types';
import { CashSessionPanel } from './components/CashSessionPanel';
import { CashierDashboard } from './components/CashierDashboard';
import { CashMovementPanel } from './components/CashMovementPanel';
import { LoginScreen } from './components/LoginScreen';
import { OrderList } from './components/OrderList';
import { PaymentPanel } from './components/PaymentPanel';
import { ReceiptPreview } from './components/ReceiptPreview';
import { SipanIcon } from './shared/SipanIcon';

type CheckoutDetails = {
  receiptType: ReceiptType;
  method: PaymentMethod;
  amountReceived?: number;
};

type CheckoutVariables = CheckoutDetails & {
  orderId: number;
  order: Order;
  account: Account;
  items: OrderLine[];
  total: number;
  receiptRequestId: string;
  paymentRequestId: string;
};

type CheckoutResult = {
  payment: PaymentResponse;
  receipt: ReceiptResponse;
};

type CompletedReceipt = {
  receipt: ReceiptResponse;
  receiptType: ReceiptType;
  order: Order;
  account: Account;
  items: OrderLine[];
  method: PaymentMethod;
  amountReceived?: number;
  change: number;
};

export function App() {
  const queryClient = useQueryClient();
  const [token, setToken] = useState<string | null>(null);
  const [restoring, setRestoring] = useState(true);
  const [restoreAttempt, setRestoreAttempt] = useState(0);
  const [restoreError, setRestoreError] = useState('');
  const [operator, setOperator] = useState('');
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [receipt, setReceipt] = useState<ReceiptResponse>();
  const [receiptPreview, setReceiptPreview] = useState<CompletedReceipt>();
  const [receiptAttempted, setReceiptAttempted] = useState(false);
  const [checkoutPhase, setCheckoutPhase] = useState<'idle' | 'receipt' | 'payment'>('idle');
  const [checkoutError, setCheckoutError] = useState('');
  const [feedback, setFeedback] = useState('');
  const receiptKey = useRef<{ fingerprint: string; id: string }>();
  const paymentKey = useRef<{ fingerprint: string; id: string }>();

  useEffect(() => {
    let active = true;
    setRestoring(true);
    restoreSession()
      .then((data) => {
        if (!active) return;
        setAccessToken(data.access_token);
        setToken(data.access_token);
        const persona = data.user?.persona;
        setOperator([persona?.nombres, persona?.primer_apellido].filter(Boolean).join(' ') || 'Cajero');
        setRestoreError('');
      })
      .catch((error: unknown) => {
        if (!active) return;
        setAccessToken(null);
        if (error instanceof ApiError && error.status === 401) {
          setRestoreError('');
        } else {
          setRestoreError(getErrorMessage(error, 'No se pudo restaurar la sesión.'));
        }
      })
      .finally(() => {
        if (active) setRestoring(false);
      });
    return () => { active = false; };
  }, [restoreAttempt]);

  const login = useMutation({
    mutationFn: ({ username, password }: { username: string; password: string }) =>
      api<LoginResponse>('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ username, password, context: 'CAJERO' }),
      }),
    onSuccess: (data) => {
      queryClient.clear();
      setAccessToken(data.access_token);
      setToken(data.access_token);
      setRestoreError('');
      const persona = data.user?.persona;
      setOperator([persona?.nombres, persona?.primer_apellido].filter(Boolean).join(' ') || 'Cajero');
    },
  });

  const sessionQuery = useQuery({
    queryKey: ['cash-session'],
    enabled: Boolean(token),
    queryFn: () => api<CashSessionResponse>('/caja/sesiones/actual'),
    refetchInterval: 15000,
  });
  const cashierDashboardQuery = useQuery({
    queryKey: ['cashier-dashboard'],
    enabled: Boolean(token),
    queryFn: () => api<CashierDashboardData>('/caja/dashboard'),
    refetchInterval: 30000,
  });
  const ordersQuery = useQuery({
    queryKey: ['cashier-orders'],
    enabled: Boolean(token),
    queryFn: async () => {
      const [open, inPayment] = await Promise.all([
        api<Order[]>('/pedidos?estado=ABIERTO'),
        api<Order[]>('/pedidos?estado=EN_PAGO'),
      ]);
      const unique = new Map<number, Order>();
      [...open, ...inPayment].forEach((order) => unique.set(order.id_pedido, order));
      return [...unique.values()];
    },
    refetchInterval: 15000,
  });
  const orderDetailQuery = useQuery({
    queryKey: ['order-detail', selectedOrder?.id_pedido],
    enabled: Boolean(token && selectedOrder),
    queryFn: () => api<OrderDetail>(`/pedidos/${selectedOrder!.id_pedido}`),
  });

  const openSession = useMutation({
    mutationFn: ({ amount, notes }: { amount: number; notes: string }) =>
      api<{ id_caja_sesion: number }>('/caja/sesiones', {
        method: 'POST',
        body: JSON.stringify({ monto_apertura: amount, observaciones: notes || null }),
      }),
    onSuccess: () => {
      setFeedback('La caja se abrió correctamente.');
      queryClient.invalidateQueries({ queryKey: ['cash-session'] });
    },
  });
  const closeSession = useMutation({
    mutationFn: ({ id, amount, notes }: { id: number; amount: number; notes: string }) =>
      api<{ diferencia: number }>(`/caja/sesiones/${id}/cierre`, {
        method: 'POST',
        body: JSON.stringify({ monto_declarado: amount, observaciones: notes || null }),
      }),
    onSuccess: (data) => {
      const difference = Number(data.diferencia);
      setFeedback(`La caja se cerró correctamente. Diferencia de arqueo: ${formatCurrency(difference)}.`);
      queryClient.invalidateQueries({ queryKey: ['cash-session'] });
    },
  });
  const cashMovement = useMutation({
    mutationFn: ({ type, amount, reason }: { type: CashMovementType; amount: number; reason: string }) =>
      api<{ id_movimiento: number }>('/caja/movimientos', {
        method: 'POST',
        body: JSON.stringify({ tipo: type, monto: amount, motivo: reason }),
      }),
    onSuccess: (_data, variables) => {
      setFeedback(`${variables.type === 'INGRESO' ? 'Ingreso' : 'Egreso'} registrado en la caja.`);
      queryClient.invalidateQueries({ queryKey: ['cash-session'] });
    },
  });
  const checkout = useMutation<CheckoutResult, Error, CheckoutVariables>({
    mutationFn: async (details) => {
      let issued = receipt;
      if (!issued) {
        setReceiptAttempted(true);
        setCheckoutPhase('receipt');
        issued = await api<ReceiptResponse>('/comprobantes', {
          method: 'POST',
          body: JSON.stringify({
            receipt_request_id: details.receiptRequestId,
            id_pedido: details.orderId,
            tipo: details.receiptType,
          }),
        });
        setReceipt(issued);
      }

      setCheckoutPhase('payment');
      const payment = await api<PaymentResponse>('/pagos', {
        method: 'POST',
        body: JSON.stringify({
          payment_request_id: details.paymentRequestId,
          id_comprobante: issued.id_comprobante,
          id_caja_sesion: sessionQuery.data?.sesion?.id_caja_sesion,
          metodo: details.method,
          monto: details.total,
          ...(details.amountReceived !== undefined ? { monto_recibido: details.amountReceived } : {}),
        }),
      });
      return { payment, receipt: issued };
    },
    onSuccess: (result, details) => {
      const change = Number(result.payment.p_vuelto ?? 0);
      setReceiptPreview({
        receipt: result.receipt,
        receiptType: details.receiptType,
        order: details.order,
        account: details.account,
        items: details.items,
        method: details.method,
        amountReceived: details.amountReceived,
        change,
      });
      setFeedback(`Pago del pedido #${selectedOrder?.id_pedido} registrado.${change ? ` Vuelto: ${formatCurrency(change)}.` : ''}`);
      setCheckoutError('');
      setCheckoutPhase('idle');
      setSelectedOrder(null);
      setReceipt(undefined);
      setReceiptAttempted(false);
      receiptKey.current = undefined;
      paymentKey.current = undefined;
      queryClient.invalidateQueries({ queryKey: ['cashier-orders'] });
      queryClient.invalidateQueries({ queryKey: ['cash-session'] });
      queryClient.invalidateQueries({ queryKey: ['cashier-dashboard'] });
      queryClient.invalidateQueries({ queryKey: ['order-detail', details.orderId] });
    },
    onError: (error) => {
      setCheckoutError(getErrorMessage(error, 'No se pudo completar el cobro.'));
      setCheckoutPhase('idle');
    },
  });

  const logoutMutation = useMutation({
    mutationFn: () => api<{ code: string }>('/auth/logout', { method: 'POST' }),
    onSuccess: () => {
      setAccessToken(null);
      setToken(null);
      setOperator('');
      setSelectedOrder(null);
      setReceipt(undefined);
      setReceiptPreview(undefined);
      setReceiptAttempted(false);
      receiptKey.current = undefined;
      paymentKey.current = undefined;
      setFeedback('');
      queryClient.clear();
    },
  });

  const authError = [sessionQuery.error, cashierDashboardQuery.error, ordersQuery.error, orderDetailQuery.error, openSession.error, closeSession.error, cashMovement.error, checkout.error, logoutMutation.error]
    .find((error) => error instanceof ApiError && error.status === 401);
  useEffect(() => {
    if (authError) {
      setAccessToken(null);
      setToken(null);
      setOperator('');
      setSelectedOrder(null);
      setReceipt(undefined);
      setReceiptPreview(undefined);
      setReceiptAttempted(false);
      receiptKey.current = undefined;
      paymentKey.current = undefined;
      queryClient.clear();
    }
  }, [authError, queryClient]);

  function chooseOrder(order: Order) {
    if (selectedOrder?.id_pedido === order.id_pedido) return;
    setSelectedOrder(order);
    setReceipt(undefined);
    setReceiptPreview(undefined);
    setReceiptAttempted(false);
    setCheckoutError('');
    setFeedback('');
    setCheckoutPhase('idle');
    receiptKey.current = undefined;
    paymentKey.current = undefined;
  }

  function handlePay(details: CheckoutDetails) {
    if (!selectedOrder || !orderDetailQuery.data?.cuenta) return;
    if (details.receiptType === 'FACTURA') {
      setCheckoutError('La factura requiere seleccionar y validar un cliente con RUC. Esta opción aún no está disponible.');
      return;
    }
    const receiptFingerprint = JSON.stringify({
      orderId: selectedOrder.id_pedido,
      receiptType: details.receiptType,
    });
    if (receiptKey.current?.fingerprint !== receiptFingerprint) {
      receiptKey.current = { fingerprint: receiptFingerprint, id: createRequestId() };
    }
    const fingerprint = String(selectedOrder.id_pedido);
    if (paymentKey.current?.fingerprint !== fingerprint) {
      paymentKey.current = { fingerprint, id: createRequestId() };
    }
    setCheckoutError('');
    checkout.mutate({
      ...details,
      orderId: selectedOrder.id_pedido,
      order: selectedOrder,
      account: orderDetailQuery.data.cuenta,
      items: orderDetailQuery.data.items,
      total: Number(orderDetailQuery.data.cuenta.saldo_pendiente ?? orderDetailQuery.data.cuenta.total),
      receiptRequestId: receiptKey.current.id,
      paymentRequestId: paymentKey.current.id,
    });
  }

  function logout() {
    logoutMutation.mutate();
  }

  async function recordCashMovement(type: CashMovementType, amount: number, reason: string) {
    try {
      await cashMovement.mutateAsync({ type, amount, reason });
      return true;
    } catch {
      return false;
    }
  }

  if (!token) {
    if (restoring) {
      return <main className="login-page"><p className="startup-message">Restaurando sesión segura…</p></main>;
    }
    return (
      <LoginScreen
        busy={login.isPending}
        error={login.error ? getErrorMessage(login.error, 'No se pudo iniciar sesión. Revisa tus credenciales.') : undefined}
        restoreError={restoreError}
        onRetryRestore={() => {
          setRestoreError('');
          setRestoreAttempt((attempt) => attempt + 1);
        }}
        onLogin={(username, password) => login.mutate({ username, password })}
      />
    );
  }

  const session = sessionQuery.data?.sesion ?? null;
  const orders = ordersQuery.data ?? [];
  const mutationError = openSession.error || closeSession.error;

  return (
    <main className="pos-shell">
      <header className="pos-header">
        <div className="brand-lockup">
          <span className="brand-mark"><SipanIcon name="cash" size={23} /></span>
          <div><strong>POS Caja</strong><small>Chifa Sipán</small></div>
        </div>
        <div className="header-actions">
          <span className="user-chip"><span className="user-dot" />{operator}</span>
          <button className="button button--header" type="button" disabled={checkout.isPending || logoutMutation.isPending} onClick={logout}>
            {logoutMutation.isPending ? 'Cerrando…' : 'Cerrar sesión'}
          </button>
        </div>
      </header>

      <div className="workspace">
        <section className="welcome-row">
          <div>
            <p className="eyebrow">PANEL DE CAJERO</p>
            <h1>Hola, {operator.split(' ')[0]}</h1>
            <p className="muted">Revisa tus resultados y cobra las comandas concluidas.</p>
          </div>
          <div className="live-indicator"><span /> Sistema conectado</div>
        </section>

        <CashierDashboard
          data={cashierDashboardQuery.data}
          loading={cashierDashboardQuery.isLoading}
          error={cashierDashboardQuery.error ? getErrorMessage(cashierDashboardQuery.error, 'Inténtalo nuevamente.') : undefined}
          onRetry={() => cashierDashboardQuery.refetch()}
        />

        {feedback && <p className="notice notice--success global-feedback" role="status">{feedback}</p>}
        {logoutMutation.error && (
          <p className="notice notice--error global-feedback" role="alert">
            No se pudo cerrar la sesión en el servidor: {getErrorMessage(logoutMutation.error, 'Inténtalo nuevamente.')}
          </p>
        )}

        <CashSessionPanel
          session={session}
          summary={sessionQuery.data?.arqueo}
          loading={sessionQuery.isLoading}
          busy={openSession.isPending || closeSession.isPending || cashMovement.isPending || checkout.isPending}
          locked={Boolean(receipt || checkoutError)}
          error={mutationError ? getErrorMessage(mutationError, 'No se pudo actualizar la caja.') : undefined}
          loadError={sessionQuery.error ? getErrorMessage(sessionQuery.error, 'No se pudo consultar la sesión.') : undefined}
          onRetry={() => sessionQuery.refetch()}
          onOpen={(amount, notes) => {
            setFeedback('');
            openSession.mutate({ amount, notes });
          }}
          onClose={(id, amount, notes) => {
            setFeedback('');
            closeSession.mutate({ id, amount, notes });
          }}
        />

        <CashMovementPanel
          sessionOpen={Boolean(session)}
          busy={cashMovement.isPending}
          locked={Boolean(receipt || checkoutError)}
          error={cashMovement.error ? getErrorMessage(cashMovement.error, 'No se pudo registrar el movimiento.') : undefined}
          onRecord={recordCashMovement}
        />

        <div className="checkout-grid">
          <OrderList
            orders={orders}
            completedOrders={cashierDashboardQuery.data?.comandas_concluidas ?? []}
            selectedId={selectedOrder?.id_pedido ?? null}
            loading={ordersQuery.isLoading}
            completedLoading={cashierDashboardQuery.isLoading}
            disabled={checkout.isPending || Boolean(receipt) || Boolean(checkoutError)}
            error={ordersQuery.error ? getErrorMessage(ordersQuery.error, 'No se pudieron cargar los pedidos.') : undefined}
            completedError={cashierDashboardQuery.error ? getErrorMessage(cashierDashboardQuery.error, 'No se pudieron cargar las comandas concluidas.') : undefined}
            onRetry={() => ordersQuery.refetch()}
            onRetryCompleted={() => cashierDashboardQuery.refetch()}
            onSelect={chooseOrder}
          />
          <PaymentPanel
            order={selectedOrder}
            account={orderDetailQuery.data?.cuenta}
            items={orderDetailQuery.data?.items}
            accountError={orderDetailQuery.error ? getErrorMessage(orderDetailQuery.error, 'No se pudo cargar el detalle de la cuenta.') : undefined}
            loading={orderDetailQuery.isLoading}
            onRetry={() => orderDetailQuery.refetch()}
            sessionOpen={Boolean(session)}
            busy={checkout.isPending}
            phase={checkoutPhase}
            error={checkoutError}
            receipt={receipt}
            receiptLocked={receiptAttempted}
            onPay={handlePay}
          />
        </div>
      </div>
      {receiptPreview && (
        <ReceiptPreview
          {...receiptPreview}
          onClose={() => setReceiptPreview(undefined)}
        />
      )}
    </main>
  );
}

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback;
}

function formatCurrency(value: string | number) {
  return new Intl.NumberFormat('es-PE', { style: 'currency', currency: 'PEN' }).format(Number(value) || 0);
}

function createRequestId() {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
