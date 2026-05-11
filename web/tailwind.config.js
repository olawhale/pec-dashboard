/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50:  '#eff6ff',
          500: '#0078d4',
          700: '#005a9e',
        },
      },
    },
  },
  plugins: [],
}
