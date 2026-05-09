import axios from 'axios'

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000/api'

const apiClient = axios.create({
  baseURL: BASE_URL,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor — attach JWT token
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('cobros_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error),
)

// Response interceptor — unwrap { ok, data } envelope + handle 401 → logout
apiClient.interceptors.response.use(
  (response) => {
    // Backend always responds { ok: true, data: X } — unwrap automatically
    if (response.data && response.data.ok === true && 'data' in response.data) {
      response.data = response.data.data
    }
    return response
  },
  (error) => {
    // Normalize { ok: false, error: { code, message } } so callers can use err.response.data.message
    if (error.response?.data?.error?.message) {
      error.response.data.message = error.response.data.error.message
    }
    if (error.response?.status === 401) {
      localStorage.removeItem('cobros_token')
      localStorage.removeItem('cobros_admin')
      if (window.location.pathname !== '/') {
        window.location.href = '/'
      }
    }
    return Promise.reject(error)
  },
)

export default apiClient

// ─── Auth ──────────────────────────────────────────────────────────────────
export const authAPI = {
  login: (email, password) =>
    apiClient.post('/auth/admin/login', { email, password }),
}

// ─── Admins / Stats ────────────────────────────────────────────────────────
export const adminAPI = {
  getStats: (adminId) => apiClient.get(`/admins/${adminId}/stats`),
  getVendors: (adminId) => apiClient.get(`/admins/${adminId}/vendors`),
  createVendor: (adminId, data) => apiClient.post(`/admins/${adminId}/vendors`, data),
  getClients: (adminId, params = {}) =>
    apiClient.get(`/admins/${adminId}/clients`, { params }),
  getCash: (adminId, date) =>
    apiClient.get(`/admins/${adminId}/cash`, { params: { date } }),
  getAllCash: (adminId, date, params = {}) =>
    apiClient.get(`/admins/${adminId}/cash/all`, { params: { date, ...params } }),
  getAllCashSummary: (adminId, date) =>
    apiClient.get(`/admins/${adminId}/cash/all/summary`, { params: { date } }),
  getCashSummary: (adminId, date) =>
    apiClient.get(`/admins/${adminId}/cash/summary`, { params: { date } }),
  createCashMovement: (adminId, data) =>
    apiClient.post(`/admins/${adminId}/cash/movements`, data),
  getCollectionsReport: (adminId, params = {}) =>
    apiClient.get(`/admins/${adminId}/reports/collections`, { params }),
  getLateClientsReport: (adminId, params = {}) =>
    apiClient.get(`/admins/${adminId}/reports/late-clients`, { params }),
  getVendorPerformanceReport: (adminId, params = {}) =>
    apiClient.get(`/admins/${adminId}/reports/vendor-performance`, { params }),
  getVendorRouteDay: (adminId, vendorId, date) =>
    apiClient.get(`/admins/${adminId}/vendors/${vendorId}/route-day`, { params: { date } }),
  getVendorStats: (adminId, vendorId) =>
    apiClient.get(`/vendors/${vendorId}/stats`),
  getAllVendorLocations: (adminId) =>
    apiClient.get(`/admins/${adminId}/vendors/locations/latest`),
  getVendorLatestLocation: (adminId, vendorId) =>
    apiClient.get(`/admins/${adminId}/vendors/${vendorId}/location/latest`),
}

// ─── Vendors ───────────────────────────────────────────────────────────────
export const vendorAPI = {
  update: (vendorId, data) => apiClient.put(`/vendors/${vendorId}`, data),
  delete: (vendorId) => apiClient.delete(`/vendors/${vendorId}`),
  resetDevice: (vendorId) => apiClient.post(`/vendors/${vendorId}/reset-device`),
  resetPassword: (vendorId, password) => apiClient.post(`/vendors/${vendorId}/reset-password`, { password }),
  toggleStatus: (vendorId, active) =>
    apiClient.put(`/vendors/${vendorId}`, { status: active ? 'active' : 'inactive' }),
}

// ─── Clients ───────────────────────────────────────────────────────────────
export const clientAPI = {
  getCredits: (clientId) => apiClient.get(`/clients/${clientId}/credits`),
  reassign: (clientId, vendorId) =>
    apiClient.put(`/clients/${clientId}`, { vendor_id: vendorId }),
  hardDelete: (adminId, clientId) =>
    apiClient.delete(`/admins/${adminId}/clients/${clientId}/hard`),
}
