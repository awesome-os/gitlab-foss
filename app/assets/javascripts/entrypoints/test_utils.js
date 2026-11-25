import { Sortable } from 'sortablejs';
import simulateDrag from '~/test_utils/simulate_drag';

// Export to global space for rspec to use
window.simulateDrag = simulateDrag;
window.Sortable = Sortable;
// Monaco is large, so specs load it only when they need it.
// Pages with an editor have already loaded it, so the promise resolves at once.
window.loadLocalMonaco = () => import('monaco-editor').then(({ editor }) => editor);
