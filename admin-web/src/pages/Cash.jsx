import React, { useEffect, useState, useCallback } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { adminAPI } from '../api/client'
import DataTable from '../components/DataTable'
import Modal from '../components/Modal'
import Badge from '../components/Badge'
import StatCard from '../components/StatCard'
import { useToast } from '../components/Toast'
import { currency, formatDate } from '../utils/formatters'

const today = () => new Date().toISOString().split('T')[0]

const EMPTY_MOVEMENT = { movement_type: 'income', amount: '', note: '', category: '' }

export default function Cash() {
  const { admin } = useAuth()
  const adminId = admin?.adminId || admin?.id

  const [date, setDate] = useState(today())
  const [movements, setMovements] = useState([])
  const [summary, setSummary] = useState(null)
  const [loading, setLoading] = useState(true)
  const [loadingSummary, setLoadingSummary] = useState(true)
  const [error, setError] = useState(null)

  const [showAdd, setShowAdd] = useState(false)
  const [form, setForm] = useState(EMPTY_MOVEMENT)
  const [formError, setFormError] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [toast, showToast] = useToast()

  const fetchData = useCallback(async (d) => {
    if (!adminId) return
    setLoading(true)
    setLoadingSummary(true)
    setError(null)
    try {
      const [cashRes, summaryRes] = await Promise.allSettled([
        adminAPI.getAllCash(adminId, d),
        adminAPI.getAllCashSummary(adminId, d),
      ])
      if (cashRes.status === 'fulfilled') {
        const d2 = cashRes.value.data
        const items = Array.isArray(d2) ? d2 : (d2?.items || d2?.movements || d2?.data || [])
        setMovements(items)
      } else {
        setMovements([])
        if (cashRes.reason?.response?.status !== 404) {
          setError(cashRes.reason?.response?.data?.message || 'Error al cargar movimientos')
        }
      }
      if (summaryRes.status === 'fulfilled') {
        setSummary(summaryRes.value.data)
      } else {
        setSummary(null)
      }
    } finally {
      setLoading(false)
      setLoadingSummary(false)
    }
  }, [adminId])

  useEffect(() => { fetchData(date) }, [fetchData, date])

  const handleDateChange = (e) => {
    setDate(e.target.value)
  }

  const handleAddMovement = async (e) => {
    e.preventDefault()
    setFormError('')
    if (!form.amount || isNaN(Number(form.amount)) || Number(form.amount) <= 0) {
      setFormError('Ingresa un monto válido mayor a 0.')
      return
    }
    if (!form.note.trim()) {
      setFormError('La descripción es requerida.')
      return
    }
    setSubmitting(true)
    try {
      await adminAPI.createCashMovement(adminId, {
        movement_type: form.movement_type,
        amount: Number(form.amount),
        note: form.note,
        category: form.category || undefined,
      })
      setShowAdd(false)
      setForm(EMPTY_MOVEMENT)
      showToast('Movimiento registrado correctamente.')
      fetchData(date)
    } catch (err) {
      setFormError(err.response?.data?.message || 'Error al registrar movimiento')
    } finally {
      setSubmitting(false)
    }
  }

  const cols = [
    {
      key: 'movement_type',
      label: 'Tipo',
      render: (v, row) => {
        const isIncome = v === 'income' || row.is_income
        return <Badge variant={isIncome ? 'income' : 'expense'} label={isIncome ? 'Ingreso' : 'Egreso'} />
      },
    },
    {
      key: 'note',
      label: 'Descripción',
      render: (v, row) => (
        <div>
          <p className="text-sm text-textPrimary">{v || row.description || row.concept || '—'}</p>
          {row.category && <p className="text-xs text-textMuted">{row.category}</p>}
        </div>
      ),
    },
    {
      key: 'amount',
      label: 'Monto',
      render: (v, row) => {
        const isIncome = row.movement_type === 'income' || row.is_income
        return (
          <span className={`font-semibold text-sm ${isIncome ? 'text-success' : 'text-error'}`}>
            {isIncome ? '+' : '-'}{currency(Math.abs(v ?? 0))}
          </span>
        )
      },
    },
    {
      key: 'vendor_name',
      label: 'Realizado por',
      render: (v, row) => {
        const name = v || row.vendorName || row.vendor_name
        const source = row.source
        if (!name && source === 'admin') {
          return (
            <div className="flex items-center gap-1.5">
              <span className="w-5 h-5 rounded-full bg-primary/20 flex items-center justify-center text-primary text-xs font-bold flex-shrink-0">A</span>
              <span className="text-sm text-textSecondary">Admin</span>
            </div>
          )
        }
        if (name) {
          return (
            <div className="flex items-center gap-1.5">
              <span className="w-5 h-5 rounded-full bg-success/20 flex items-center justify-center text-success text-xs font-bold flex-shrink-0">
                {name[0]?.toUpperCase()}
              </span>
              <span className="text-sm text-textSecondary">{name}</span>
            </div>
          )
        }
        return <span className="text-sm text-textMuted">—</span>
      },
    },
    {
      key: 'occurred_at',
      label: 'Hora',
      render: (v, row) => {
        const d = v || row.created_at || row.time
        if (!d) return <span className="text-xs text-textMuted">—</span>
        try {
          return <span className="text-xs text-textMuted">{new Date(d).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' })}</span>
        } catch {
          return <span className="text-xs text-textMuted">{d}</span>
        }
      },
    },
  ]

  const income = summary?.income ?? summary?.total_income ?? 0
  const expense = summary?.expense ?? summary?.total_expense ?? 0
  const net = summary?.net ?? (income - expense)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="section-title">Caja</h2>
          <p className="text-textMuted text-sm mt-0.5">Control de movimientos diarios</p>
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          {/* Date picker */}
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-textMuted">
              <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                <path fillRule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clipRule="evenodd" />
              </svg>
            </span>
            <input
              type="date"
              value={date}
              onChange={handleDateChange}
              className="input-field pl-10 text-sm w-48 cursor-pointer"
              style={{ colorScheme: 'dark' }}
            />
          </div>
          <button
            onClick={() => { setForm(EMPTY_MOVEMENT); setFormError(''); setShowAdd(true) }}
            className="btn-primary text-sm"
          >
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
              <path fillRule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clipRule="evenodd" />
            </svg>
            Agregar movimiento
          </button>
        </div>
      </div>

      {toast}

      {/* Error */}
      {error && (
        <div className="px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm">{error}</div>
      )}

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard
          title="Ingresos"
          value={currency(income)}
          subtitle={`${date === today() ? 'Hoy' : date}`}
          icon="↑"
          color="success"
          loading={loadingSummary}
        />
        <StatCard
          title="Egresos"
          value={currency(expense)}
          subtitle={`${date === today() ? 'Hoy' : date}`}
          icon="↓"
          color="error"
          loading={loadingSummary}
        />
        <StatCard
          title="Balance neto"
          value={currency(net)}
          subtitle="Ingreso menos egreso"
          icon="="
          color={net >= 0 ? 'success' : 'error'}
          loading={loadingSummary}
        />
      </div>

      {/* Movements table */}
      <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <h3 className="font-semibold text-textPrimary text-sm">
            Movimientos — {formatDate(date + 'T12:00:00', { weekday: 'long', day: 'numeric', month: 'long' })}
          </h3>
          <span className="text-xs text-textMuted">{movements.length} registros</span>
        </div>
        <DataTable
          columns={cols}
          data={movements}
          loading={loading}
          emptyMessage="No hay movimientos para esta fecha"
          keyField="id"
          pageSize={20}
        />
      </div>

      {/* Add Movement Modal */}
      <Modal
        isOpen={showAdd}
        onClose={() => setShowAdd(false)}
        title="Registrar movimiento"
        footer={
          <>
            <button onClick={() => setShowAdd(false)} className="btn-secondary text-sm">Cancelar</button>
            <button onClick={handleAddMovement} disabled={submitting} className="btn-primary text-sm">
              {submitting ? 'Registrando...' : 'Registrar'}
            </button>
          </>
        }
      >
        <form onSubmit={handleAddMovement} className="space-y-4">
          {formError && (
            <div className="px-3 py-2 bg-error/10 border border-error/30 rounded-lg text-error text-sm">{formError}</div>
          )}
          <div>
            <label className="label">Tipo de movimiento</label>
            <div className="flex gap-3">
              {['income', 'expense'].map(t => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setForm(f => ({ ...f, movement_type: t }))}
                  className={`flex-1 py-2.5 rounded-lg text-sm font-medium border transition-all ${form.movement_type === t
                    ? t === 'income'
                      ? 'bg-success/15 border-success/40 text-success'
                      : 'bg-error/15 border-error/40 text-error'
                    : 'bg-surfaceBright border-border text-textSecondary hover:border-textMuted'
                  }`}
                >
                  {t === 'income' ? '↑ Ingreso' : '↓ Egreso'}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="label">Monto *</label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-textMuted text-sm">$</span>
              <input
                type="number"
                step="0.01"
                min="0.01"
                className="input-field pl-7"
                placeholder="0.00"
                value={form.amount}
                onChange={e => setForm(f => ({ ...f, amount: e.target.value }))}
                required
              />
            </div>
          </div>
          <div>
            <label className="label">Descripción *</label>
            <input
              className="input-field"
              placeholder="Concepto del movimiento"
              value={form.note}
              onChange={e => setForm(f => ({ ...f, note: e.target.value }))}
              required
            />
          </div>
          <div>
            <label className="label">Categoría</label>
            <input
              className="input-field"
              placeholder="Ej: Cobros, Gastos operativos..."
              value={form.category}
              onChange={e => setForm(f => ({ ...f, category: e.target.value }))}
            />
          </div>
        </form>
      </Modal>
    </div>
  )
}
