interface Props {
  title: string
  value: string
  subtitle?: string
  trend?: 'up' | 'down' | 'flat'
}

export function KPICard({ title, value, subtitle, trend }: Props) {
  const trendColor =
    trend === 'up' ? 'text-green-600' :
    trend === 'down' ? 'text-red-500' : 'text-gray-400'

  const trendIcon =
    trend === 'up' ? '▲' : trend === 'down' ? '▼' : '—'

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
      <p className="text-sm font-medium text-gray-500">{title}</p>
      <p className="mt-1 text-3xl font-semibold text-gray-900">{value}</p>
      {(subtitle || trend) && (
        <p className={`mt-1 text-sm ${trendColor}`}>
          {trend && <span className="mr-1">{trendIcon}</span>}
          {subtitle}
        </p>
      )}
    </div>
  )
}
