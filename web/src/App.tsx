import { BrowserRouter, NavLink, Route, Routes } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Dashboard } from './pages/Dashboard'
import { Query } from './pages/Query'

const qc = new QueryClient({ defaultOptions: { queries: { staleTime: 60_000 } } })

const navClass = ({ isActive }: { isActive: boolean }) =>
  `px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
    isActive
      ? 'bg-brand-500 text-white'
      : 'text-gray-600 hover:bg-gray-100'
  }`

export default function App() {
  return (
    <QueryClientProvider client={qc}>
      <BrowserRouter>
        <div className="min-h-screen bg-gray-50">
          {/* Top nav */}
          <header className="bg-white border-b border-gray-200 px-6 py-3 flex items-center gap-6">
            <span className="text-lg font-bold text-brand-500">PEC Dashboard</span>
            <nav className="flex gap-1">
              <NavLink to="/"      className={navClass} end>Overview</NavLink>
              <NavLink to="/query" className={navClass}>AI Query</NavLink>
            </nav>
          </header>

          <main className="max-w-6xl mx-auto px-6 py-8">
            <Routes>
              <Route path="/"      element={<Dashboard />} />
              <Route path="/query" element={<Query />} />
            </Routes>
          </main>
        </div>
      </BrowserRouter>
    </QueryClientProvider>
  )
}
