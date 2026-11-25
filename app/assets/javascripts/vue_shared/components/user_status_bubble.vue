<script>
export default {
  name: 'UserStatusBubble',
};
</script>

<template>
  <!-- Keep in sync with the status bubble in app/views/users/show.html.haml -->
  <span
    class="gl-border gl-relative gl-inline-flex gl-min-w-8 gl-max-w-full gl-items-baseline gl-justify-center gl-gap-2 gl-self-start gl-rounded-xl gl-bg-default gl-px-3 gl-py-2 gl-text-sm gl-font-normal gl-leading-normal gl-tracking-wide gl-text-default"
  >
    <svg class="cover-status-tail" width="13" height="7" viewBox="0 0 13 7" aria-hidden="true">
      <path
        d="M13 7 V6.5 C7.43 6.5 4.18 4.3 2.6 1.1 Q1.95 -0.2 1.21 0.7 C1.02 2.8 0.84 4.8 0 6.5 V7"
      />
    </svg>
    <slot />
  </span>
</template>
