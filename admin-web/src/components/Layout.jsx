import React, { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import { useAuth } from '../contexts/AuthContext'

const PAGE_TITLES = {
  '/dashboard': { title: 'Dashboard', subtitle: 'Resumen general' },
  '/vendors': { title: 'Vendedores', subtitle: 'Gestión de vendedores de ruta' },
  '/clients': { title: 'Clientes', subtitle: 'Listado de clientes y créditos' },
  '/cash': { title: 'Caja', subtitle: 'Movimientos y balance diario' },
  '/reports': { title: 'Reportes', subtitle: 'Análisis y estadísticas' },
  '/locations': { title: 'Ubicaciones', subtitle: 'Rastreo en tiempo real de vendedores' },
  '/settings': { title: 'Configuración', subtitle: 'Cuenta y preferencias' },
}

export default function Layout() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const location = useLocation()
  const { admin } = useAuth()
  const pageInfo = PAGE_TITLES[location.pathname] || { title: 'CobrosApp', subtitle: '' }
  const adminInitial = admin?.email?.[0]?.toUpperCase() || 'A'

  return (
    <div className="flex h-screen overflow-hidden bg-bg">
      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar — desktop */}
      <div className={`hidden lg:flex flex-shrink-0 transition-all duration-300 ${sidebarCollapsed ? 'w-16' : 'w-64'}`}>
        <Sidebar collapsed={sidebarCollapsed} onClose={() => {}} />
      </div>

      {/* Sidebar — mobile */}
      <div className={`fixed inset-y-0 left-0 z-50 flex lg:hidden transition-transform duration-300 ${mobileOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="w-64">
          <Sidebar collapsed={false} onClose={() => setMobileOpen(false)} />
        </div>
      </div>

      {/* Main content */}
      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        {/* Topbar */}
        <header className="flex-shrink-0 flex items-center gap-4 h-16 px-6 bg-surface border-b border-border">
          {/* Mobile hamburger */}
          <button
            onClick={() => setMobileOpen(true)}
            className="lg:hidden p-2 rounded-lg text-textMuted hover:text-textPrimary hover:bg-surfaceBright transition-colors"
          >
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
              <path fillRule="evenodd" d="M3 5a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 10a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 15a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clipRule="evenodd" />
            </svg>
          </button>

          {/* Desktop collapse toggle */}
          <button
            onClick={() => setSidebarCollapsed(c => !c)}
            className="hidden lg:flex p-2 rounded-lg text-textMuted hover:text-textPrimary hover:bg-surfaceBright transition-colors"
          >
            <svg viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
              <path fillRule="evenodd" d="M3 5a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 10a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 15a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clipRule="evenodd" />
            </svg>
          </button>

          {/* Page title */}
          <div className="flex-1 min-w-0">
            <h1 className="text-base font-semibold text-textPrimary truncate">{pageInfo.title}</h1>
            {pageInfo.subtitle && (
              <p className="text-xs text-textMuted hidden sm:block">{pageInfo.subtitle}</p>
            )}
          </div>

          {/* Right side */}
          <div className="flex items-center gap-3">
            <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-full bg-success/10 border border-success/20">
              <span className="w-1.5 h-1.5 rounded-full bg-success animate-pulse" />
              <span className="text-xs font-medium text-success">En línea</span>
            </div>
            {/* Admin avatar */}
            <div
              className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 text-sm font-bold text-white shadow-[0_0_12px_rgba(108,99,255,0.3)]"
              style={{ background: 'linear-gradient(135deg, #6C63FF, #4A43CC)' }}
              title={admin?.email}
            >
              {adminInitial}
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-y-auto p-6">
          <div className="max-w-7xl mx-auto animate-fade-in">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  )
}
