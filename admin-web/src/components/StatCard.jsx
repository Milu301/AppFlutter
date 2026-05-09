import React from 'react'

const colorConfig = {
  primary: {
    border: 'border-l-primary',
    iconBg: 'bg-primary/15',
    iconRing: 'ring-1 ring-primary/20',
    iconText: 'text-primary',
    glow: 'shadow-[0_0_28px_rgba(108,99,255,0.1)]',
    hoverGlow: 'hover:shadow-[0_4px_32px_rgba(108,99,255,0.22)]',
    valueColor: 'text-textPrimary',
  },
  success: {
    border: 'border-l-success',
    iconBg: 'bg-success/15',
    iconRing: 'ring-1 ring-success/20',
    iconText: 'text-success',
    glow: 'shadow-[0_0_28px_rgba(0,212,160,0.08)]',
    hoverGlow: 'hover:shadow-[0_4px_32px_rgba(0,212,160,0.20)]',
    valueColor: 'text-success',
  },
  error: {
    border: 'border-l-error',
    iconBg: 'bg-error/15',
    iconRing: 'ring-1 ring-error/20',
    iconText: 'text-error',
    glow: 'shadow-[0_0_28px_rgba(255,92,114,0.08)]',
    hoverGlow: 'hover:shadow-[0_4px_32px_rgba(255,92,114,0.20)]',
    valueColor: 'text-error',
  },
  warning: {
    border: 'border-l-warning',
    iconBg: 'bg-warning/15',
    iconRing: 'ring-1 ring-warning/20',
    iconText: 'text-warning',
    glow: 'shadow-[0_0_28px_rgba(255,176,32,0.08)]',
    hoverGlow: 'hover:shadow-[0_4px_32px_rgba(255,176,32,0.20)]',
    valueColor: 'text-warning',
  },
  info: {
    border: 'border-l-info',
    iconBg: 'bg-info/15',
    iconRing: 'ring-1 ring-info/20',
    iconText: 'text-info',
    glow: 'shadow-[0_0_28px_rgba(62,207,255,0.08)]',
    hoverGlow: 'hover:shadow-[0_4px_32px_rgba(62,207,255,0.20)]',
    valueColor: 'text-info',
  },
}

export default function StatCard({ title, value, subtitle, icon, color = 'primary', loading = false, trend }) {
  const c = colorConfig[color] || colorConfig.primary

  if (loading) {
    return (
      <div className={`bg-surfaceCard border border-border border-l-4 ${c.border} rounded-xl p-5 ${c.glow}`}>
        <div className="flex items-start justify-between mb-4">
          <div className="skeleton h-4 w-28 rounded" />
          <div className="skeleton w-11 h-11 rounded-xl" />
        </div>
        <div className="space-y-2.5">
          <div className="skeleton h-7 w-32 rounded" />
          <div className="skeleton h-3.5 w-20 rounded" />
        </div>
      </div>
    )
  }

  return (
    <div
      className={`bg-surfaceCard border border-border border-l-4 ${c.border} rounded-xl p-5 ${c.glow} ${c.hoverGlow} transition-all duration-300 group cursor-default`}
      onMouseEnter={e => (e.currentTarget.style.transform = 'translateY(-2px)')}
      onMouseLeave={e => (e.currentTarget.style.transform = '')}
    >
      <div className="flex items-start justify-between mb-3">
        <p className="text-sm font-medium text-textSecondary leading-snug pr-2">{title}</p>
        {icon && (
          <div className={`w-11 h-11 rounded-xl ${c.iconBg} ${c.iconRing} flex items-center justify-center flex-shrink-0 ${c.iconText}`}>
            {icon}
          </div>
        )}
      </div>

      <p className={`text-2xl font-bold tracking-tight mb-1.5 ${c.valueColor}`}>{value ?? '—'}</p>

      <div className="flex items-center gap-2 flex-wrap">
        {subtitle && (
          <p className="text-xs text-textMuted">{subtitle}</p>
        )}
        {trend != null && (
          <span className={`inline-flex items-center gap-1 text-xs font-semibold px-2 py-0.5 rounded-full ${
            trend > 0 ? 'bg-success/15 text-success' : trend < 0 ? 'bg-error/15 text-error' : 'bg-surfaceBright text-textMuted'
          }`}>
            {trend > 0 ? '↑' : trend < 0 ? '↓' : '—'} {Math.abs(trend)}%
          </span>
        )}
      </div>
    </div>
  )
}
