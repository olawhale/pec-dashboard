import {
  ComposedChart,
  Line,
  Bar,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import type { ForecastRow } from '../types'

interface Props {
  data: ForecastRow[]
}

interface ChartRow {
  label: string
  actual?: number
  forecast?: number
  band?: [number, number]
}

function fmt(n: number | null): number | undefined {
  return n != null ? Math.round(n * 100) / 100 : undefined
}

export function PECChart({ data }: Props) {
  const rows: ChartRow[] = data.map(r => ({
    label: `${r.month_name.slice(0, 3)} ${r.year}`,
    actual:   fmt(r.actual_pec_amount),
    forecast: fmt(r.forecasted_pec_amount),
    band:
      r.forecast_lower != null && r.forecast_upper != null
        ? [Math.round(r.forecast_lower), Math.round(r.forecast_upper)]
        : undefined,
  }))

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
      <h2 className="text-base font-semibold text-gray-700 mb-4">
        PEC Actual vs. Forecast
      </h2>
      <ResponsiveContainer width="100%" height={320}>
        <ComposedChart data={rows} margin={{ top: 4, right: 16, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="label" tick={{ fontSize: 12 }} />
          <YAxis
            tick={{ fontSize: 12 }}
            tickFormatter={v => `$${(v as number / 1000).toFixed(0)}k`}
          />
          <Tooltip
            formatter={(value: number) => [`$${value.toLocaleString()}`, '']}
          />
          <Legend />
          <Bar dataKey="actual" name="Actual PEC" fill="#0078d4" radius={[3, 3, 0, 0]} />
          <Area
            dataKey="band"
            name="Forecast band"
            fill="#bfdbfe"
            stroke="none"
            connectNulls
          />
          <Line
            dataKey="forecast"
            name="Forecast"
            stroke="#f59e0b"
            strokeDasharray="5 3"
            dot={false}
            connectNulls
          />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  )
}
