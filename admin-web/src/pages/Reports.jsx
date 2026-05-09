import React, { useState, useCallback } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { adminAPI } from '../api/client'
import DataTable from '../components/DataTable'
import Badge from '../components/Badge'
import { currency, pct, formatDate } from '../utils/formatters'

const TABS = [
  { id: 'collections', label: 'Cobros' },
  { id: 'late-clients', label: 'Clientes con mora' },
  { id: 'vendor-performance', label: 'Desempeño vendedores' },
]

function exportCSV(data, filename) {
  if (!data || data.length === 0) return
  const keys = Object.keys(data[0])
  const header = keys.join(',')
  const rows = data.map(row =>
    keys.map(k => {
      const v = row[k]
      if (v == null) return ''
      if (typeof v === 'string' && (v.includes(',') || v.includes('"') || v.includes('\n'))) {
        return `"${v.replace(/"/g, '""')}"`
      }
      return v
    }).join(',')
  )
  const csv = [header, ...rows].join('\n')
  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${filename}_${new Date().toISOString().split('T')[0]}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function CollectionsTab({ adminId }) {
  const [data, setData] = useState([])
  const [loading, setLoading] = useState(false)
  const [loaded, setLoaded] = useState(false)
  const [error, setError] = useState(null)
  const [params, setParams] = useState({ startDate: '', endDate: '' })

  const loadData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data: d } = await adminAPI.getCollectionsReport(adminId, {
        start_date: params.startDate,
        end_date: params.endDate,
      })
      setData(Array.isArray(d) ? d : d.data || d.collections || [])
      setLoaded(true)
    } catch (err) {
      setError(err.response?.data?.message || 'Error al cargar reporte')
    } finally {
      setLoading(false)
    }
  }, [adminId, params])

  const cols = [
    { key: 'date', label: 'Fecha', render: (v) => <span className="text-sm">{formatDate(v)}</span> },
    { key: 'vendor', label: 'Vendedor', render: (v, r) => <span className="text-sm">{v || r.vendorName || r.vendor_name || '—'}</span> },
    { key: 'client', label: 'Cliente', render: (v, r) => <span className="text-sm">{v || r.clientName || r.client_name || '—'}</span> },
    { key: 'amount', label: 'Monto cobrado', render: (v) => <span className="font-semibold text-success text-sm">{currency(v)}</span> },
    {
      key: 'status',
      label: 'Estado',
      render: (v) => {
        const map = { on_time: 'current', late: 'overdue', pending: 'pending', paid: 'paid' }
        return <Badge status={map[v] || 'default'} label={v || '—'} />
      },
    },
    { key: 'installment', label: 'Cuota #', render: (v) => <span className="text-xs font-mono text-textSecondary">{v || '—'}</span> },
  ]

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-3 bg-surfaceBright border border-border rounded-xl p-3">
          <div>
            <label className="text-xs text-textMuted block mb-1">Desde</label>
            <input type="date" value={params.startDate} onChange={e => setParams(p => ({ ...p, startDate: e.target.value }))}
              className="bg-transparent text-textPrimary text-sm focus:outline-none cursor-pointer" style={{ colorScheme: 'dark' }} />
          </div>
          <span className="text-textMuted">→</span>
          <div>
            <label className="text-xs text-textMuted block mb-1">Hasta</label>
            <input type="date" value={params.endDate} onChange={e => setParams(p => ({ ...p, endDate: e.target.value }))}
              className="bg-transparent text-textPrimary text-sm focus:outline-none cursor-pointer" style={{ colorScheme: 'dark' }} />
          </div>
        </div>
        <button onClick={loadData} disabled={loading} className="btn-primary text-sm">
          {loading ? 'Cargando...' : 'Generar reporte'}
        </button>
        {loaded && data.length > 0 && (
          <button onClick={() => exportCSV(data, 'cobros')} className="btn-secondary text-sm">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
            Exportar CSV
          </button>
        )}
      </div>
      {error && <div className="px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm">{error}</div>}
      {loaded && (
        <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
          <div className="px-5 py-3 border-b border-border flex items-center justify-between">
            <span className="text-sm font-semibold text-textPrimary">Resultados</span>
            <span className="text-xs text-textMuted">{data.length} registros</span>
          </div>
          <DataTable columns={cols} data={data} loading={loading} emptyMessage="No hay cobros en el período seleccionado" keyField="id" />
        </div>
      )}
      {!loaded && !loading && (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" className="w-8 h-8 text-primary">
              <path d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <p className="text-textSecondary text-sm">Selecciona un rango de fechas y genera el reporte</p>
        </div>
      )}
    </div>
  )
}

function LateClientsTab({ adminId }) {
  const [data, setData] = useState([])
  const [loading, setLoading] = useState(false)
  const [loaded, setLoaded] = useState(false)
  const [error, setError] = useState(null)

  const loadData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data: d } = await adminAPI.getLateClientsReport(adminId)
      setData(Array.isArray(d) ? d : d.data || d.clients || [])
      setLoaded(true)
    } catch (err) {
      setError(err.response?.data?.message || 'Error al cargar reporte')
    } finally {
      setLoading(false)
    }
  }, [adminId])

  const cols = [
    { key: 'clientName', label: 'Cliente', render: (v, r) => <span className="font-medium text-sm">{v || r.name || r.client_name || '—'}</span> },
    { key: 'phone', label: 'Teléfono', render: (v, r) => <span className="font-mono text-xs text-textSecondary">{v || r.phoneNumber || '—'}</span> },
    { key: 'vendor', label: 'Vendedor', render: (v, r) => <span className="text-sm text-textSecondary">{v || r.vendorName || '—'}</span> },
    { key: 'daysLate', label: 'Días vencido', render: (v, r) => {
      const days = v ?? r.days_late ?? 0
      const color = days > 30 ? 'text-error' : days > 15 ? 'text-warning' : 'text-textSecondary'
      return <span className={`font-semibold text-sm ${color}`}>{days} días</span>
    }},
    { key: 'overdueAmount', label: 'Monto vencido', render: (v, r) => <span className="font-semibold text-error text-sm">{currency(v ?? r.overdue_amount)}</span> },
    { key: 'totalDebt', label: 'Deuda total', render: (v, r) => <span className="text-sm text-warning">{currency(v ?? r.total_debt ?? r.balance)}</span> },
  ]

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3 flex-wrap">
        <button onClick={loadData} disabled={loading} className="btn-primary text-sm">
          {loading ? 'Cargando...' : 'Ver clientes con mora'}
        </button>
        {loaded && data.length > 0 && (
          <button onClick={() => exportCSV(data, 'clientes_mora')} className="btn-secondary text-sm">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
            Exportar CSV
          </button>
        )}
      </div>
      {error && <div className="px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm">{error}</div>}
      {loaded && (
        <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
          <div className="px-5 py-3 border-b border-border flex items-center justify-between">
            <span className="text-sm font-semibold text-textPrimary">Clientes en mora</span>
            <span className="text-xs text-error font-medium">{data.length} clientes</span>
          </div>
          <DataTable columns={cols} data={data} loading={loading} emptyMessage="No hay clientes con mora" keyField="id" />
        </div>
      )}
      {!loaded && !loading && (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <div className="w-16 h-16 rounded-2xl bg-error/10 flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" className="w-8 h-8 text-error">
              <path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <p className="text-textSecondary text-sm">Haz clic en "Ver clientes con mora" para cargar el reporte</p>
        </div>
      )}
    </div>
  )
}

function VendorPerformanceTab({ adminId }) {
  const [data, setData] = useState([])
  const [loading, setLoading] = useState(false)
  const [loaded, setLoaded] = useState(false)
  const [error, setError] = useState(null)

  const loadData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data: d } = await adminAPI.getVendorPerformanceReport(adminId)
      setData(Array.isArray(d) ? d : d.data || d.vendors || [])
      setLoaded(true)
    } catch (err) {
      setError(err.response?.data?.message || 'Error al cargar reporte')
    } finally {
      setLoading(false)
    }
  }, [adminId])

  const cols = [
    { key: 'name', label: 'Vendedor', render: (v, r) => <span className="font-medium text-sm">{v || r.vendorName || '—'}</span> },
    { key: 'clients', label: 'Clientes', render: (v, r) => <span className="text-sm font-mono">{v ?? r.client_count ?? '—'}</span> },
    { key: 'activeCredits', label: 'Créditos activos', render: (v, r) => <span className="text-sm font-mono text-info">{v ?? r.active_credits ?? '—'}</span> },
    { key: 'collected', label: 'Cobrado', render: (v, r) => <span className="font-semibold text-success text-sm">{currency(v ?? r.total_collected)}</span> },
    { key: 'portfolio', label: 'Cartera', render: (v, r) => <span className="font-semibold text-primary text-sm">{currency(v ?? r.total_portfolio)}</span> },
    { key: 'collectionRate', label: 'Tasa cobro', render: (v, r) => {
      const rate = v ?? r.collection_rate
      const color = rate > 90 ? 'text-success' : rate > 70 ? 'text-warning' : 'text-error'
      return <span className={`font-semibold text-sm ${color}`}>{pct(rate)}</span>
    }},
    { key: 'overdueClients', label: 'En mora', render: (v, r) => {
      const n = v ?? r.overdue_clients ?? 0
      return <span className={`font-semibold text-sm ${n > 0 ? 'text-error' : 'text-textMuted'}`}>{n}</span>
    }},
  ]

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3 flex-wrap">
        <button onClick={loadData} disabled={loading} className="btn-primary text-sm">
          {loading ? 'Cargando...' : 'Ver desempeño'}
        </button>
        {loaded && data.length > 0 && (
          <button onClick={() => exportCSV(data, 'desempeno_vendedores')} className="btn-secondary text-sm">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
            Exportar CSV
          </button>
        )}
      </div>
      {error && <div className="px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm">{error}</div>}
      {loaded && (
        <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
          <div className="px-5 py-3 border-b border-border flex items-center justify-between">
            <span className="text-sm font-semibold text-textPrimary">Desempeño por vendedor</span>
            <span className="text-xs text-textMuted">{data.length} vendedores</span>
          </div>
          <DataTable columns={cols} data={data} loading={loading} emptyMessage="No hay datos de desempeño" keyField="id" />
        </div>
      )}
      {!loaded && !loading && (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <div className="w-16 h-16 rounded-2xl bg-success/10 flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" className="w-8 h-8 text-success">
              <path d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <p className="text-textSecondary text-sm">Haz clic en "Ver desempeño" para cargar el reporte</p>
        </div>
      )}
    </div>
  )
}

export default function Reports() {
  const { admin } = useAuth()
  const adminId = admin?.adminId || admin?.id
  const [activeTab, setActiveTab] = useState('collections')

  return (
    <div className="space-y-6">
      <div>
        <h2 className="section-title">Reportes</h2>
        <p className="text-textMuted text-sm mt-0.5">Análisis y estadísticas operativas</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-surfaceCard border border-border rounded-xl p-1">
        {TABS.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex-1 py-2 px-4 rounded-lg text-sm font-medium transition-all duration-200 ${
              activeTab === tab.id
                ? 'bg-primary text-white shadow-glow'
                : 'text-textSecondary hover:text-textPrimary hover:bg-surfaceBright'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div className="animate-fade-in">
        {activeTab === 'collections' && <CollectionsTab adminId={adminId} />}
        {activeTab === 'late-clients' && <LateClientsTab adminId={adminId} />}
        {activeTab === 'vendor-performance' && <VendorPerformanceTab adminId={adminId} />}
      </div>
    </div>
  )
}
