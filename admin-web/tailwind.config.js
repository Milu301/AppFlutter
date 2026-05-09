/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        bg: '#080C18',
        surface: '#111827',
        surfaceCard: '#161E30',
        surfaceBright: '#1E2640',
        primary: {
          DEFAULT: '#6C63FF',
          hover: '#5A52E0',
          light: 'rgba(108,99,255,0.15)',
        },
        success: {
          DEFAULT: '#00D4A0',
          light: 'rgba(0,212,160,0.15)',
        },
        warning: {
          DEFAULT: '#FFB020',
          light: 'rgba(255,176,32,0.15)',
        },
        error: {
          DEFAULT: '#FF5C72',
          light: 'rgba(255,92,114,0.15)',
        },
        info: {
          DEFAULT: '#3ECFFF',
          light: 'rgba(62,207,255,0.15)',
        },
        textPrimary: '#EDF2FF',
        textSecondary: '#8899BB',
        textMuted: '#4D5E7A',
        border: '#1F2D45',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        card: '0 4px 24px rgba(0,0,0,0.4)',
        glow: '0 0 20px rgba(108,99,255,0.3)',
      },
      animation: {
        'fade-in': 'fadeIn 0.2s ease-in-out',
        'slide-in': 'slideIn 0.2s ease-out',
        'spin-slow': 'spin 1.5s linear infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideIn: {
          '0%': { opacity: '0', transform: 'translateY(-8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
}
