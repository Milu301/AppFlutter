import React from 'react'

const variants = {
  active:   { bg: 'bg-success/15', text: 'text-success',   dot: 'bg-success',   label: 'Activo' },
  inactive: { bg: 'bg-error/15',   text: 'text-error',     dot: 'bg-error',     label: 'Inactivo' },
  pending:  { bg: 'bg-warning/15', text: 'text-warning',   dot: 'bg-warning',   label: 'Pendiente' },
  paid:     { bg: 'bg-success/15', text: 'text-success',   dot: 'bg-success',   label: 'Pagado' },
  overdue:  { bg: 'bg-error/15',   text: 'text-error',     dot: 'bg-error',     label: 'Vencido' },
  current:  { bg: 'bg-info/15',    text: 'text-info',      dot: 'bg-info',      label: 'Al día' },
  default:  { bg: 'bg-surfaceBright', text: 'text-textSecondary', dot: 'bg-textMuted', label: '' },
  income:   { bg: 'bg-success/15', text: 'text-success',   dot: 'bg-success',   label: 'Ingreso' },
  expense:  { bg: 'bg-error/15',   text: 'text-error',     dot: 'bg-error',     label: 'Egreso' },
  info:     { bg: 'bg-info/15',    text: 'text-info',      dot: 'bg-info',      label: '' },
  warning:  { bg: 'bg-warning/15', text: 'text-warning',   dot: 'bg-warning',   label: '' },
  primary:  { bg: 'bg-primary/15', text: 'text-primary',   dot: 'bg-primary',   label: '' },
}

export default function Badge({ status, label, variant, showDot = true, size = 'sm' }) {
  const key = variant || (status ? status.toLowerCase() : 'default')
  const style = variants[key] || variants.default
  const displayLabel = label || style.label || status || ''

  const sizeClass = size === 'xs'
    ? 'text-xs px-2 py-0.5'
    : 'text-xs px-2.5 py-1'

  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full font-medium ${sizeClass} ${style.bg} ${style.text}`}>
      {showDot && (
        <span className={`w-1.5 h-1.5 rounded-full ${style.dot} flex-shrink-0`} />
      )}
      {displayLabel}
    </span>
  )
}
