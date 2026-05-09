import React, { createContext, useContext, useState, useCallback, useEffect } from 'react'
import { authAPI } from '../api/client'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [admin, setAdmin] = useState(() => {
    try {
      const stored = localStorage.getItem('cobros_admin')
      return stored ? JSON.parse(stored) : null
    } catch {
      return null
    }
  })
  const [token, setToken] = useState(() => localStorage.getItem('cobros_token'))
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const isAuthenticated = Boolean(token && admin)

  const login = useCallback(async (email, password) => {
    setLoading(true)
    setError(null)
    try {
      const { data } = await authAPI.login(email, password)

      // Interceptor unwraps { ok, data } → data = { token, admin, session, ... }
      const receivedToken = data.token || data.access_token || data.accessToken
      const baseAdmin = data.admin || data.user || {}
      // adminId may be in admin object or in the session field depending on backend version
      const resolvedId = baseAdmin.adminId ?? baseAdmin.id ?? data.session?.adminId ?? data.adminId
      const receivedAdmin = { ...baseAdmin, adminId: resolvedId, id: resolvedId }

      if (!receivedToken) throw new Error('No token received from server')

      localStorage.setItem('cobros_token', receivedToken)
      localStorage.setItem('cobros_admin', JSON.stringify(receivedAdmin))
      setToken(receivedToken)
      setAdmin(receivedAdmin)
      return { success: true }
    } catch (err) {
      const message =
        err.response?.data?.message ||
        err.response?.data?.error?.message ||
        err.message ||
        'Login failed'
      setError(message)
      return { success: false, message }
    } finally {
      setLoading(false)
    }
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('cobros_token')
    localStorage.removeItem('cobros_admin')
    setToken(null)
    setAdmin(null)
  }, [])

  // Keep state in sync if localStorage changes in another tab
  useEffect(() => {
    const onStorage = (e) => {
      if (e.key === 'cobros_token' && !e.newValue) {
        setToken(null)
        setAdmin(null)
      }
    }
    window.addEventListener('storage', onStorage)
    return () => window.removeEventListener('storage', onStorage)
  }, [])

  const value = {
    admin,
    token,
    isAuthenticated,
    loading,
    error,
    login,
    logout,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
