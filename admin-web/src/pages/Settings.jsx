import React, { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import apiClient from '../api/client'
import { formatDate } from '../utils/formatters'

export default function Settings() {
  const { admin, logout } = useAuth()

  const [pwForm, setPwForm] = useState({ current: '', next: '', confirm: '' })
  const [pwError, setPwError] = useState('')
  const [pwSuccess, setPwSuccess] = useState('')
  const [pwLoading, setPwLoading] = useState(false)
  const [showPasswords, setShowPasswords] = useState(false)

  const adminId = admin?.adminId || admin?.id
  const email = admin?.email || '—'
  const expiresAt = admin?.subscription_expires_at || admin?.subscriptionExpiresAt || admin?.expires_at

  const handleChangePassword = async (e) => {
    e.preventDefault()
    setPwError('')
    setPwSuccess('')
    if (!pwForm.current || !pwForm.next || !pwForm.confirm) {
      setPwError('Todos los campos son requeridos.')
      return
    }
    if (pwForm.next.length < 6) {
      setPwError('La nueva contraseña debe tener al menos 6 caracteres.')
      return
    }
    if (pwForm.next !== pwForm.confirm) {
      setPwError('Las contraseñas no coinciden.')
      return
    }
    setPwLoading(true)
    try {
      await apiClient.put(`/admins/${adminId}/password`, {
        currentPassword: pwForm.current,
        newPassword: pwForm.next,
      })
      setPwSuccess('Contraseña actualizada correctamente.')
      setPwForm({ current: '', next: '', confirm: '' })
    } catch (err) {
      const status = err.response?.status
      if (status === 404) {
        setPwError('Funcionalidad no disponible todavía. Próximamente.')
      } else {
        setPwError(err.response?.data?.message || 'Error al cambiar contraseña.')
      }
    } finally {
      setPwLoading(false)
    }
  }


  const isExpiringSoon = expiresAt && new Date(expiresAt) - new Date() < 15 * 24 * 60 * 60 * 1000

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h2 className="section-title">Configuración</h2>
        <p className="text-textMuted text-sm mt-0.5">Información de cuenta y preferencias</p>
      </div>

      {/* Profile card */}
      <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
        <div className="px-6 py-4 border-b border-border flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-primary/15 flex items-center justify-center">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-primary">
              <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
            </svg>
          </div>
          <h3 className="font-semibold text-textPrimary text-sm">Información de la cuenta</h3>
        </div>
        <div className="p-6 space-y-5">
          {/* Avatar */}
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary/30 to-info/30 border border-primary/30 flex items-center justify-center">
              <span className="text-2xl font-bold text-primary">
                {email[0]?.toUpperCase() || 'A'}
              </span>
            </div>
            <div>
              <p className="font-semibold text-textPrimary">{email}</p>
              <p className="text-sm text-textMuted">Administrador</p>
              {adminId && <p className="text-xs text-textMuted mt-0.5">ID: {adminId}</p>}
            </div>
          </div>

          {/* Details */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2 border-t border-border">
            <div className="bg-surfaceBright rounded-xl p-4">
              <p className="text-xs text-textMuted mb-1">Correo electrónico</p>
              <p className="text-sm font-medium text-textPrimary">{email}</p>
            </div>
            <div className="bg-surfaceBright rounded-xl p-4">
              <p className="text-xs text-textMuted mb-1">ID Administrador</p>
              <p className="text-sm font-mono text-textSecondary">{adminId || '—'}</p>
            </div>
            <div className={`rounded-xl p-4 sm:col-span-2 ${isExpiringSoon ? 'bg-warning/10 border border-warning/30' : 'bg-surfaceBright'}`}>
              <p className="text-xs text-textMuted mb-1">Suscripción vence</p>
              <div className="flex items-center gap-2">
                <p className={`text-sm font-medium ${isExpiringSoon ? 'text-warning' : 'text-textPrimary'}`}>
                  {formatDate(expiresAt)}
                </p>
                {isExpiringSoon && (
                  <span className="text-xs bg-warning/20 text-warning px-2 py-0.5 rounded-full font-medium">
                    Vence pronto
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Change password */}
      <div className="bg-surfaceCard border border-border rounded-xl overflow-hidden">
        <div className="px-6 py-4 border-b border-border flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-warning/15 flex items-center justify-center">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-warning">
              <path fillRule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clipRule="evenodd" />
            </svg>
          </div>
          <h3 className="font-semibold text-textPrimary text-sm">Cambiar contraseña</h3>
        </div>
        <form onSubmit={handleChangePassword} className="p-6 space-y-4">
          {pwError && (
            <div className="flex items-center gap-2 px-3 py-2 bg-error/10 border border-error/30 rounded-lg text-error text-sm animate-slide-in">
              <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 flex-shrink-0">
                <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
              {pwError}
            </div>
          )}
          {pwSuccess && (
            <div className="flex items-center gap-2 px-3 py-2 bg-success/10 border border-success/30 rounded-lg text-success text-sm animate-slide-in">
              <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 flex-shrink-0">
                <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
              </svg>
              {pwSuccess}
            </div>
          )}

          <div className="flex items-center justify-between mb-1">
            <span className="text-xs text-textMuted">
              {showPasswords ? 'Las contraseñas son visibles' : 'Las contraseñas están ocultas'}
            </span>
            <button type="button" onClick={() => setShowPasswords(s => !s)} className="text-xs text-primary hover:underline">
              {showPasswords ? 'Ocultar' : 'Mostrar'}
            </button>
          </div>

          {[
            { key: 'current', label: 'Contraseña actual', placeholder: '••••••••' },
            { key: 'next', label: 'Nueva contraseña', placeholder: 'Mínimo 6 caracteres' },
            { key: 'confirm', label: 'Confirmar nueva contraseña', placeholder: 'Repite la contraseña' },
          ].map(({ key, label, placeholder }) => (
            <div key={key}>
              <label className="label">{label}</label>
              <input
                type={showPasswords ? 'text' : 'password'}
                className="input-field"
                placeholder={placeholder}
                value={pwForm[key]}
                onChange={e => setPwForm(f => ({ ...f, [key]: e.target.value }))}
              />
            </div>
          ))}

          <button type="submit" disabled={pwLoading} className="btn-primary text-sm w-full sm:w-auto">
            {pwLoading ? (
              <>
                <svg className="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                Guardando...
              </>
            ) : 'Cambiar contraseña'}
          </button>
        </form>
      </div>

      {/* Danger zone */}
      <div className="bg-surfaceCard border border-error/20 rounded-xl overflow-hidden">
        <div className="px-6 py-4 border-b border-error/20 flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-error/15 flex items-center justify-center">
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 text-error">
              <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
            </svg>
          </div>
          <h3 className="font-semibold text-error text-sm">Zona de peligro</h3>
        </div>
        <div className="p-6 flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-textPrimary">Cerrar sesión</p>
            <p className="text-xs text-textMuted mt-0.5">Cierra tu sesión en todos los dispositivos de este navegador</p>
          </div>
          <button onClick={logout} className="btn-danger text-sm">
            Cerrar sesión
          </button>
        </div>
      </div>

      {/* Version info */}
      <div className="text-center pt-2">
        <p className="text-xs text-textMuted">CobrosApp Admin Panel v1.0.0</p>
        <p className="text-xs text-textMuted mt-0.5">
          API: {import.meta.env.VITE_API_URL || 'http://localhost:3000/api'}
        </p>
      </div>
    </div>
  )
}
