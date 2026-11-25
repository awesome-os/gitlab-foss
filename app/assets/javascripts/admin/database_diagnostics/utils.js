import { HTTP_STATUS_UNAUTHORIZED } from '~/lib/utils/http_status';
import { formatNumber, s__ } from '~/locale';

// Severity strings come from Gitlab::Database::Diagnostics::Findings.
const SEVERITY_VARIANTS = {
  error: 'danger',
  warning: 'warning',
};

const SEVERITY_ICONS = {
  error: { name: 'error', variant: 'danger' },
  warning: { name: 'warning', variant: 'warning' },
};

// An unknown severity renders as a warning, so a severity added to the backend
// stays visible here.
export const severityVariant = (severity) => SEVERITY_VARIANTS[severity] || 'warning';

// No severity means the check found nothing, so the icon reports success. An
// unknown one falls back to a warning, as severityVariant does.
export const severityIcon = (severity) => {
  if (!severity) return { name: 'check-circle-filled', variant: 'success' };

  return SEVERITY_ICONS[severity] || SEVERITY_ICONS.warning;
};

// After a check is run, the cache holds the previous run's result until the new job
// replaces it, so a poll only takes a result that the job it started wrote. A result
// with no job ID comes from a worker that did not record one yet and is taken as is.
export const isResultOfJob = (data, jobId) => {
  const resultJobId = data?.metadata?.job_id;

  return !jobId || !resultJobId || resultJobId === jobId;
};

// pg_ash leaves values empty when it reads a source coarser than a minute.
const formatOrNotAvailable = (value, options) =>
  value === null ? s__('DatabaseDiagnostics|Not available') : formatNumber(value, options);

export const formatActiveSessions = (value) =>
  formatOrNotAvailable(value, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export const formatShareOfLoad = (pct) =>
  formatOrNotAvailable(pct === null ? null : pct / 100, {
    style: 'percent',
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  });

// While admin mode is inactive, the endpoints answer 401 with a message that says so,
// which Retry cannot fix until the admin re-authenticates.
export const activeSessionHistoryErrorMessage = (error, fallback) =>
  (error?.response?.status === HTTP_STATUS_UNAUTHORIZED && error.response.data?.message) ||
  fallback;

// Both active session history tables set these widths on their columns, so their
// number columns line up.
export const activeSessionHistoryNumberFields = () =>
  [
    { key: 'pct', label: s__('DatabaseDiagnostics|Share of load'), width: '@md/panel:gl-w-1/8' },
    {
      key: 'avg_aas',
      label: s__('DatabaseDiagnostics|Average active sessions'),
      width: '@md/panel:gl-w-1/6',
    },
    {
      key: 'peak_aas',
      label: s__('DatabaseDiagnostics|Peak active sessions'),
      width: '@md/panel:gl-w-1/6',
    },
  ].map(({ width, ...field }) => ({
    ...field,
    columnClass: width,
    thClass: 'gl-text-right',
    tdClass: 'gl-text-right',
  }));
