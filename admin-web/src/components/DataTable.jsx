import React, { useState, useMemo } from 'react'

function SortIcon({ direction }) {
  if (!direction) return (
    <svg className="w-3.5 h-3.5 text-textMuted opacity-50" viewBox="0 0 14 14" fill="none">
      <path d="M7 2v10M4 5l3-3 3 3M4 9l3 3 3-3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
  return direction === 'asc' ? (
    <svg className="w-3.5 h-3.5 text-primary" viewBox="0 0 14 14" fill="none">
      <path d="M4 9l3-6 3 6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ) : (
    <svg className="w-3.5 h-3.5 text-primary" viewBox="0 0 14 14" fill="none">
      <path d="M4 5l3 6 3-6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

export default function DataTable({
  columns,
  data = [],
  loading = false,
  emptyMessage = 'No hay datos disponibles',
  pageSize = 15,
  onRowClick,
  keyField = 'id',
  className = '',
}) {
  const [sortKey, setSortKey] = useState(null)
  const [sortDir, setSortDir] = useState('asc')
  const [page, setPage] = useState(1)

  const handleSort = (key) => {
    if (sortKey === key) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    } else {
      setSortKey(key)
      setSortDir('asc')
    }
    setPage(1)
  }

  const sorted = useMemo(() => {
    if (!sortKey) return data
    return [...data].sort((a, b) => {
      const av = a[sortKey] ?? ''
      const bv = b[sortKey] ?? ''
      const cmp = typeof av === 'number'
        ? av - bv
        : String(av).localeCompare(String(bv), 'es', { numeric: true })
      return sortDir === 'asc' ? cmp : -cmp
    })
  }, [data, sortKey, sortDir])

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize))
  const paginated = sorted.slice((page - 1) * pageSize, page * pageSize)

  const skeletonRows = Array.from({ length: Math.min(pageSize, 6) })

  return (
    <div className={`w-full ${className}`}>
      <div className="overflow-x-auto rounded-xl border border-border">
        <table className="w-full border-collapse text-sm">
          <thead>
            <tr className="border-b border-border bg-surface/60">
              {columns.map((col) => (
                <th
                  key={col.key || col.label}
                  className={`px-4 py-3 text-left text-xs font-semibold text-textSecondary uppercase tracking-wider select-none ${col.sortable !== false && col.key ? 'cursor-pointer hover:text-textPrimary' : ''} ${col.className || ''}`}
                  style={col.width ? { width: col.width } : {}}
                  onClick={col.sortable !== false && col.key ? () => handleSort(col.key) : undefined}
                >
                  <div className="flex items-center gap-1.5">
                    {col.label}
                    {col.sortable !== false && col.key && (
                      <SortIcon direction={sortKey === col.key ? sortDir : null} />
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              skeletonRows.map((_, i) => (
                <tr key={i} className="border-b border-border/50">
                  {columns.map((col) => (
                    <td key={col.key || col.label} className="px-4 py-3.5">
                      <div className="h-4 bg-surfaceBright rounded animate-pulse" style={{ width: col.skeletonWidth || '80%' }} />
                    </td>
                  ))}
                </tr>
              ))
            ) : paginated.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-12 text-center text-textMuted">
                  <div className="flex flex-col items-center gap-2">
                    <svg className="w-8 h-8 opacity-30" viewBox="0 0 24 24" fill="none">
                      <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                    </svg>
                    <span className="text-sm">{emptyMessage}</span>
                  </div>
                </td>
              </tr>
            ) : (
              paginated.map((row, idx) => (
                <tr
                  key={row[keyField] ?? idx}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  className={`border-b border-border/50 transition-colors duration-150 ${onRowClick ? 'cursor-pointer hover:bg-surfaceBright/60' : 'hover:bg-surfaceBright/30'}`}
                >
                  {columns.map((col) => (
                    <td key={col.key || col.label} className={`px-4 py-3.5 text-textPrimary ${col.cellClass || ''}`}>
                      {col.render ? col.render(row[col.key], row) : (
                        <span className="text-sm">{row[col.key] ?? '—'}</span>
                      )}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {!loading && sorted.length > pageSize && (
        <div className="flex items-center justify-between mt-4 px-1">
          <span className="text-xs text-textMuted">
            {(page - 1) * pageSize + 1}–{Math.min(page * pageSize, sorted.length)} de {sorted.length}
          </span>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setPage(1)}
              disabled={page === 1}
              className="px-2 py-1.5 text-xs rounded-lg text-textSecondary hover:bg-surfaceBright disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              «
            </button>
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="px-3 py-1.5 text-xs rounded-lg text-textSecondary hover:bg-surfaceBright disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              Anterior
            </button>
            {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
              let p
              if (totalPages <= 5) p = i + 1
              else if (page <= 3) p = i + 1
              else if (page >= totalPages - 2) p = totalPages - 4 + i
              else p = page - 2 + i
              return (
                <button
                  key={p}
                  onClick={() => setPage(p)}
                  className={`w-8 h-8 text-xs rounded-lg transition-colors ${p === page ? 'bg-primary text-white font-semibold' : 'text-textSecondary hover:bg-surfaceBright'}`}
                >
                  {p}
                </button>
              )
            })}
            <button
              onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="px-3 py-1.5 text-xs rounded-lg text-textSecondary hover:bg-surfaceBright disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              Siguiente
            </button>
            <button
              onClick={() => setPage(totalPages)}
              disabled={page === totalPages}
              className="px-2 py-1.5 text-xs rounded-lg text-textSecondary hover:bg-surfaceBright disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              »
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
