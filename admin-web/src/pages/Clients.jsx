import React, { useEffect, useState, useCallback, useRef } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { adminAPI, clientAPI } from '../api/client'
import DataTable from '../components/DataTable'
import Modal from '../components/Modal'
import Badge from '../components/Badge'
import { useToast } from '../components/Toast'
import { currency, formatDate } from '../utils/formatters'

// ─── Credits panel ────────────────────────────────────────────────────────────
function CreditsPanel({ client, onClose }) {
  const [credits, setCredits] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    const id = client?.id || client?.clientId
    if (!id) return
    setLoading(true)
    setError(null)
    clientAPI.getCredits(id)
      .then(({ data }) => setCredits(Array.isArray(data) ? data : data.credits || data.data || []))
      .catch(err => setError(err.response?.data?.message || 'Error al cargar créditos'))
      .finally(() => setLoading(false))
  }, [client])

  const cols = [
    { key: 'creditNumber', label: 'Crédito #', render: (v, r) => <span className="font-mono text-xs text-textSecondary">{v || r.id || '—'}</span> },
    { key: 'principal', label: 'Capital', render: (v) => <span className="text-sm font-medium">{currency(v)}</span> },
    { key: 'balance', label: 'Saldo', render: (v, r) => <span className="text-sm font-semibold text-warning">{currency(v ?? r.remaining_balance)}</span> },
    {
      key: 'status',
      label: 'Estado',
      render: (v) => {
        const map = { active: 'current', paid: 'paid', overdue: 'overdue', vencido: 'overdue', al_dia: 'current', pagado: 'paid' }
        return <Badge status={map[v?.toLowerCase()] || v} label={v} />
      },
    },
    {
      key: 'startDate',
      label: 'Inicio',
      render: (v, r) => {
        const d = v || r.start_date || r.created_at
        return <span className="text-xs text-textSecondary">{d ? formatDate(d) : '—'}</span>
      },
    },
    {
      key: 'installments',
      label: 'Cuotas',
      render: (v, r) => {
        const count = Array.isArray(v) ? v.length : (v ?? r.total_installments ?? '—')
        return <span className="text-xs text-textSecondary">{count}</span>
      },
    },
  ]

  return (
    <Modal isOpen={!!client} onClose={onClose} title={`Créditos — ${client?.name || client?.fullName || ''}`} size="xl">
      {error && <div className="mb-4 text-sm text-error">{error}</div>}
      <DataTable columns={cols} data={credits} loading={loading} emptyMessage="Este cliente no tiene créditos" keyField="id" pageSize={10} />
    </Modal>
  )
}

// ─── Reassign modal ───────────────────────────────────────────────────────────
function ReassignModal({ client, adminId, onClose, onSuccess }) {
  const [vendors, setVendors] = useState([])
  const [loading, setLoading] = useState(true)
  const [selectedVendorId, setSelectedVendorId] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!adminId) return
    adminAPI.getVendors(adminId)
      .then(({ data }) => {
        const list = Array.isArray(data) ? data : data.vendors || data.items || data.data || []
        setVendors(list)
      })
      .catch(() => setError('No se pudieron cargar los vendedores'))
      .finally(() => setLoading(false))
  }, [adminId])

  const currentVendorId = client?.vendor_id || client?.vendorId || ''
  const clientName = client?.name || client?.fullName || 'Cliente'

  const handleSubmit = async () => {
    if (!selectedVendorId) { setError('Selecciona un vendedor'); return }
    setSubmitting(true)
    setError('')
    try {
      await clientAPI.reassign(client.id, selectedVendorId)
      onSuccess(`"${clientName}" reasignado correctamente.`)
      onClose()
    } catch (err) {
      setError(err.response?.data?.message || 'Error al reasignar')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <Modal
      isOpen={!!client}
      onClose={onClose}
      title="Reasignar cliente"
      footer={
        <>
          <button onClick={onClose} className="btn-secondary text-sm">Cancelar</button>
          <button onClick={handleSubmit} disabled={submitting || !selectedVendorId} className="btn-primary text-sm">
            {submitting ? 'Guardando...' : 'Reasignar'}
          </button>
        </>
      }
    >
      <div className="space-y-4">
        <p className="text-sm text-textSecondary">
          Cliente: <span className="font-semibold text-textPrimary">{clientName}</span>
        </p>

        {error && (
          <div className="px-3 py-2 bg-error/10 border border-error/30 rounded-lg text-error text-sm">{error}</div>
        )}

        {loading ? (
          <div className="text-sm text-textMuted">Cargando vendedores...</div>
        ) : (
          <div className="space-y-2">
            <label className="label">Nuevo vendedor *</label>
            <div className="space-y-1.5 max-h-64 overflow-y-auto pr-1">
              {vendors.map(v => {
                const vid = v.id || v.vendorId
                const vname = v.name || v.vendorName || vid
                const isCurrent = vid === currentVendorId
                const isSelected = vid === selectedVendorId
                return (
                  <button
                    key={vid}
                    type="button"
                    onClick={() => setSelectedVendorId(vid)}
                    disabled={isCurrent}
                    className={`w-full text-left px-3 py-2.5 rounded-lg border text-sm transition-all ${
                      isSelected
                        ? 'bg-primary/15 border-primary/40 text-primary font-medium'
                        : isCurrent
                          ? 'bg-surfaceBright/40 border-border text-textMuted cursor-not-allowed'
                          : 'bg-surfaceBright border-border text-textSecondary hover:border-primary/30 hover:text-textPrimary'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span>{vname}</span>
                      <span className="flex items-center gap-1.5">
                        {isCurrent && <span className="text-xs text-textMuted bg-surfaceCard px-1.5 py-0.5 rounded">Actual</span>}
                        {isSelected && !isCurrent && (
                          <svg viewBox="0 0 16 16" fill="currentColor" className="w-4 h-4 text-primary">
                            <path fillRule="evenodd" d="M12.707 4.293a1 1 0 010 1.414l-5 5a1 1 0 01-1.414 0l-2-2a1 1 0 111.414-1.414L7 8.586l4.293-4.293a1 1 0 011.414 0z" clipRule="evenodd" />
                          </svg>
                        )}
                      </span>
                    </div>
                    {v.status && v.status !== 'active' && (
                      <span className="text-xs text-warning mt-0.5 block">{v.status}</span>
                    )}
                  </button>
                )
              })}
              {vendors.length === 0 && (
                <p className="text-sm text-textMuted py-2">No hay vendedores disponibles.</p>
              )}
            </div>
          </div>
        )}
      </div>
    </Modal>
  )
}

// ─── Hard delete confirm modal ─────────────────────────────────────────────────
function HardDeleteModal({ client, adminId, onClose, onSuccess }) {
  const [confirm, setConfirm] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  const clientName = client?.name || client?.fullName || 'Cliente'
  const isConfirmed = confirm.trim().toLowerCase() === 'eliminar'

  const handleDelete = async () => {
    if (!isConfirmed) return
    setSubmitting(true)
    setError('')
    try {
      await clientAPI.hardDelete(adminId, client.id)
      onSuccess(`"${clientName}" eliminado permanentemente.`)
      onClose()
    } catch (err) {
      setError(err.response?.data?.message || 'Error al eliminar')
      setSubmitting(false)
    }
  }

  return (
    <Modal
      isOpen={!!client}
      onClose={onClose}
      title="Eliminar cliente permanentemente"
      footer={
        <>
          <button onClick={onClose} className="btn-secondary text-sm">Cancelar</button>
          <button
            onClick={handleDelete}
            disabled={!isConfirmed || submitting}
            className="text-sm px-4 py-2 rounded-lg font-medium transition-all disabled:opacity-40 disabled:cursor-not-allowed bg-error text-white hover:bg-error/90"
          >
            {submitting ? 'Eliminando...' : 'Eliminar para siempre'}
          </button>
        </>
      }
    >
      <div className="space-y-4">
        <div className="flex items-start gap-3 px-4 py-3 bg-error/10 border border-error/30 rounded-xl">
          <svg viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5 text-error flex-shrink-0 mt-0.5">
            <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
          </svg>
          <div>
            <p className="text-sm font-semibold text-error">Acción irreversible</p>
            <p className="text-sm text-textSecondary mt-0.5">
              Se eliminarán <strong className="text-textPrimary">todos los créditos, cuotas, pagos y visitas</strong> de{' '}
              <span className="font-semibold text-textPrimary">"{clientName}"</span> de la base de datos. No hay vuelta atrás.
            </p>
          </div>
        </div>

        {error && (
          <div className="px-3 py-2 bg-error/10 border border-error/30 rounded-lg text-error text-sm">{error}</div>
        )}

        <div>
          <label className="label">
            Escribe <span className="font-mono font-bold text-textPrimary">eliminar</span> para confirmar
          </label>
          <input
            className="input-field mt-1"
            placeholder="eliminar"
            value={confirm}
            onChange={e => setConfirm(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && isConfirmed && handleDelete()}
            autoFocus
          />
        </div>
      </div>
    </Modal>
  )
}

// ─── Actions menu ──────────────────────────────────────────────────────────────
function ActionsMenu({ row, onViewCredits, onReassign, onHardDelete }) {
  const [open, setOpen] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    if (!open) return
    const handler = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false) }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [open])

  return (
    <div className="relative" ref={ref} onClick={e => e.stopPropagation()}>
      <button
        onClick={() => setOpen(o => !o)}
        className="p-1.5 rounded-lg text-textMuted hover:text-textPrimary hover:bg-surfaceBright transition-colors"
        title="Acciones"
      >
        <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
          <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
        </svg>
      </button>

      {open && (
        <div className="absolute right-0 top-8 z-50 w-48 bg-surfaceCard border border-border rounded-xl shadow-xl overflow-hidden">
          <button
            onClick={() => { setOpen(false); onViewCredits(row) }}
            className="w-full text-left px-4 py-2.5 text-sm text-textSecondary hover:bg-surfaceBright hover:text-textPrimary flex items-center gap-2"
          >
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-info">
              <path d="M4 4a2 2 0 00-2 2v1h16V6a2 2 0 00-2-2H4z" /><path fillRule="evenodd" d="M18 9H2v5a2 2 0 002 2h12a2 2 0 002-2V9zM4 13a1 1 0 011-1h1a1 1 0 110 2H5a1 1 0 01-1-1zm5-1a1 1 0 100 2h1a1 1 0 100-2H9z" clipRule="evenodd" />
            </svg>
            Ver créditos
          </button>
          <button
            onClick={() => { setOpen(false); onReassign(row) }}
            className="w-full text-left px-4 py-2.5 text-sm text-textSecondary hover:bg-surfaceBright hover:text-textPrimary flex items-center gap-2"
          >
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-primary">
              <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
            </svg>
            Reasignar vendedor
          </button>
          <div className="border-t border-border" />
          <button
            onClick={() => { setOpen(false); onHardDelete(row) }}
            className="w-full text-left px-4 py-2.5 text-sm text-error hover:bg-error/10 flex items-center gap-2"
          >
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clipRule="evenodd" />
            </svg>
            Eliminar permanente
          </button>
        </div>
      )}
    </div>
  )
}

// ─── Main page ─────────────────────────────────────────────────────────────────
export default function Clients() {
  const { admin } = useAuth()
  const adminId = admin?.adminId || admin?.id

  const [clients, setClients] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [search, setSearch] = useState('')
  const [offset, setOffset] = useState(0)
  const [hasMore, setHasMore] = useState(true)
  const LIMIT = 50
  const searchTimer = useRef(null)

  const [creditsClient, setCreditsClient] = useState(null)
  const [reassignClient, setReassignClient] = useState(null)
  const [hardDeleteClient, setHardDeleteClient] = useState(null)
  const [toast, showToast] = useToast()

  const fetchClients = useCallback(async (q = '', off = 0, replace = true) => {
    if (!adminId) return
    setLoading(true)
    setError(null)
    try {
      const { data } = await adminAPI.getClients(adminId, { q, limit: LIMIT, offset: off })
      const rows = Array.isArray(data) ? data : data.clients || data.data || []
      if (replace) {
        setClients(rows)
      } else {
        setClients(prev => [...prev, ...rows])
      }
      setHasMore(rows.length === LIMIT)
      setOffset(off + rows.length)
    } catch (err) {
      setError(err.response?.data?.message || 'Error al cargar clientes')
    } finally {
      setLoading(false)
    }
  }, [adminId])

  useEffect(() => { fetchClients('', 0, true) }, [fetchClients])

  const handleSearch = (e) => {
    const q = e.target.value
    setSearch(q)
    clearTimeout(searchTimer.current)
    searchTimer.current = setTimeout(() => {
      setOffset(0)
      fetchClients(q, 0, true)
    }, 400)
  }

  const handleLoadMore = () => fetchClients(search, offset, false)

  const handleActionSuccess = (msg) => {
    showToast(msg)
    fetchClients(search, 0, true)
  }

  const columns = [
    {
      key: 'name',
      label: 'Cliente',
      render: (v, row) => (
        <div>
          <p className="font-medium text-sm text-textPrimary">{v || row.fullName || row.full_name || '—'}</p>
          <p className="text-xs text-textMuted">{row.phone || row.phoneNumber || '—'}</p>
        </div>
      ),
    },
    {
      key: 'docId',
      label: 'Doc. ID',
      render: (v, row) => <span className="text-sm text-textSecondary font-mono">{v || row.document_id || row.documentId || '—'}</span>,
    },
    {
      key: 'status',
      label: 'Estado',
      render: (v, row) => {
        const active = v ?? row.active
        if (typeof active === 'boolean') return <Badge status={active ? 'active' : 'inactive'} />
        const map = { active: 'active', inactive: 'inactive', activo: 'active', inactivo: 'inactive' }
        return <Badge status={map[String(v).toLowerCase()] || 'default'} label={v || '—'} />
      },
    },
    {
      key: 'vendor_name',
      label: 'Vendedor',
      render: (v, row) => (
        <span className="text-sm text-textSecondary">
          {v || row.vendorName || row.vendor_name || <span className="text-textMuted italic">Sin vendedor</span>}
        </span>
      ),
    },
    {
      key: '_actions',
      label: '',
      sortable: false,
      render: (_, row) => (
        <ActionsMenu
          row={row}
          onViewCredits={setCreditsClient}
          onReassign={setReassignClient}
          onHardDelete={setHardDeleteClient}
        />
      ),
    },
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="section-title">Clientes</h2>
          <p className="text-textMuted text-sm mt-0.5">{clients.length} registros cargados</p>
        </div>
        <button onClick={() => fetchClients('', 0, true)} className="btn-secondary text-sm">
          <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
            <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
          </svg>
          Actualizar
        </button>
      </div>

      {toast}

      {/* Search */}
      <div className="relative max-w-md">
        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-textMuted">
          <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
            <path fillRule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clipRule="evenodd" />
          </svg>
        </span>
        <input
          type="text"
          value={search}
          onChange={handleSearch}
          placeholder="Buscar por nombre, teléfono o documento..."
          className="input-field pl-10 text-sm"
        />
      </div>

      {/* Error */}
      {error && (
        <div className="px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm">{error}</div>
      )}

      {/* Table */}
      <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
        <DataTable
          columns={columns}
          data={clients}
          loading={loading}
          emptyMessage="No se encontraron clientes"
          keyField="id"
          pageSize={15}
        />
      </div>

      {/* Load more */}
      {!loading && hasMore && clients.length > 0 && (
        <div className="flex justify-center">
          <button onClick={handleLoadMore} className="btn-secondary text-sm">
            Cargar más clientes
          </button>
        </div>
      )}

      {/* Modals */}
      <CreditsPanel client={creditsClient} onClose={() => setCreditsClient(null)} />

      <ReassignModal
        client={reassignClient}
        adminId={adminId}
        onClose={() => setReassignClient(null)}
        onSuccess={handleActionSuccess}
      />

      <HardDeleteModal
        client={hardDeleteClient}
        adminId={adminId}
        onClose={() => setHardDeleteClient(null)}
        onSuccess={handleActionSuccess}
      />
    </div>
  )
}
