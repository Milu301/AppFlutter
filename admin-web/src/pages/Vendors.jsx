import React, { useEffect, useState, useCallback } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { adminAPI, vendorAPI } from '../api/client'
import DataTable from '../components/DataTable'
import Modal from '../components/Modal'
import Badge from '../components/Badge'
import { useToast } from '../components/Toast'

const EMPTY_CREATE = { name: '', email: '', password: '', phone: '' }
const EMPTY_EDIT = { name: '', email: '', phone: '', status: 'active', password: '' }

function VendorStat({ label, value, color }) {
  const colors = {
    primary: 'bg-primary/10 border-primary/20 text-primary',
    success: 'bg-success/10 border-success/20 text-success',
    error:   'bg-error/10 border-error/20 text-error',
    muted:   'bg-surfaceBright border-border text-textSecondary',
  }
  return (
    <div className={`flex flex-col items-center justify-center px-6 py-3 rounded-xl border ${colors[color] || colors.muted}`}>
      <span className="text-2xl font-bold leading-none">{value}</span>
      <span className="text-xs mt-1 font-medium opacity-80">{label}</span>
    </div>
  )
}

export default function Vendors() {
  const { admin } = useAuth()
  const adminId = admin?.adminId || admin?.id

  const [vendors, setVendors] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [showCreate, setShowCreate] = useState(false)
  const [showEdit, setShowEdit]     = useState(null)
  const [showDelete, setShowDelete] = useState(null)
  const [showReset, setShowReset]   = useState(null)

  const [createForm, setCreateForm] = useState(EMPTY_CREATE)
  const [editForm, setEditForm]     = useState(EMPTY_EDIT)
  const [formError, setFormError]   = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [toast, showToast] = useToast()

  const fetchVendors = useCallback(async () => {
    if (!adminId) return
    setLoading(true)
    setError(null)
    try {
      const { data } = await adminAPI.getVendors(adminId)
      setVendors(Array.isArray(data) ? data : data.vendors || data.data || [])
    } catch (err) {
      setError(err.response?.data?.message || 'Error al cargar vendedores')
    } finally {
      setLoading(false)
    }
  }, [adminId])

  useEffect(() => { fetchVendors() }, [fetchVendors])

  const total    = vendors.length
  const active   = vendors.filter(v => (v.active ?? v.status === 'active')).length
  const inactive = total - active

  const handleCreate = async (e) => {
    e.preventDefault()
    setFormError('')
    if (!createForm.name.trim() || !createForm.email.trim() || !createForm.password.trim()) {
      setFormError('Nombre, correo y contraseña son requeridos.')
      return
    }
    setSubmitting(true)
    try {
      await adminAPI.createVendor(adminId, createForm)
      setShowCreate(false)
      setCreateForm(EMPTY_CREATE)
      showToast('Vendedor creado correctamente.')
      fetchVendors()
    } catch (err) {
      setFormError(err.response?.data?.message || 'Error al crear vendedor')
    } finally {
      setSubmitting(false)
    }
  }

  const openEdit = (vendor) => {
    setEditForm({
      name:   vendor.name   || vendor.fullName || '',
      email:  vendor.email  || '',
      phone:  vendor.phone  || vendor.phoneNumber || '',
      status: vendor.status || (vendor.active ? 'active' : 'inactive'),
      password: '',
    })
    setFormError('')
    setShowEdit(vendor)
  }

  const handleEdit = async (e) => {
    e.preventDefault()
    setFormError('')
    if (!editForm.name.trim() || !editForm.email.trim()) {
      setFormError('Nombre y correo son requeridos.')
      return
    }
    if (editForm.password && editForm.password.length < 6) {
      setFormError('La contraseña debe tener al menos 6 caracteres.')
      return
    }
    setSubmitting(true)
    const vendorId = showEdit.id || showEdit.vendorId
    try {
      const payload = {
        name:   editForm.name.trim(),
        email:  editForm.email.trim(),
        status: editForm.status,
      }
      if (editForm.phone.trim()) payload.phone = editForm.phone.trim()
      if (editForm.password.trim()) payload.password = editForm.password.trim()
      await vendorAPI.update(vendorId, payload)
      setShowEdit(null)
      showToast('Vendedor actualizado correctamente.')
      fetchVendors()
    } catch (err) {
      setFormError(err.response?.data?.message || 'Error al actualizar vendedor')
    } finally {
      setSubmitting(false)
    }
  }

  const handleToggleStatus = async (vendor) => {
    const isActive = vendor.active ?? vendor.status === 'active'
    try {
      await vendorAPI.toggleStatus(vendor.id || vendor.vendorId, !isActive)
      showToast(`Vendedor ${isActive ? 'desactivado' : 'activado'}.`)
      fetchVendors()
    } catch (err) {
      showToast(err.response?.data?.message || 'Error al cambiar estado', 'error')
    }
  }

  const handleResetDevice = async () => {
    if (!showReset) return
    setSubmitting(true)
    try {
      await vendorAPI.resetDevice(showReset.id || showReset.vendorId)
      setShowReset(null)
      showToast('Dispositivo reiniciado. El vendedor deberá iniciar sesión de nuevo.')
    } catch (err) {
      showToast(err.response?.data?.message || 'Error al reiniciar dispositivo', 'error')
    } finally {
      setSubmitting(false)
    }
  }

  const handleDelete = async () => {
    if (!showDelete) return
    setSubmitting(true)
    try {
      await vendorAPI.delete(showDelete.id || showDelete.vendorId)
      setShowDelete(null)
      showToast('Vendedor eliminado.')
      fetchVendors()
    } catch (err) {
      showToast(err.response?.data?.message || 'Error al eliminar vendedor', 'error')
    } finally {
      setSubmitting(false)
    }
  }

  const columns = [
    {
      key: 'name',
      label: 'Vendedor',
      render: (v, row) => {
        const name = v || row.fullName || '—'
        const initial = name[0]?.toUpperCase() || '?'
        return (
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary/30 to-info/20 flex items-center justify-center flex-shrink-0 border border-primary/20">
              <span className="text-sm font-bold text-primary">{initial}</span>
            </div>
            <div>
              <p className="font-medium text-textPrimary text-sm leading-tight">{name}</p>
              <p className="text-xs text-textMuted">{row.email || '—'}</p>
            </div>
          </div>
        )
      },
    },
    {
      key: 'phone',
      label: 'Teléfono',
      render: (v, row) => (
        <span className="text-sm text-textSecondary font-mono">{v || row.phoneNumber || '—'}</span>
      ),
    },
    {
      key: 'active',
      label: 'Estado',
      render: (v, row) => {
        const isActive = v ?? row.status === 'active'
        return (
          <div className="flex items-center gap-2">
            <span className={`w-2 h-2 rounded-full flex-shrink-0 ${isActive ? 'bg-success animate-pulse' : 'bg-error'}`} />
            <Badge status={isActive ? 'active' : 'inactive'} />
          </div>
        )
      },
    },
    {
      key: 'routeCount',
      label: 'Rutas',
      render: (v, row) => {
        const count = v ?? row.routes_count ?? row.route_count ?? 0
        return (
          <span className={`inline-flex items-center justify-center w-8 h-8 rounded-lg text-sm font-bold ${count > 0 ? 'bg-info/15 text-info' : 'bg-surfaceBright text-textMuted'}`}>
            {count}
          </span>
        )
      },
    },
    {
      key: 'actions',
      label: 'Acciones',
      sortable: false,
      render: (_, row) => (
        <div className="flex items-center gap-1">
          <button onClick={(e) => { e.stopPropagation(); openEdit(row) }}
            title="Editar vendedor"
            className="p-1.5 rounded-lg text-textMuted hover:text-primary hover:bg-primary/10 transition-colors">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
            </svg>
          </button>
          <button onClick={(e) => { e.stopPropagation(); handleToggleStatus(row) }}
            title={(row.active ?? row.status === 'active') ? 'Desactivar' : 'Activar'}
            className="p-1.5 rounded-lg text-textMuted hover:text-warning hover:bg-warning/10 transition-colors">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
            </svg>
          </button>
          <button onClick={(e) => { e.stopPropagation(); setShowReset(row) }}
            title="Reiniciar dispositivo"
            className="p-1.5 rounded-lg text-textMuted hover:text-info hover:bg-info/10 transition-colors">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
            </svg>
          </button>
          <button onClick={(e) => { e.stopPropagation(); setShowDelete(row) }}
            title="Eliminar"
            className="p-1.5 rounded-lg text-textMuted hover:text-error hover:bg-error/10 transition-colors">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clipRule="evenodd" />
            </svg>
          </button>
        </div>
      ),
    },
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h2 className="section-title">Vendedores</h2>
          <p className="text-textMuted text-sm mt-0.5">Gestión completa del equipo de ventas</p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchVendors} className="btn-secondary text-sm" disabled={loading}>
            <svg viewBox="0 0 20 20" fill="currentColor" className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`}>
              <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
            </svg>
            Actualizar
          </button>
          <button onClick={() => { setCreateForm(EMPTY_CREATE); setFormError(''); setShowCreate(true) }} className="btn-primary text-sm">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clipRule="evenodd" />
            </svg>
            Nuevo vendedor
          </button>
        </div>
      </div>

      {/* Stats */}
      {!loading && total > 0 && (
        <div className="flex flex-wrap gap-3">
          <VendorStat label="Total" value={total} color="primary" />
          <VendorStat label="Activos" value={active} color="success" />
          <VendorStat label="Inactivos" value={inactive} color={inactive > 0 ? 'error' : 'muted'} />
        </div>
      )}

      {toast}

      {error && (
        <div className="flex items-center gap-3 px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm">{error}</div>
      )}

      <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
        <DataTable columns={columns} data={vendors} loading={loading} emptyMessage="No hay vendedores registrados" keyField="id" />
      </div>

      {/* Create Modal */}
      <Modal isOpen={showCreate} onClose={() => setShowCreate(false)} title="Nuevo Vendedor"
        footer={<>
          <button onClick={() => setShowCreate(false)} className="btn-secondary text-sm">Cancelar</button>
          <button onClick={handleCreate} disabled={submitting} className="btn-primary text-sm">
            {submitting ? 'Creando...' : 'Crear vendedor'}
          </button>
        </>}>
        <form onSubmit={handleCreate} className="space-y-4">
          {formError && <div className="px-3 py-2 bg-error/10 border border-error/30 rounded-lg text-error text-sm">{formError}</div>}
          <div>
            <label className="label">Nombre completo *</label>
            <input className="input-field" placeholder="Juan Pérez" value={createForm.name}
              onChange={e => setCreateForm(f => ({ ...f, name: e.target.value }))} required />
          </div>
          <div>
            <label className="label">Correo electrónico *</label>
            <input type="email" className="input-field" placeholder="vendedor@ejemplo.com" value={createForm.email}
              onChange={e => setCreateForm(f => ({ ...f, email: e.target.value }))} required />
          </div>
          <div>
            <label className="label">Contraseña *</label>
            <input type="password" className="input-field" placeholder="Mínimo 6 caracteres" value={createForm.password}
              onChange={e => setCreateForm(f => ({ ...f, password: e.target.value }))} required />
          </div>
          <div>
            <label className="label">Teléfono</label>
            <input type="tel" className="input-field" placeholder="5512345678" value={createForm.phone}
              onChange={e => setCreateForm(f => ({ ...f, phone: e.target.value }))} />
          </div>
        </form>
      </Modal>

      {/* Edit Modal */}
      <Modal isOpen={!!showEdit} onClose={() => setShowEdit(null)}
        title={`Editar — ${showEdit?.name || showEdit?.fullName || 'Vendedor'}`}
        footer={<>
          <button onClick={() => setShowEdit(null)} className="btn-secondary text-sm">Cancelar</button>
          <button onClick={handleEdit} disabled={submitting} className="btn-primary text-sm">
            {submitting ? 'Guardando...' : 'Guardar cambios'}
          </button>
        </>}>
        <form onSubmit={handleEdit} className="space-y-4">
          {formError && <div className="px-3 py-2 bg-error/10 border border-error/30 rounded-lg text-error text-sm">{formError}</div>}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="label">Nombre completo *</label>
              <input className="input-field" placeholder="Juan Pérez" value={editForm.name}
                onChange={e => setEditForm(f => ({ ...f, name: e.target.value }))} required />
            </div>
            <div>
              <label className="label">Teléfono</label>
              <input type="tel" className="input-field" placeholder="5512345678" value={editForm.phone}
                onChange={e => setEditForm(f => ({ ...f, phone: e.target.value }))} />
            </div>
          </div>
          <div>
            <label className="label">Correo electrónico *</label>
            <input type="email" className="input-field" placeholder="vendedor@ejemplo.com" value={editForm.email}
              onChange={e => setEditForm(f => ({ ...f, email: e.target.value }))} required />
          </div>
          <div>
            <label className="label">Estado</label>
            <div className="flex gap-3">
              {['active', 'inactive'].map(s => (
                <button key={s} type="button" onClick={() => setEditForm(f => ({ ...f, status: s }))}
                  className={`flex-1 py-2.5 rounded-lg text-sm font-medium border transition-all ${editForm.status === s
                    ? s === 'active' ? 'bg-success/15 border-success/40 text-success' : 'bg-error/15 border-error/40 text-error'
                    : 'bg-surfaceBright border-border text-textSecondary hover:border-textMuted'}`}>
                  {s === 'active' ? '✓ Activo' : '✗ Inactivo'}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="label">
              Nueva contraseña{' '}
              <span className="text-textMuted font-normal text-xs">(vacío = no cambiar)</span>
            </label>
            <input type="password" className="input-field" placeholder="Mínimo 6 caracteres" value={editForm.password}
              onChange={e => setEditForm(f => ({ ...f, password: e.target.value }))} />
            {editForm.password && (
              <div className={`mt-1.5 h-1 rounded-full transition-all duration-300 ${
                editForm.password.length >= 8 ? 'bg-success w-full' :
                editForm.password.length >= 6 ? 'bg-warning w-2/3' : 'bg-error w-1/3'}`} />
            )}
            <p className="text-xs text-textMuted mt-1">Si cambias la contraseña, el vendedor deberá iniciar sesión de nuevo.</p>
          </div>
        </form>
      </Modal>

      {/* Reset Device Modal */}
      <Modal isOpen={!!showReset} onClose={() => setShowReset(null)} title="Reiniciar dispositivo" size="sm"
        footer={<>
          <button onClick={() => setShowReset(null)} className="btn-secondary text-sm">Cancelar</button>
          <button onClick={handleResetDevice} disabled={submitting} className="btn-primary text-sm">
            {submitting ? 'Reiniciando...' : 'Confirmar'}
          </button>
        </>}>
        <div className="flex flex-col items-center gap-3 text-center py-2">
          <div className="w-14 h-14 rounded-2xl bg-info/15 flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" className="w-7 h-7 text-info">
              <path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <div>
            <p className="text-textPrimary font-medium">¿Reiniciar dispositivo de <span className="text-info">{showReset?.name}</span>?</p>
            <p className="text-textMuted text-sm mt-1">El vendedor deberá iniciar sesión nuevamente en la app móvil.</p>
          </div>
        </div>
      </Modal>

      {/* Delete Modal */}
      <Modal isOpen={!!showDelete} onClose={() => setShowDelete(null)} title="Eliminar vendedor" size="sm"
        footer={<>
          <button onClick={() => setShowDelete(null)} className="btn-secondary text-sm">Cancelar</button>
          <button onClick={handleDelete} disabled={submitting}
            className="bg-error hover:bg-red-600 text-white font-semibold px-4 py-2 rounded-lg transition-colors text-sm">
            {submitting ? 'Eliminando...' : 'Eliminar'}
          </button>
        </>}>
        <div className="flex flex-col items-center gap-3 text-center py-2">
          <div className="w-14 h-14 rounded-2xl bg-error/15 flex items-center justify-center">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-7 h-7 text-error">
              <path fillRule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clipRule="evenodd" />
            </svg>
          </div>
          <div>
            <p className="text-textPrimary font-medium">¿Eliminar a <span className="text-error">{showDelete?.name}</span>?</p>
            <p className="text-textMuted text-sm mt-1">Esta acción no se puede deshacer.</p>
          </div>
        </div>
      </Modal>
    </div>
  )
}
