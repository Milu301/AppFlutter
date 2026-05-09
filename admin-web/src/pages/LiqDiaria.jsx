import React, { useEffect, useState, useCallback } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { adminAPI } from '../api/client'

// ─── helpers ────────────────────────────────────────────────────────────── //

const fmt = (n) => (n == null ? '—' : new Intl.NumberFormat('es-MX').format(n))

const money = (n) => {
  if (n == null) return '—'
  return new Intl.NumberFormat('es-MX', {
    style: 'currency', currency: 'MXN',
    minimumFractionDigits: 2, maximumFractionDigits: 2,
  }).format(n)
}

const fmtDatetime = (d) => {
  if (!d) return null
  try { return new Date(d).toLocaleString('es-MX') } catch { return String(d) }
}

const todayISO = () => new Date().toISOString().slice(0, 10)

const FREQ_LABEL = { daily: 'Diaria', weekly: 'Semanal', once: 'Única' }

function Spinner({ cls = 'w-5 h-5' }) {
  return (
    <svg className={`animate-spin ${cls}`} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" className="opacity-25" />
      <path d="M4 12a8 8 0 018-8" stroke="currentColor" strokeWidth="4" className="opacity-75" />
    </svg>
  )
}

// ─── LiqDiariaTab primitives ─────────────────────────────────────────────── //

function SectionTitle({ children }) {
  return (
    <div className="flex items-center gap-2 pt-3 pb-0.5">
      <span className="h-px flex-1 bg-border/50" />
      <span className="text-[10px] font-bold text-textMuted uppercase tracking-widest">{children}</span>
      <span className="h-px flex-1 bg-border/50" />
    </div>
  )
}

function StatRow({ label, value, valueClass = '', bold = false, children }) {
  return (
    <div className="flex items-start justify-between gap-4 py-1 px-2 rounded hover:bg-surfaceBright/30 transition-colors min-h-[28px]">
      <span className="text-xs text-textMuted shrink-0 mt-0.5">{label}</span>
      <div className={`text-sm text-right leading-snug
        ${bold ? 'font-semibold text-textPrimary' : 'text-textSecondary'} ${valueClass}`}>
        {children ?? value}
      </div>
    </div>
  )
}

function DateBadge({ value }) {
  if (!value) return <span className="text-xs text-textMuted">—</span>
  return (
    <span className="inline-flex items-center gap-1.5 text-xs px-2 py-0.5 rounded-full bg-success/15 text-success border border-success/30 font-medium">
      <span className="w-1.5 h-1.5 rounded-full bg-success flex-shrink-0" />
      {fmtDatetime(value)}
    </span>
  )
}

function PctBadge({ pct }) {
  return (
    <span className="inline-flex items-center text-[10px] px-1.5 py-0.5 rounded-full bg-success/15 text-success border border-success/30 font-bold ml-1.5">
      {pct}%
    </span>
  )
}

function RedDot() {
  return (
    <svg viewBox="0 0 8 8" fill="currentColor" className="w-2.5 h-2.5 text-error inline-block mr-1 flex-shrink-0">
      <circle cx="4" cy="4" r="4" />
    </svg>
  )
}

// ════════════════════════════════════════════════════════════════════════════
//  LiqDiariaTab
// ════════════════════════════════════════════════════════════════════════════
function LiqDiariaTab({ routeDay, vendorStats, vendor }) {
  const t  = routeDay?.totals    || {}
  const s  = vendorStats         || {}
  const rd = routeDay            || {}

  const isClosed = !!rd.close_time

  const recaudoPretendido = t.due_total  ?? 0
  const recaudoActual     = t.paid_today ?? 0
  const pctActual = recaudoPretendido > 0
    ? ((recaudoActual / recaudoPretendido) * 100).toFixed(1)
    : '0.0'

  const initialClients  = rd.initial_clients  ?? 0
  const syncedClients   = rd.synced_clients   ?? 0
  const newClients      = rd.new_clients      ?? 0
  const renewedClients  = rd.renewed_clients  ?? 0
  const income          = rd.income           ?? 0
  const withdrawals     = rd.withdrawals      ?? 0
  const expenses        = rd.expenses         ?? 0

  return (
    <div className="space-y-0.5">

      {/* ── Identificación ── */}
      <SectionTitle>Identificación</SectionTitle>

      <StatRow label="Vendedor" bold>
        <span className="flex items-center gap-1.5 flex-wrap justify-end">
          <span>{vendor?.name || '—'}</span>
          {rd.vendor_code && (
            <span className="text-textMuted font-normal text-xs">— Cod: {rd.vendor_code}</span>
          )}
          <button
            className="p-0.5 rounded text-textMuted hover:text-textSecondary hover:bg-surfaceBright transition-colors"
            title="Exportar Excel"
          >
            <svg viewBox="0 0 16 16" fill="none" className="w-3.5 h-3.5">
              <rect x="2" y="1" width="12" height="14" rx="1.5" stroke="currentColor" strokeWidth="1.3" />
              <path d="M5 5l2 3 2-3M9 5H7M7 8v3" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
        </span>
      </StatRow>

      <StatRow label="Fecha de Inicio de Cobro">
        <DateBadge value={rd.start_time} />
      </StatRow>

      <StatRow label="Fecha de Cierre de Cobro">
        {rd.close_time
          ? <DateBadge value={rd.close_time} />
          : <span className="text-xs text-textMuted italic">Sistema sin Cerrar</span>}
      </StatRow>

      <StatRow label="Fecha de Último Acceso Móvil">
        <DateBadge value={rd.last_mobile_access} />
      </StatRow>

      {/* ── Cartera ── */}
      <SectionTitle>Cartera</SectionTitle>

      <StatRow label="Clientes Iniciales">
        <span className="flex items-center gap-1.5">
          <span>{initialClients}</span>
          <span className="text-xs text-textMuted">
            ({syncedClients} Sincronizados / {initialClients})
          </span>
          <button className="p-0.5 rounded text-textMuted hover:bg-surfaceBright transition-colors" title="Sincronizar">
            <svg viewBox="0 0 14 14" fill="none" className="w-3 h-3">
              <path d="M1 7a6 6 0 019.9-4.5M13 7a6 6 0 01-9.9 4.5M13 3v3.5h-3.5M1 11V7.5h3.5"
                stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
        </span>
      </StatRow>

      <StatRow label="Clientes Nuevos/Renovados">
        <span>
          {newClients + renewedClients}
          <span className="text-xs text-textMuted ml-1">({newClients}/{renewedClients})</span>
        </span>
      </StatRow>

      <StatRow label="Pago Aplazado Sig. Día"  value={fmt(rd.deferred_next_day ?? 0)} />
      <StatRow label="Clientes Cancelados"      value={fmt(rd.cancelled_clients  ?? 0)} />
      <StatRow label="Total de Clientes" bold   value={fmt(rd.total_clients ?? s.clients?.total ?? 0)} />

      {/* ── Caja y Cartera Inicial ── */}
      <SectionTitle>Caja y Cartera Inicial</SectionTitle>
      <StatRow label="Caja Inicial"    bold value={money(rd.initial_cash      ?? 0)} />
      <StatRow label="Cartera Inicial" bold value={money(rd.initial_portfolio ?? s.credits?.total_portfolio ?? 0)} />

      {/* ── Recaudo ── */}
      <SectionTitle>Recaudo</SectionTitle>

      <StatRow label="Recaudo Pretendido del Día" bold>
        <span className="flex items-center">
          {money(recaudoPretendido)}
          <PctBadge pct={100} />
        </span>
      </StatRow>

      <StatRow label="Recaudo Actual del Día" bold>
        <span className="flex items-center gap-2 flex-wrap justify-end">
          <span className="text-success font-semibold">{money(recaudoActual)}</span>
          <span className="text-warning text-xs">({pctActual}%)</span>
          <span className="text-xs text-textMuted">Pagos: {t.paid_count ?? 0}</span>
          <span className="text-xs text-textMuted">No Pagos: {t.no_paid_count ?? 0}</span>
        </span>
      </StatRow>

      <StatRow label="Recaudo Por Tipo de Pago">
        <span className="flex items-center gap-3 flex-wrap justify-end text-xs">
          <span>
            Efectivo:&nbsp;
            <span className="font-medium text-info">({money(t.cash_collected ?? 0)})</span>
          </span>
          <span>
            Transferencia:&nbsp;
            <span className="font-medium text-primary">({money(t.transfer_collected ?? 0)})</span>
          </span>
        </span>
      </StatRow>

      {/* ── Ventas ── */}
      <SectionTitle>Ventas</SectionTitle>
      <StatRow label="Ventas">
        <span>
          {money(rd.sales ?? 0)}
          <span className="text-xs text-textMuted ml-1">(Interés {money(rd.sales_interest ?? 0)})</span>
        </span>
      </StatRow>

      {/* ── Movimientos ── */}
      <SectionTitle>Movimientos</SectionTitle>
      <StatRow label="Ingresos" valueClass="text-success">+{money(income)}</StatRow>
      <StatRow label="Retiros"  valueClass="text-error">−{money(withdrawals)}</StatRow>
      <StatRow label="Egresos"  valueClass="text-error">−{money(expenses)}</StatRow>

      {/* ── Cierre ── */}
      <SectionTitle>Cierre</SectionTitle>

      <StatRow label="Caja Final" bold>
        <span className="flex items-center gap-1">
          {!isClosed && <RedDot />}
          <span className={!isClosed ? 'text-error' : 'text-textPrimary'}>
            {money(rd.final_cash ?? 0)}
          </span>
        </span>
      </StatRow>

      <StatRow label="Cartera Final" bold>
        <span className="flex items-center gap-1 flex-wrap justify-end">
          {!isClosed && <RedDot />}
          <span className={!isClosed ? 'text-error' : 'text-textPrimary'}>
            {money(rd.final_portfolio ?? 0)}
          </span>
          <span className="text-xs text-textMuted">(Sanción {money(rd.penalty ?? 0)})</span>
        </span>
      </StatRow>
    </div>
  )
}

// ════════════════════════════════════════════════════════════════════════════
//  PagosTab
// ════════════════════════════════════════════════════════════════════════════
const INIT_PAGOS = { consecutivo: '', nombres: '', apellidos: '', documento: '', tipo: '', estado: '' }

function PagosTab({ clients, totals }) {
  const allRows = clients || []
  const [filters, setFilters]   = useState(INIT_PAGOS)
  const [filtered, setFiltered] = useState(allRows)

  useEffect(() => { setFiltered(allRows) }, [clients]) // eslint-disable-line react-hooks/exhaustive-deps

  const applyFilters = (f, rows) => rows.filter(c => {
    const name   = (c.name || c.fullName || c.full_name || '').toLowerCase()
    const consec = String(c.consecutivo || c.credit_id || c.id || '').toLowerCase()
    const doc    = String(c.docId || c.document_id || c.documentId || '').toLowerCase()
    const isPaid = !c.no_payment
    const tipo   = isPaid ? 'Cuota' : 'No Pago'

    if (f.consecutivo && !consec.includes(f.consecutivo.toLowerCase())) return false
    if (f.nombres     && !name.includes(f.nombres.toLowerCase()))       return false
    if (f.apellidos   && !name.includes(f.apellidos.toLowerCase()))     return false
    if (f.documento   && !doc.includes(f.documento.toLowerCase()))      return false
    if (f.tipo        && tipo !== f.tipo)                               return false
    return true
  })

  const handleSearch = () => setFiltered(applyFilters(filters, allRows))
  const handleClear  = () => { setFilters(INIT_PAGOS); setFiltered(allRows) }

  const totalRecaudo   = totals?.paid_today ?? 0
  const totalPretendido = totals?.due_total ?? 0
  const pctTotal = totalPretendido > 0
    ? ((totalRecaudo / totalPretendido) * 100).toFixed(1)
    : '0.0'

  return (
    <div className="space-y-3">
      {/* Summary chips */}
      <div className="flex flex-wrap gap-2">
        {[
          { label: `Pagos: ${totals?.paid_count ?? 0}`,                    cls: 'bg-success/10 text-success border-success/30' },
          { label: `No Pagos: ${totals?.no_paid_count ?? 0}`,              cls: 'bg-error/10 text-error border-error/30' },
          { label: `Efectivo: ${money(totals?.cash_collected ?? 0)}`,      cls: 'bg-info/10 text-info border-info/30' },
          { label: `Transf.: ${money(totals?.transfer_collected ?? 0)}`,   cls: 'bg-primary/10 text-primary border-primary/30' },
        ].map(({ label, cls }) => (
          <span key={label} className={`inline-flex items-center text-xs px-2.5 py-1 rounded-full border font-medium ${cls}`}>
            {label}
          </span>
        ))}
      </div>

      {/* Search bar */}
      <div className="bg-surfaceCard border border-border rounded-xl p-3">
        <div className="flex flex-wrap gap-x-3 gap-y-2 items-end">
          {[
            { key: 'consecutivo', label: 'Consecutivo' },
            { key: 'nombres',     label: 'Nombres'     },
            { key: 'apellidos',   label: 'Apellidos'   },
            { key: 'documento',   label: 'Documento'   },
          ].map(({ key, label }) => (
            <div key={key} className="flex flex-col gap-0.5">
              <label className="text-[10px] font-semibold text-textMuted uppercase tracking-wide">{label}</label>
              <input
                type="text"
                value={filters[key]}
                onChange={e => setFilters(f => ({ ...f, [key]: e.target.value }))}
                onKeyDown={e => e.key === 'Enter' && handleSearch()}
                className="input-field text-xs py-1.5 w-[100px]"
                placeholder="..."
              />
            </div>
          ))}

          <div className="flex flex-col gap-0.5">
            <label className="text-[10px] font-semibold text-textMuted uppercase tracking-wide">Tipo</label>
            <select
              value={filters.tipo}
              onChange={e => setFilters(f => ({ ...f, tipo: e.target.value }))}
              className="input-field text-xs py-1.5 w-[130px]"
            >
              <option value="">-- Selecciones --</option>
              <option value="Cuota">Cuota (Pagó)</option>
              <option value="No Pago">No Pago</option>
            </select>
          </div>

          <div className="flex flex-col gap-0.5">
            <label className="text-[10px] font-semibold text-textMuted uppercase tracking-wide">Estado</label>
            <select
              value={filters.estado}
              onChange={e => setFilters(f => ({ ...f, estado: e.target.value }))}
              className="input-field text-xs py-1.5 w-[130px]"
            >
              <option value="">--- Seleccione ---</option>
              <option value="active">Activo</option>
              <option value="overdue">Vencido</option>
            </select>
          </div>

          <div className="flex gap-2 items-center">
            <button onClick={handleSearch} className="btn-primary text-xs px-4 py-1.5">Buscar</button>
            <button onClick={handleClear}  className="btn-secondary text-xs px-3 py-1.5">Limpiar</button>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1100px]">
            <thead>
              <tr className="border-b border-border bg-surfaceBright/40">
                {[
                  'Nro.', 'Consecutivo', 'Cliente', 'Observaciones', 'Pagadas',
                  'Tipo', 'Forma de Pago', 'Valor', 'Fecha', 'Hora',
                  'Valor Prod.', 'Saldo', 'Restantes', 'Visitas', 'Frecuencia',
                ].map(h => (
                  <th key={h} className="px-2 py-3 text-left text-[10px] font-bold text-textMuted uppercase tracking-wider whitespace-nowrap">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={15} className="py-8 text-center text-textMuted text-sm">
                    Sin registros para mostrar
                  </td>
                </tr>
              ) : (
                filtered.map((c, i) => {
                  const isPaid   = !c.no_payment
                  const tipo     = isPaid ? 'Cuota' : 'No Pago'
                  const payDate  = c.payment_date || c.paid_at
                  const freq     = FREQ_LABEL[c.frequency || c.credit_frequency] || c.frequency || '—'

                  return (
                    <tr key={c.id || i} className="border-b border-border/50 hover:bg-surfaceBright/20 transition-colors">
                      {/* Nro */}
                      <td className="px-2 py-2.5 text-xs text-textMuted">{i + 1}</td>

                      {/* Consecutivo */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs font-mono text-warning">
                          {c.consecutivo || c.credit_id || c.id || '—'}
                        </span>
                      </td>

                      {/* Cliente */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs font-medium text-textPrimary">
                          {c.name || c.fullName || c.full_name || '—'}
                        </span>
                      </td>

                      {/* Observaciones */}
                      <td className="px-2 py-2.5 max-w-[110px]">
                        <span className="text-xs text-textMuted truncate block">{c.observations || '—'}</span>
                      </td>

                      {/* Pagadas */}
                      <td className="px-2 py-2.5 text-center">
                        <span className="text-xs text-textSecondary">{isPaid ? '1.0' : '0.0'}</span>
                      </td>

                      {/* Tipo — coloured cell */}
                      <td className={`px-2 py-2.5 text-center ${isPaid ? 'bg-success' : 'bg-red-600'}`}>
                        <span className="text-white text-xs font-bold">{tipo}</span>
                      </td>

                      {/* Forma de Pago */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs text-textSecondary capitalize">
                          {c.payment_method || c.pay_method || '—'}
                        </span>
                      </td>

                      {/* Valor */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs font-medium text-textPrimary">
                          {money(c.amount_paid ?? c.installment_value)}
                        </span>
                      </td>

                      {/* Fecha */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs text-textSecondary">
                          {payDate ? new Date(payDate).toLocaleDateString('es-MX') : '—'}
                        </span>
                      </td>

                      {/* Hora */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs text-textSecondary">
                          {payDate
                            ? new Date(payDate).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' })
                            : '—'}
                        </span>
                      </td>

                      {/* Valor Prod. */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs text-textSecondary">
                          {money(c.credit_total ?? c.principal)}
                        </span>
                      </td>

                      {/* Saldo */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs text-warning">
                          {money(c.credit_balance ?? c.balance)}
                        </span>
                      </td>

                      {/* Restantes */}
                      <td className="px-2 py-2.5 text-center">
                        <span className="text-xs text-textSecondary">
                          {c.remaining_installments ?? '—'}
                        </span>
                      </td>

                      {/* Visitas */}
                      <td className="px-2 py-2.5 text-center">
                        <span className="text-xs text-textSecondary">
                          {c.visits ?? c.visit_count ?? '—'}
                        </span>
                      </td>

                      {/* Frecuencia */}
                      <td className="px-2 py-2.5">
                        <span className="text-xs text-textSecondary">{freq}</span>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
            {filtered.length > 0 && (
              <tfoot>
                <tr className="border-t border-border bg-surfaceBright/40">
                  <td colSpan={15} className="px-3 py-2.5 text-xs">
                    <span className="text-textMuted font-semibold">TOTAL RECAUDO DEL DIA: </span>
                    <span className="font-bold text-textPrimary">{money(totalRecaudo)}</span>
                    <span className="text-warning font-semibold ml-1">({pctTotal}%)</span>
                  </td>
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      </div>
    </div>
  )
}

// ════════════════════════════════════════════════════════════════════════════
//  ActionPanel (sidebar derecho)
// ════════════════════════════════════════════════════════════════════════════
function ActionPanel({ routeDay }) {
  const gain = routeDay?.totals?.paid_today ?? 0

  const btnCls = 'w-full text-left text-xs font-medium px-3 py-2 rounded-lg border border-border bg-surfaceCard hover:bg-surfaceBright transition-colors text-textSecondary'

  return (
    <div className="flex flex-col gap-1.5 w-48 shrink-0">
      {['Configuraciones', 'Reporte Monitor', 'Lista Clientes', 'Bloquear Unidad', 'M. Intereses'].map(label => (
        <button key={label} className={btnCls}>{label}</button>
      ))}

      <button className={`${btnCls} flex justify-between items-center`}>
        <span>Ganancia</span>
        <span className="text-success font-semibold">{money(gain)}</span>
      </button>

      <button className={btnCls}>App Actualizada</button>

      <div className="mt-1 border border-border rounded-xl p-2.5">
        <p className="text-[9px] font-bold text-textMuted uppercase tracking-widest text-center mb-2">
          Micro Seguro
        </p>
        {['Ingreso Seguros', 'Retiros Seguros', 'Caja Seguros'].map(label => (
          <button key={label} className={`${btnCls} mb-1 last:mb-0`}>{label}</button>
        ))}
      </div>
    </div>
  )
}

// ════════════════════════════════════════════════════════════════════════════
//  Main page
// ════════════════════════════════════════════════════════════════════════════
const TABS = [
  { id: 'liq',   label: 'Liq. Diaria' },
  { id: 'pagos', label: 'Pagos'       },
]

export default function LiqDiaria() {
  const { admin } = useAuth()
  const adminId   = admin?.adminId || admin?.id

  const [vendors,          setVendors]          = useState([])
  const [selectedVendorId, setSelectedVendorId] = useState('')
  const [date,             setDate]             = useState(todayISO())
  const [activeTab,        setActiveTab]        = useState('liq')
  const [routeDay,         setRouteDay]         = useState(null)
  const [vendorStats,      setVendorStats]      = useState(null)
  const [loading,          setLoading]          = useState(false)
  const [error,            setError]            = useState(null)

  // Load vendor list once
  useEffect(() => {
    if (!adminId) return
    adminAPI.getVendors(adminId)
      .then(({ data }) => {
        const list = Array.isArray(data) ? data : data.vendors || data.data || []
        setVendors(list)
        if (list.length > 0 && !selectedVendorId) {
          setSelectedVendorId(String(list[0].id || list[0].vendorId))
        }
      })
      .catch(() => {})
  }, [adminId]) // eslint-disable-line react-hooks/exhaustive-deps

  // Fetch route-day + stats when vendor or date changes
  const fetchData = useCallback(async () => {
    if (!adminId || !selectedVendorId) return
    setLoading(true)
    setError(null)
    try {
      const [rdRes, vsRes] = await Promise.all([
        adminAPI.getVendorRouteDay(adminId, selectedVendorId, date),
        adminAPI.getVendorStats(adminId, selectedVendorId),
      ])
      setRouteDay(rdRes.data)
      setVendorStats(vsRes.data)
    } catch (err) {
      setError(err.response?.data?.message || 'Error al cargar datos del vendedor')
      setRouteDay(null)
      setVendorStats(null)
    } finally {
      setLoading(false)
    }
  }, [adminId, selectedVendorId, date])

  useEffect(() => { fetchData() }, [fetchData])

  const selectedVendor = vendors.find(v => String(v.id || v.vendorId) === selectedVendorId)

  return (
    <div className="space-y-5">
      {/* ── Header / controls ── */}
      <div className="flex items-end justify-between flex-wrap gap-3">
        <h2 className="section-title">Liquidación Diaria</h2>

        <div className="flex flex-wrap items-end gap-3">
          <div className="flex flex-col gap-0.5">
            <label className="text-[10px] font-semibold text-textMuted uppercase tracking-wide">Vendedor</label>
            <select
              value={selectedVendorId}
              onChange={e => setSelectedVendorId(e.target.value)}
              className="input-field text-sm py-1.5 min-w-[180px]"
            >
              {vendors.length === 0 && <option value="">Cargando...</option>}
              {vendors.map(v => (
                <option key={v.id || v.vendorId} value={String(v.id || v.vendorId)}>
                  {v.name || v.fullName || '—'}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-col gap-0.5">
            <label className="text-[10px] font-semibold text-textMuted uppercase tracking-wide">Fecha</label>
            <input
              type="date"
              value={date}
              onChange={e => setDate(e.target.value)}
              className="input-field text-sm py-1.5"
            />
          </div>

          <button
            onClick={fetchData}
            disabled={loading}
            className="btn-secondary text-sm flex items-center gap-1.5 py-1.5"
          >
            <svg viewBox="0 0 20 20" fill="currentColor" className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`}>
              <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
            </svg>
            Actualizar
          </button>
        </div>
      </div>

      {error && (
        <div className="px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm">{error}</div>
      )}

      {loading && !routeDay ? (
        <div className="flex items-center justify-center py-20 text-textMuted gap-2">
          <Spinner /> Cargando datos...
        </div>
      ) : (
        <div className="flex gap-5 items-start">
          {/* Left: tabs + content */}
          <div className="flex-1 min-w-0">
            {/* Tab bar */}
            <div className="flex border-b border-border mb-4">
              {TABS.map(tab => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`px-5 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors
                    ${activeTab === tab.id
                      ? 'border-primary text-primary'
                      : 'border-transparent text-textMuted hover:text-textSecondary'}`}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="bg-surfaceCard border border-border rounded-xl p-4">
              {activeTab === 'liq' && (
                <LiqDiariaTab
                  routeDay={routeDay}
                  vendorStats={vendorStats}
                  vendor={selectedVendor}
                />
              )}
              {activeTab === 'pagos' && (
                <PagosTab
                  clients={routeDay?.clients || []}
                  totals={routeDay?.totals}
                />
              )}
            </div>
          </div>

          {/* Right: action buttons */}
          <ActionPanel routeDay={routeDay} />
        </div>
      )}
    </div>
  )
}
