import React, { useEffect, useState } from 'react'

const ICONS = {
  success: (
    <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 flex-shrink-0">
      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
    </svg>
  ),
  error: (
    <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 flex-shrink-0">
      <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
    </svg>
  ),
  info: (
    <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 flex-shrink-0">
      <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
    </svg>
  ),
  warning: (
    <svg viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 flex-shrink-0">
      <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
    </svg>
  ),
}

const STYLES = {
  success: 'bg-success/10 border-success/30 text-success',
  error:   'bg-error/10   border-error/30   text-error',
  info:    'bg-info/10    border-info/30     text-info',
  warning: 'bg-warning/10 border-warning/30 text-warning',
}

/**
 * Drop-in inline toast. Auto-dismisses after `duration` ms.
 *
 * @param {{ message: string, type?: 'success'|'error'|'info'|'warning', duration?: number, onDismiss?: () => void }} props
 */
export default function Toast({ message, type = 'success', duration = 3500, onDismiss }) {
  const [visible, setVisible] = useState(true)

  useEffect(() => {
    if (!duration) return
    const t = setTimeout(() => {
      setVisible(false)
      onDismiss?.()
    }, duration)
    return () => clearTimeout(t)
  }, [duration, onDismiss])

  if (!visible || !message) return null

  return (
    <div
      className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm border animate-slide-in ${STYLES[type] ?? STYLES.info}`}
      role="alert"
    >
      {ICONS[type]}
      <span className="flex-1">{message}</span>
      <button
        onClick={() => { setVisible(false); onDismiss?.() }}
        className="opacity-60 hover:opacity-100 transition-opacity ml-1"
        aria-label="Cerrar"
      >
        <svg viewBox="0 0 16 16" fill="none" className="w-3.5 h-3.5">
          <path d="M12 4L4 12M4 4l8 8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
      </button>
    </div>
  )
}

/** Convenience hook: returns [toastProps, showToast] */
export function useToast() {
  const [toast, setToast] = useState(null)

  const show = (message, type = 'success') => setToast({ message, type })
  const dismiss = () => setToast(null)

  const toastEl = toast
    ? <Toast message={toast.message} type={toast.type} onDismiss={dismiss} />
    : null

  return [toastEl, show]
}
