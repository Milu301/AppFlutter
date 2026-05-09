import React, { useEffect, useRef, useState, useCallback } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { adminAPI } from '../api/client'

const REFRESH_INTERVAL = 30_000 // 30s

function timeAgo(dateStr) {
  if (!dateStr) return 'Sin datos'
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000)
  if (diff < 60) return `Hace ${diff}s`
  if (diff < 3600) return `Hace ${Math.floor(diff / 60)}min`
  if (diff < 86400) return `Hace ${Math.floor(diff / 3600)}h`
  return `Hace ${Math.floor(diff / 86400)}d`
}

export default function Locations() {
  const { admin } = useAuth()
  const adminId = admin?.adminId || admin?.id
  const mapRef = useRef(null)
  const mapInstanceRef = useRef(null)
  const markersRef = useRef({})

  const [vendors, setVendors] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [lastUpdate, setLastUpdate] = useState(null)
  const [selected, setSelected] = useState(null)

  const fetchLocations = useCallback(async () => {
    if (!adminId) return
    try {
      const { data } = await adminAPI.getAllVendorLocations(adminId)
      const list = Array.isArray(data) ? data : (data?.items || [])
      setVendors(list)
      setLastUpdate(new Date())
      setError(null)
    } catch (err) {
      setError(err.response?.data?.message || 'Error al cargar ubicaciones')
    } finally {
      setLoading(false)
    }
  }, [adminId])

  // Init map once
  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current || !window.L) return

    const L = window.L
    const map = L.map(mapRef.current, {
      center: [4.7109886, -74.072092],
      zoom: 12,
      zoomControl: true,
    })

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 19,
    }).addTo(map)

    mapInstanceRef.current = map

    return () => {
      map.remove()
      mapInstanceRef.current = null
    }
  }, [])

  // Update markers when vendors change
  useEffect(() => {
    const map = mapInstanceRef.current
    const L = window.L
    if (!map || !L || vendors.length === 0) return

    const bounds = []

    vendors.forEach((v) => {
      if (!v.lat || !v.lng) return

      const lat = parseFloat(v.lat)
      const lng = parseFloat(v.lng)
      if (isNaN(lat) || isNaN(lng)) return

      const minutesAgo = (Date.now() - new Date(v.recorded_at).getTime()) / 60000
      const isRecent = minutesAgo < 10
      const color = isRecent ? '#22c55e' : minutesAgo < 60 ? '#f59e0b' : '#6b7280'

      const iconHtml = `
        <div style="
          width:36px;height:36px;border-radius:50%;
          background:${color};
          border:3px solid white;
          box-shadow:0 2px 8px rgba(0,0,0,0.35);
          display:flex;align-items:center;justify-content:center;
          font-weight:800;font-size:14px;color:white;
          font-family:sans-serif;
        ">${(v.vendor_name || '?')[0].toUpperCase()}</div>
      `

      const icon = L.divIcon({
        html: iconHtml,
        className: '',
        iconSize: [36, 36],
        iconAnchor: [18, 18],
      })

      if (markersRef.current[v.vendor_id]) {
        markersRef.current[v.vendor_id].setLatLng([lat, lng])
          .setIcon(icon)
          .setPopupContent(_popupContent(v))
      } else {
        const marker = L.marker([lat, lng], { icon })
          .addTo(map)
          .bindPopup(_popupContent(v))
        markersRef.current[v.vendor_id] = marker
      }

      bounds.push([lat, lng])
    })

    if (bounds.length > 0) {
      map.fitBounds(bounds, { padding: [40, 40], maxZoom: 14 })
    }
  }, [vendors])

  function _popupContent(v) {
    const minutesAgo = (Date.now() - new Date(v.recorded_at).getTime()) / 60000
    const isRecent = minutesAgo < 10
    const statusColor = isRecent ? '#22c55e' : minutesAgo < 60 ? '#f59e0b' : '#6b7280'
    return `
      <div style="min-width:160px;font-family:sans-serif">
        <strong style="font-size:14px">${v.vendor_name || 'Vendedor'}</strong>
        <br/>
        <span style="color:${statusColor};font-size:12px">● ${timeAgo(v.recorded_at)}</span>
        ${v.battery_level != null ? `<br/><span style="font-size:11px;color:#888">🔋 ${Math.round(v.battery_level * 100)}%</span>` : ''}
        <br/>
        <span style="font-size:11px;color:#888">${parseFloat(v.lat).toFixed(5)}, ${parseFloat(v.lng).toFixed(5)}</span>
      </div>
    `
  }

  function focusVendor(v) {
    setSelected(v.vendor_id)
    const map = mapInstanceRef.current
    if (!map || !v.lat || !v.lng) return
    map.setView([parseFloat(v.lat), parseFloat(v.lng)], 16)
    const marker = markersRef.current[v.vendor_id]
    if (marker) marker.openPopup()
  }

  // Auto-refresh
  useEffect(() => {
    fetchLocations()
    const id = setInterval(fetchLocations, REFRESH_INTERVAL)
    return () => clearInterval(id)
  }, [fetchLocations])

  return (
    <div className="space-y-5 h-full flex flex-col" style={{ minHeight: 'calc(100vh - 120px)' }}>
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3 flex-shrink-0">
        <div>
          <h2 className="section-title">Ubicaciones en tiempo real</h2>
          <p className="text-textMuted text-sm mt-0.5">
            Posición actual de los vendedores · actualiza cada 30s
            {lastUpdate && <span className="ml-2 text-textMuted/60">(última actualización: {lastUpdate.toLocaleTimeString('es-MX')})</span>}
          </p>
        </div>
        <button
          onClick={() => { setLoading(true); fetchLocations() }}
          disabled={loading}
          className="btn-secondary text-sm"
        >
          <svg viewBox="0 0 20 20" fill="currentColor" className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`}>
            <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
          </svg>
          Actualizar
        </button>
      </div>

      {error && (
        <div className="px-4 py-3 bg-error/10 border border-error/30 rounded-xl text-error text-sm flex-shrink-0">{error}</div>
      )}

      <div className="flex gap-4 flex-1 min-h-0">
        {/* Vendor list sidebar */}
        <div className="w-56 flex-shrink-0 flex flex-col gap-2 overflow-y-auto">
          {loading && vendors.length === 0 && (
            <div className="bg-surfaceCard border border-border rounded-xl p-4 text-center text-textMuted text-sm">
              Cargando...
            </div>
          )}
          {!loading && vendors.length === 0 && (
            <div className="bg-surfaceCard border border-border rounded-xl p-4 text-center text-textMuted text-sm">
              Sin ubicaciones registradas
            </div>
          )}
          {vendors.map((v) => {
            const minutesAgo = v.recorded_at
              ? (Date.now() - new Date(v.recorded_at).getTime()) / 60000
              : Infinity
            const isRecent = minutesAgo < 10
            const dotColor = isRecent ? 'bg-success' : minutesAgo < 60 ? 'bg-warning' : 'bg-textMuted'
            const isSelected = selected === v.vendor_id

            return (
              <button
                key={v.vendor_id}
                onClick={() => focusVendor(v)}
                className={`w-full text-left px-3 py-2.5 rounded-xl border transition-all ${
                  isSelected
                    ? 'bg-primary/15 border-primary/40'
                    : 'bg-surfaceCard border-border hover:bg-surfaceBright'
                }`}
              >
                <div className="flex items-center gap-2">
                  <span className={`w-2 h-2 rounded-full flex-shrink-0 ${dotColor}`} />
                  <span className="text-sm font-medium text-textPrimary truncate">{v.vendor_name || 'Vendedor'}</span>
                </div>
                <p className="text-xs text-textMuted mt-0.5 ml-4">{timeAgo(v.recorded_at)}</p>
              </button>
            )
          })}
        </div>

        {/* Map */}
        <div className="flex-1 min-h-0 bg-surfaceCard border border-border rounded-xl overflow-hidden" style={{ minHeight: 400 }}>
          {!window.L && (
            <div className="flex items-center justify-center h-full text-textMuted text-sm">
              Cargando mapa...
            </div>
          )}
          <div ref={mapRef} style={{ width: '100%', height: '100%', minHeight: 400 }} />
        </div>
      </div>

      {/* Legend */}
      <div className="flex items-center gap-4 flex-shrink-0">
        <span className="text-xs text-textMuted">Leyenda:</span>
        <div className="flex items-center gap-1.5">
          <span className="w-2.5 h-2.5 rounded-full bg-success" />
          <span className="text-xs text-textMuted">Activo (&lt;10min)</span>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="w-2.5 h-2.5 rounded-full bg-warning" />
          <span className="text-xs text-textMuted">Reciente (&lt;1h)</span>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="w-2.5 h-2.5 rounded-full bg-textMuted" />
          <span className="text-xs text-textMuted">Inactivo</span>
        </div>
      </div>
    </div>
  )
}
