<template>
  <svg class="sipan-icon" :class="{ 'sipan-icon--lg': large, 'sipan-icon--xl': xl }" :width="size" :height="size" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <template v-if="name === 'logo'">
      <path d="M4 14c1.5 4 5 6 8 6s6.5-2 8-6" /><path d="M5 14h14" /><path d="M8 9c.5-2 2-4 4-4s3.5 2 4 4" /><path d="M12 5V3" />
    </template>
    <template v-else-if="name === 'kitchen'">
      <path d="M8 10a4 4 0 0 1 8 0" /><path d="M6 10h12v2a6 6 0 0 1-12 0z" /><path d="M12 4v2M9 5v2M15 5v2" />
    </template>
    <template v-else-if="name === 'user'"><circle cx="12" cy="8" r="3.5" /><path d="M5 20c1.2-3.5 3.7-5 7-5s5.8 1.5 7 5" /></template>
    <template v-else-if="name === 'lock'"><rect x="5" y="11" width="14" height="10" rx="2" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></template>
    <template v-else-if="name === 'eye'"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" /><circle cx="12" cy="12" r="3" /></template>
    <template v-else-if="name === 'eye-off'"><path d="m3 3 18 18" /><path d="M10.6 10.6a2 2 0 0 0 2.8 2.8" /><path d="M9.9 5.2A10.7 10.7 0 0 1 12 5c6.5 0 10 7 10 7a14 14 0 0 1-3.1 3.9M6.2 6.2A16 16 0 0 0 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4.1-.8" /></template>
    <template v-else-if="name === 'clock'"><circle cx="12" cy="12" r="8" /><path d="M12 8v5l3 2" /></template>
    <template v-else-if="name === 'refresh'"><path d="M20 12a8 8 0 1 1-2.3-5.6" /><path d="M20 4v6h-6" /></template>
    <template v-else-if="name === 'flame'"><path d="M12 3s5 5 5 9a5 5 0 1 1-10 0c0-2 2-4 3-6 1 2 2 2 2 2s-1-3 0-5z" /></template>
    <template v-else-if="name === 'check'"><circle cx="12" cy="12" r="8" /><path d="M8.5 12.5 11 15l4.5-5" /></template>
    <template v-else-if="name === 'salon'"><circle cx="12" cy="11" r="6" /><path d="M8 21v-4M16 21v-4M12 17v4" /></template>
    <template v-else-if="name === 'order'"><path d="M7 3h10v18H7z" /><path d="M10 7h4M10 11h4M10 15h2" /></template>
    <template v-else-if="name === 'close'"><path d="m6 6 12 12M18 6 6 18" /></template>
  </svg>
</template>

<script setup lang="ts">
defineProps<{ name: string; size?: number; large?: boolean; xl?: boolean }>();
</script>
