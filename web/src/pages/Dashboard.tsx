import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { fetchSummary, fetchForecast, fetchPartners } from '../api/client'
import { KPICard } from '../components/KPICard'
import { PECChart } from '../components/PECChart'
import type { MonthlySummaryRow } from '../types'

function fmt(n: number) {
  if (n >= 1_000_000) return `$${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000)     return `$${(n / 1_000).toFixed(1)}k`
  return `$${n.toFixed(2)}`
}

function kpis(rows: MonthlySummaryRow[]) {
  const total = rows.reduce((s, r) => s + r.total_pec_amount, 0)

  const byMonth = rows.reduce<Record<string, number>>((acc, r) => {
    const key = `${r.year}-${r.month}`
    acc[key] = (acc[key] ?? 0) + r.total_pec_amount
    return acc
  }, {})
  const months = Object.entries(byMonth).sort(([a], [b]) => a.localeCompare(b))
  const lastMonth  = months.at(-1)?.[1] ?? 0
  const prevMonth  = months.at(-2)?.[1] ?? 0
  const trend = lastMonth > prevMonth ? 'up' : lastMonth < prevMonth ? 'down' : 'flat'
  const change = prevMonth ? (((lastMonth - prevMonth) / prevMonth) * 100).toFixed(1) : null

  return { total, lastMonth, trend, change }
}

export function Dashboard() {
  const [partner, setPartner] = useState<string>('')

  const { data: partners = [] } = useQuery({
    queryKey: ['partners'],
    queryFn: fetchPartners,
  })

  const { data: summary = [], isLoading: summaryLoading } = useQuery({
    queryKey: ['summary', partner],
    queryFn: () => fetchSummary(partner || undefined),
  })

  const { data: forecast = [], isLoading: forecastLoading } = useQuery({
    queryKey: ['forecast', partner],
    queryFn: () => fetchForecast(partner || undefined),
  })

  const { total, lastMonth, trend, change } = kpis(summary)

  return (
    <div className="space-y-6">
      {/* Filter bar */}
      <div className="flex items-center gap-3">
        <label className="text-sm font-medium text-gray-600">Partner</label>
        <select
          value={partner}
          onChange={e => setPartner(e.target.value)}
          className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm
                     focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          <option value="">All partners</option>
          {partners.map(p => (
            <option key={p} value={p}>{p}</option>
          ))}
        </select>
      </div>

      {/* KPI row */}
      {summaryLoading ? (
        <p className="text-sm text-gray-400">Loading…</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <KPICard
            title="Total PEC (all time)"
            value={fmt(total)}
          />
          <KPICard
            title="Last Month PEC"
            value={fmt(lastMonth)}
            trend={trend as 'up' | 'down' | 'flat'}
            subtitle={change ? `${change}% vs prior month` : undefined}
          />
          <KPICard
            title="Partners"
            value={String(partner ? 1 : partners.length)}
          />
        </div>
      )}

      {/* Chart */}
      {forecastLoading ? (
        <div className="h-80 bg-white rounded-xl border border-gray-100 animate-pulse" />
      ) : (
        <PECChart data={forecast} />
      )}
    </div>
  )
}
