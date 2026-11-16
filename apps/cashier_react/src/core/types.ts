export type LoginResponse = {
  access_token: string;
  user?: {
    persona?: {
      nombres?: string;
      primer_apellido?: string;
    };
  };
};

export type Order = {
  id_pedido: number;
  tipo: string;
  estado: string;
  id_mesa: number | null;
  numero_mesa?: number | null;
  fecha?: string;
};

export type CompletedCashierOrder = Order & {
  saldo_pendiente: string | number;
  items_concluidos: number;
};

export type CashierDashboardData = {
  resumen: {
    pedidos_cobrados_hoy: number;
    ventas_hoy: number;
    ticket_promedio: number;
    pedidos_pendientes_cobro: number;
    comandas_concluidas: number;
    efectivo_hoy: number;
    tarjeta_hoy: number;
    yape_hoy: number;
    plin_hoy: number;
    transferencia_hoy: number;
  };
  ventas_7_dias: Array<{
    fecha: string;
    etiqueta: string;
    ventas: number;
    pedidos: number;
  }>;
  comandas_concluidas: CompletedCashierOrder[];
};

export type CashSession = {
  id_caja_sesion: number;
  monto_apertura: string | number;
  apertura_en?: string;
};

export type CashSummary = {
  total_efectivo?: string | number;
  total_tarjeta?: string | number;
  total_yape?: string | number;
  total_plin?: string | number;
  total_transferencia?: string | number;
  movimientos_ingreso?: string | number;
  movimientos_egreso?: string | number;
  saldo_teorico_gaveta?: string | number;
};

export type CashSessionResponse = {
  sesion: CashSession | null;
  arqueo?: CashSummary | null;
};

export type Account = {
  id_pedido: number;
  subtotal_items?: string | number;
  subtotal_modificadores?: string | number;
  base_imponible: string | number;
  impuestos: string | number;
  total: string | number;
  total_pagado?: string | number;
  saldo_pendiente?: string | number;
};

export type OrderLine = {
  id_detalle: number | null;
  nombre_snapshot: string | null;
  precio_unitario_venta: string | number | null;
  cantidad: number | null;
  estado_item: string | null;
  nota: string | null;
};

export type OrderDetail = {
  pedido: {
    id_pedido: number;
    fecha: string;
    tipo: string;
    id_mesa: number | null;
    numero_mesa: number | null;
    num_comensales?: number | null;
  };
  cuenta: Account;
  items: OrderLine[];
};

export type ReceiptResponse = {
  id_comprobante: number;
  serie: string;
  correlativo: number;
};

export type PaymentResponse = {
  p_vuelto?: string | number;
  p_id_pago_out?: number;
  p_pedido_estado?: string;
};

export type ReceiptType = 'BOLETA' | 'FACTURA' | 'NOTA_VENTA';
export type PaymentMethod = 'EFECTIVO' | 'TARJETA' | 'YAPE' | 'PLIN' | 'TRANSFERENCIA';
export type CashMovementType = 'INGRESO' | 'EGRESO';
