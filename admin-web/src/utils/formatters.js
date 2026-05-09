const LOCALE = 'es-MX'

export function currency(n, { code = 'MXN', decimals = 0 } = {}) {
  if (n == null || n === '') return '—'
  return new Intl.NumberFormat(LOCALE, {
    style: 'currency',
    currency: code,
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(n)
}

export function fmt(n, opts = {}) {
  if (n == null) return '—'
  return new Intl.NumberFormat(LOCALE, opts).format(n)
}

export function pct(n, decimals = 1) {
  if (n == null) return '—'
  return `${Number(n).toFixed(decimals)}%`
}

export function formatDate(d, opts = { year: 'numeric', month: 'short', day: 'numeric' }) {
  if (!d) return '—'
  try {
    return new Date(d).toLocaleDateString(LOCALE, opts)
  } catch {
    return '—'
  }
}

export function formatDateTime(d) {
  if (!d) return '—'
  try {
    return new Date(d).toLocaleString(LOCALE, {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit',
    })
  } catch {
    return '—'
  }
}
