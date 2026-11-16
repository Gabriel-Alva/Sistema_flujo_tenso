<template>
  <div class="kds-body" @keydown.esc="closeDetails">
    <header class="kds-header">
      <div class="kds-brand">
        <span class="kds-brand-icon"><SipanIcon name="kitchen" :size="30" /></span>
        <span class="kds-brand-text"><small>CHIFA SIPÁN</small><strong>Monitor de cocina</strong></span>
      </div>
      <span class="kds-station-label">Estación {{ auth.stationId }} · {{ auth.nombre }}</span>
      <span class="clock"><SipanIcon name="clock" /> {{ clock }}</span>
      <div class="header-actions">
        <button class="btn-ghost" :disabled="queue.loading" @click="refresh">
          <SipanIcon name="refresh" /> {{ queue.loading ? 'Actualizando…' : 'Actualizar' }}
        </button>
        <button class="btn-ghost" @click="logout">Cerrar sesión</button>
      </div>
    </header>
    <main class="kds-queue">
      <p v-if="queue.error" class="queue-message error" role="alert">
        {{ queue.error }}
        <button class="btn-ghost" :disabled="queue.loading" @click="refresh">Reintentar</button>
      </p>
      <p v-else-if="queue.loading && !queue.tickets.length" class="queue-message" role="status">Cargando cola…</p>
      <p v-if="queue.mutationError" class="queue-message error" role="alert">{{ queue.mutationError }}</p>
      <section v-if="orderGroups.length" class="order-grid">
      <article
        v-for="group in orderGroups"
        :key="group.id_comanda"
        class="order-card"
        :class="group.isReady ? 'order-card--ready' : 'order-card--active'"
      >
        <header class="order-card-header">
          <div class="order-heading">
            <span class="order-icon"><SipanIcon name="order" /></span>
            <div class="order-heading-copy">
              <span class="order-kicker">Pedido #{{ group.tickets[0].id_pedido }} · Ronda {{ group.tickets[0].numero_ronda }}</span>
              <h2>
                <template v-if="group.tickets[0].numero_mesa">
                  <SipanIcon name="salon" /> Mesa {{ group.tickets[0].numero_mesa }}
                </template>
                <template v-else>{{ orderTypeLabel(group.tickets[0].tipo_pedido) }}</template>
              </h2>
            </div>
            <span class="order-state" :class="orderStateClass(group)">
              <SipanIcon v-if="group.isReady" name="check" />
              <span v-else class="state-dot" />
              {{ orderStateLabel(group) }}
            </span>
          </div>
          <div class="order-meta">
            <span class="order-type-badge">{{ orderTypeLabel(group.tickets[0].tipo_pedido) }}</span>
            <span><SipanIcon name="clock" /> Enviada {{ formatTimestamp(group.tickets[0].fecha_envio) }}</span>
            <span class="order-timer" :aria-label="`Tiempo transcurrido ${formatElapsed(group.tickets[0])}`">
              Hace {{ formatElapsed(group.tickets[0]) }}
            </span>
            <span v-if="group.tickets[0].nombre_mesero"><SipanIcon name="user" /> {{ group.tickets[0].nombre_mesero }}</span>
            <span v-if="showOrderZone(group.tickets[0])">Zona · {{ group.tickets[0].zona }}</span>
          </div>
          <div class="order-progress">
            <div class="progress-track" role="progressbar" :aria-valuenow="group.progress" aria-valuemin="0" aria-valuemax="100">
              <span :style="{ width: `${group.progress}%` }" />
            </div>
            <strong>{{ group.readyItems }}/{{ group.totalItems }} listos</strong>
          </div>
        </header>

        <section class="order-items" :aria-label="`Productos del pedido ${group.tickets[0].id_pedido}`">
          <article
            v-for="t in group.tickets"
            :key="t.id_detalle"
            class="order-item"
            :class="{ 'order-item--ready': t.estado_item === 'LISTO' }"
          >
            <header class="order-item-heading">
              <img
                v-if="t.imagen_url?.trim() && !failedImages.has(t.id_detalle)"
                class="product-thumb"
                :src="imageUrl(t.imagen_url)"
                alt=""
                loading="lazy"
                @error="markImageError(t.id_detalle)"
              />
              <span v-else class="product-thumb product-thumb--empty" aria-hidden="true">
                <SipanIcon name="kitchen" />
              </span>
              <div class="order-item-copy">
                <div class="item-name-row">
                  <h3>{{ t.nombre_snapshot }}</h3>
                  <span class="item-quantity">×{{ t.cantidad }}</span>
                </div>
                <span class="priority-tag" :style="{ color: t.color_hex, borderColor: t.color_hex }">{{ t.prioridad }}</span>
                <p v-if="t.modificadores" class="item-modifiers" :title="t.modificadores">{{ t.modificadores }}</p>
                <p v-if="t.nota" class="item-note" :title="t.nota">Nota: {{ t.nota }}</p>
              </div>
            </header>

            <div class="prep-steps" :aria-label="`Estado: ${itemStateLabel(t)}`">
              <div class="prep-step" :class="stepClass(t, 'PENDIENTE')">
                <span class="prep-step-icon">
                  <SipanIcon v-if="isStepComplete(t, 'PENDIENTE')" name="check" />
                  <span v-else class="step-dot" />
                </span>
                <small>Pendiente</small>
              </div>
              <span class="prep-step-line" :class="{ 'prep-step-line--done': isStepComplete(t, 'PENDIENTE') }" />
              <div class="prep-step" :class="stepClass(t, 'EN_PREPARACION')">
                <span class="prep-step-icon">
                  <SipanIcon v-if="isStepComplete(t, 'EN_PREPARACION')" name="check" />
                  <SipanIcon v-else-if="t.estado_item === 'EN_PREPARACION'" name="flame" />
                  <span v-else class="step-dot" />
                </span>
                <small>Preparando</small>
              </div>
              <span class="prep-step-line" :class="{ 'prep-step-line--done': isStepComplete(t, 'EN_PREPARACION') }" />
              <div class="prep-step" :class="stepClass(t, 'LISTO')">
                <span class="prep-step-icon">
                  <SipanIcon v-if="isStepComplete(t, 'LISTO')" name="check" />
                  <span v-else class="step-dot" />
                </span>
                <small>Listo</small>
              </div>
            </div>

            <div class="item-actions">
              <button
                v-if="t.estado_item === 'PENDIENTE'"
                class="btn-primary btn-prep"
                :disabled="queue.updatingId !== null || queue.updatingCommandId !== null"
                @click="avanzar(t, 'EN_PREPARACION')"
              >
                <SipanIcon name="flame" /> Empezar
              </button>
              <button
                v-else-if="t.estado_item === 'EN_PREPARACION'"
                class="btn-primary btn-ready"
                :disabled="queue.updatingId !== null || queue.updatingCommandId !== null"
                @click="avanzar(t, 'LISTO')"
              >
                <SipanIcon name="check" /> Marcar listo
              </button>
              <span v-else class="item-ready-label"><SipanIcon name="check" /> Plato listo</span>
              <button class="btn-ghost" :disabled="queue.updatingId !== null || queue.updatingCommandId !== null" @click="openDetails(t)">
                <SipanIcon name="order" /> Detalles
              </button>
              <button
                v-if="canCancel(t)"
                class="btn-cancel"
                :disabled="queue.updatingId !== null || queue.updatingCommandId !== null"
                @click="openCancel(t)"
              >
                Cancelar
              </button>
            </div>
          </article>
        </section>

        <div v-if="group.isReady" class="order-ready-notice">
          <SipanIcon name="check" />
          <span>Todos los platos están listos. Avisar a salón para la entrega.</span>
        </div>
        <footer class="order-footer">
          <button
            v-if="group.canCancelComanda"
            class="command-cancel-button"
            :disabled="queue.updatingCommandId !== null || queue.updatingId !== null"
            @click="openCancelCommand(group)"
          >
            Cancelar comanda
          </button>
          <p v-else-if="group.hasStarted && !group.isReady" class="command-cancel-note">
            Preparación iniciada: cancela solo los ítems necesarios.
          </p>
        </footer>
      </article>
      </section>
      <div v-else-if="!queue.loading && !queue.error" class="kds-empty">
        <SipanIcon name="kitchen" :size="48" xl />
        <p>No hay comandas activas en esta estación.</p>
      </div>
    </main>

    <div v-if="selectedTicket" class="kds-modal-backdrop" @click.self="closeDetails">
      <section
        class="kds-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="ticket-details-title"
        tabindex="-1"
      >
        <header class="kds-modal-header">
          <div>
            <span class="kds-modal-eyebrow">Pedido #{{ selectedTicket.id_pedido }} · Ronda {{ selectedTicket.numero_ronda }}</span>
            <h2 id="ticket-details-title">{{ cancelMode ? 'Cancelar ítem' : 'Detalle de comanda' }}</h2>
          </div>
          <button class="kds-modal-close" aria-label="Cerrar detalle" @click="closeDetails">
            <SipanIcon name="close" />
          </button>
        </header>

        <div class="kds-detail-grid">
          <div><span>Comanda</span><strong>#{{ selectedTicket.id_comanda }}</strong></div>
          <div><span>Estado</span><strong>{{ itemStateLabel(selectedTicket) }}</strong></div>
          <div><span>Tipo</span><strong>{{ selectedTicket.tipo_pedido }}</strong></div>
          <div v-if="selectedTicket.numero_mesa"><span>Mesa</span><strong>{{ selectedTicket.numero_mesa }}{{ selectedTicket.zona ? ` · ${selectedTicket.zona}` : '' }}</strong></div>
          <div><span>Estación</span><strong>{{ selectedTicket.estacion || `Estación ${auth.stationId}` }}</strong></div>
          <div><span>Prioridad</span><strong>{{ selectedTicket.prioridad }}</strong></div>
          <div><span>Enviada</span><strong>{{ formatTimestamp(selectedTicket.fecha_envio) }}</strong></div>
          <div><span>Transcurrido</span><strong>{{ formatElapsed(selectedTicket) }}</strong></div>
        </div>

        <section class="kds-detail-item">
          <h3>{{ selectedTicket.cantidad }} × {{ selectedTicket.nombre_snapshot }}</h3>
          <p v-if="selectedTicket.modificadores"><strong>Modificadores:</strong> {{ selectedTicket.modificadores }}</p>
          <p v-if="selectedTicket.nota" class="nota"><strong>Nota:</strong> {{ selectedTicket.nota }}</p>
          <p v-if="!selectedTicket.modificadores && !selectedTicket.nota" class="kds-muted">Sin modificadores ni notas especiales.</p>
        </section>

        <form v-if="cancelMode" class="kds-cancel-form" @submit.prevent="cancelSelected">
          <label for="cancel-reason">Motivo de cancelación <span aria-hidden="true">*</span></label>
          <textarea
            id="cancel-reason"
            v-model="cancelReason"
            maxlength="250"
            minlength="3"
            required
            rows="3"
            placeholder="Describe por qué se cancela este ítem"
          />
          <p class="kds-muted">El motivo quedará registrado en el historial de la comanda.</p>
          <div class="kds-modal-actions">
            <button type="button" class="btn-ghost" :disabled="queue.updatingId !== null || queue.updatingCommandId !== null" @click="cancelMode = false">
              Volver al detalle
            </button>
            <button
              type="submit"
              class="btn-cancel"
              :disabled="queue.updatingId !== null || queue.updatingCommandId !== null || cancelReason.trim().length < 3"
            >
              {{ queue.updatingId === selectedTicket.id_detalle ? 'Cancelando…' : 'Confirmar cancelación' }}
            </button>
          </div>
        </form>
        <div v-else class="kds-modal-actions">
          <button class="btn-ghost" @click="closeDetails">Cerrar</button>
          <button
            v-if="canCancel(selectedTicket)"
            class="btn-cancel"
            :disabled="queue.updatingId !== null || queue.updatingCommandId !== null"
            @click="cancelMode = true"
          >
            Cancelar este ítem
          </button>
        </div>
      </section>
    </div>

    <div v-if="selectedComanda" class="kds-modal-backdrop" @click.self="closeDetails">
      <section
        class="kds-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="cancel-command-title"
        tabindex="-1"
      >
        <header class="kds-modal-header">
          <div>
            <span class="kds-modal-eyebrow">Pedido #{{ selectedComanda.tickets[0].id_pedido }} · Ronda {{ selectedComanda.tickets[0].numero_ronda }}</span>
            <h2 id="cancel-command-title">Cancelar comanda</h2>
          </div>
          <button class="kds-modal-close" aria-label="Cerrar cancelación" @click="closeDetails">
            <SipanIcon name="close" />
          </button>
        </header>
        <p class="command-cancel-summary">
          Se cancelarán {{ selectedComanda.tickets.length }} ítem{{ selectedComanda.tickets.length === 1 ? '' : 's' }} pendiente{{ selectedComanda.tickets.length === 1 ? '' : 's' }} de
          {{ selectedComanda.tickets[0].estacion || `Estación ${auth.stationId}` }}. Los productos de otras estaciones no cambiarán.
        </p>
        <p v-if="queue.mutationError" class="modal-mutation-error" role="alert">{{ queue.mutationError }}</p>
        <form class="kds-cancel-form" @submit.prevent="cancelSelectedCommand">
          <label for="cancel-command-reason">Motivo de cancelación <span aria-hidden="true">*</span></label>
          <textarea
            id="cancel-command-reason"
            v-model="cancelReason"
            maxlength="250"
            minlength="3"
            required
            rows="3"
            placeholder="Describe por qué se cancela esta comanda"
          />
          <p class="kds-muted">Solo se permite cancelar la comanda antes de iniciar la preparación.</p>
          <div class="kds-modal-actions">
            <button type="button" class="btn-ghost" :disabled="queue.updatingCommandId !== null" @click="closeDetails">
              Volver
            </button>
            <button
              type="submit"
              class="btn-cancel"
              :disabled="queue.updatingCommandId !== null || cancelReason.trim().length < 3"
            >
              {{ queue.updatingCommandId === selectedComanda.id_comanda ? 'Cancelando…' : 'Confirmar cancelación' }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth.store';
import { useQueueStore, type Ticket } from '../stores/queue.store';
import SipanIcon from '../components/SipanIcon.vue';

type ProcessStep = Ticket['estado_item'];
type OrderGroup = {
  id_comanda: number;
  tickets: Ticket[];
  totalItems: number;
  readyItems: number;
  progress: number;
  isReady: boolean;
  hasStarted: boolean;
  canCancelComanda: boolean;
};

const auth = useAuthStore();
const queue = useQueueStore();
const router = useRouter();
const now = ref(Date.now());
const clock = computed(() => new Date(now.value).toLocaleTimeString());
const selectedId = ref<number | null>(null);
const selectedTicket = computed(() => queue.tickets.find((ticket) => ticket.id_detalle === selectedId.value) ?? null);
const selectedComandaId = ref<number | null>(null);
const failedImages = ref(new Set<number>());
const orderGroups = computed<OrderGroup[]>(() => {
  const groups = new Map<number, OrderGroup>();
  for (const ticket of queue.tickets) {
    let group = groups.get(ticket.id_comanda);
    if (!group) {
      group = {
        id_comanda: ticket.id_comanda,
        tickets: [],
        totalItems: ticket.total_items_estacion,
        readyItems: ticket.items_listos_estacion,
        progress: 0,
        isReady: false,
        hasStarted: false,
        canCancelComanda: false,
      };
      groups.set(ticket.id_comanda, group);
    }
    group.tickets.push(ticket);
    group.totalItems = Math.max(group.totalItems, ticket.total_items_estacion);
    group.readyItems = Math.max(group.readyItems, ticket.items_listos_estacion);
  }

  return [...groups.values()]
    .map((group) => {
      const isReady = group.totalItems > 0 && group.readyItems >= group.totalItems;
      const allItemsPending = group.tickets.length === group.totalItems
        && group.tickets.every((ticket) => ticket.estado_item === 'PENDIENTE');
      return {
        ...group,
        progress: group.totalItems ? Math.round((group.readyItems / group.totalItems) * 100) : 0,
        isReady,
        hasStarted: !allItemsPending,
        canCancelComanda: allItemsPending,
      };
    });
});
const selectedComanda = computed(() => orderGroups.value.find((group) => group.id_comanda === selectedComandaId.value) ?? null);
const cancelMode = ref(false);
const cancelReason = ref('');
let clockTimer: number;
let queueTimer: number;

async function refresh() {
  if (auth.stationId) await queue.load(auth.stationId, true);
}

async function avanzar(t: Ticket, estado: 'EN_PREPARACION' | 'LISTO') {
  if (auth.stationId) await queue.setEstado(t.id_detalle, estado, auth.stationId);
}

function formatElapsed(ticket: Ticket) {
  const seconds = Math.max(
    0,
    ticket.segundos_transcurridos + Math.floor((now.value - queue.lastLoadedAt) / 1000),
  );
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainingSeconds = seconds % 60;
  const twoDigits = (value: number) => String(value).padStart(2, '0');

  return hours > 0
    ? `${hours}:${twoDigits(minutes)}:${twoDigits(remainingSeconds)}`
    : `${minutes}:${twoDigits(remainingSeconds)}`;
}

function formatTimestamp(value: string) {
  return value.replace('T', ' ').slice(0, 19);
}

function orderTypeLabel(type: string) {
  return type === 'SALON' ? 'Salón' : type === 'DELIVERY' ? 'Delivery' : type;
}

function showOrderZone(ticket: Ticket) {
  return Boolean(ticket.zona && ticket.zona.trim().toLocaleLowerCase() !== orderTypeLabel(ticket.tipo_pedido).toLocaleLowerCase());
}

function orderStateLabel(group: OrderGroup) {
  if (group.isReady) return 'Listo';
  return group.tickets.some((ticket) => ticket.estado_item === 'EN_PREPARACION')
    ? 'En preparación'
    : 'Pendiente';
}

function orderStateClass(group: OrderGroup) {
  if (group.isReady) return 'order-state--ready';
  return group.tickets.some((ticket) => ticket.estado_item === 'EN_PREPARACION')
    ? 'order-state--preparing'
    : 'order-state--pending';
}

function itemStateLabel(ticket: Ticket) {
  return ticket.estado_item === 'EN_PREPARACION'
    ? 'En preparación'
    : ticket.estado_item === 'LISTO'
      ? 'Listo'
      : 'Pendiente';
}

function isStepComplete(ticket: Ticket, step: ProcessStep) {
  const order: ProcessStep[] = ['PENDIENTE', 'EN_PREPARACION', 'LISTO'];
  return ticket.estado_item === 'LISTO' || order.indexOf(ticket.estado_item) > order.indexOf(step);
}

function stepClass(ticket: Ticket, step: ProcessStep) {
  if (isStepComplete(ticket, step)) return 'prep-step--done';
  return ticket.estado_item === step ? 'prep-step--current' : 'prep-step--upcoming';
}

function canCancel(ticket: Ticket) {
  return ticket.estado_item === 'PENDIENTE' || ticket.estado_item === 'EN_PREPARACION';
}

function imageUrl(value: string) {
  const imagePath = value.trim();
  if (/^https?:\/\//i.test(imagePath)) return imagePath;
  const apiBase = import.meta.env.VITE_API_BASE || 'http://localhost:8000/api/v1';
  const assetOrigin = apiBase.replace(/\/api\/v1\/?$/, '').replace(/\/+$/, '');
  return `${assetOrigin}/${imagePath.replace(/^\/+/, '')}`;
}

function markImageError(idDetalle: number) {
  failedImages.value.add(idDetalle);
}

function openDetails(ticket: Ticket) {
  selectedComandaId.value = null;
  selectedId.value = ticket.id_detalle;
  cancelMode.value = false;
  cancelReason.value = '';
}

function openCancel(ticket: Ticket) {
  openDetails(ticket);
  cancelMode.value = true;
}

function openCancelCommand(group: OrderGroup) {
  selectedId.value = null;
  selectedComandaId.value = group.id_comanda;
  cancelReason.value = '';
}

function closeDetails() {
  selectedId.value = null;
  selectedComandaId.value = null;
  cancelMode.value = false;
  cancelReason.value = '';
}

async function cancelSelected() {
  const ticket = selectedTicket.value;
  if (!ticket || !auth.stationId || cancelReason.value.trim().length < 3) return;

  const cancelled = await queue.cancelItem(ticket.id_detalle, cancelReason.value.trim(), auth.stationId);
  if (cancelled) closeDetails();
}

async function cancelSelectedCommand() {
  const comanda = selectedComanda.value;
  if (!comanda || !auth.stationId || cancelReason.value.trim().length < 3) return;

  const cancelled = await queue.cancelComanda(comanda.id_comanda, cancelReason.value.trim(), auth.stationId);
  if (cancelled) closeDetails();
}

function logout() {
  auth.logout();
  queue.$reset();
  void router.replace({ name: 'login' });
}

onMounted(async () => {
  clockTimer = window.setInterval(() => { now.value = Date.now(); }, 1000);
  await refresh();
  queueTimer = window.setInterval(() => {
    if (document.visibilityState === 'visible' && auth.stationId) void queue.load(auth.stationId);
  }, 15000);
});
onUnmounted(() => {
  window.clearInterval(clockTimer);
  window.clearInterval(queueTimer);
});
</script>
