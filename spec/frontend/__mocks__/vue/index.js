import Vue from 'vue';

Vue.config.productionTip = false;
Vue.config.devtools = false;

export default Vue;
// 'vue' resolves to the vue3compat wrapper, which re-exports the CommonJS @vue/compat.
// eslint-disable-next-line import-x/export
export * from 'vue';
