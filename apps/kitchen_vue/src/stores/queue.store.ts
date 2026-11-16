import { defineStore } from 'pinia';
import { api, getApiErrorMessage } from '../core/api';

export type Ticket = {
  id_detalle: number;
  id_comanda: number;
  id_pedido: number;
  numero_ronda: number;
  fecha_envio: string;
  numero_mesa: number | null;
  zona: string | null;
  nombre_mesero: string | null;
  tipo_pedido: string;
  imagen_url: string | null;
  nombre_snapshot: string;
  cantidad: number;
  nota: string | null;
  modificadores: string | null;
  total_items_estacion: number;
  items_listos_estacion: number;
  segundos_transcurridos: number;
  estado_item: 'PENDIENTE' | 'EN_PREPARACION' | 'LISTO';
  prioridad: string;
  color_hex: string;
  estacion: string | null;
};

type TicketStatus = 'EN_PREPARACION' | 'LISTO' | 'CANCELADO';
let pendingLoad: Promise<void> | null = null;

export const useQueueStore = defineStore('queue', {
  state: () => ({
    tickets: [] as Ticket[],
    loading: false,
    error: '',
    mutationError: '',
    updatingId: null as number | null,
    updatingCommandId: null as number | null,
    lastLoadedAt: 0,
  }),
  actions: {
    async load(stationId: number, force = false) {
      if (pendingLoad) {
        await pendingLoad;
        if (force) await this.load(stationId);
        return;
      }

      this.loading = true;
      this.error = '';
      pendingLoad = (async () => {
        try {
          const { data } = await api.get<Ticket[]>('/cocina/cola', {
            params: { id_estacion: stationId },
          });
          if (!Array.isArray(data)) throw new Error('La respuesta de la cola no es válida.');
          this.tickets = data;
          this.lastLoadedAt = Date.now();
        } catch (error) {
          this.error = getApiErrorMessage(error, 'No se pudo cargar la cola de cocina.');
        } finally {
          this.loading = false;
          pendingLoad = null;
        }
      })();
      await pendingLoad;
    },
    async setEstado(id: number, estado_item: Exclude<TicketStatus, 'CANCELADO'>, stationId: number) {
      return this.updateStatus(id, estado_item, stationId);
    },
    async cancelItem(id: number, motivo_cancelacion: string, stationId: number) {
      return this.updateStatus(id, 'CANCELADO', stationId, motivo_cancelacion);
    },
    async cancelComanda(id: number, motivo_cancelacion: string, stationId: number): Promise<boolean> {
      this.mutationError = '';
      this.updatingCommandId = id;
      try {
        await api.patch(`/cocina/comandas/${id}/cancelar`, { motivo_cancelacion });
        await this.load(stationId, true);
        return true;
      } catch (error) {
        this.mutationError = getApiErrorMessage(error, 'No se pudo cancelar la comanda.');
        return false;
      } finally {
        this.updatingCommandId = null;
      }
    },
    async updateStatus(
      id: number,
      estado_item: TicketStatus,
      stationId: number,
      motivo_cancelacion?: string,
    ): Promise<boolean> {
      this.mutationError = '';
      this.updatingId = id;
      try {
        await api.patch(`/cocina/items/${id}/estado`, { estado_item, motivo_cancelacion });
        await this.load(stationId, true);
        return true;
      } catch (error) {
        this.mutationError = getApiErrorMessage(error, 'No se pudo actualizar el estado del ítem.');
        return false;
      } finally {
        this.updatingId = null;
      }
    },
  },
});
