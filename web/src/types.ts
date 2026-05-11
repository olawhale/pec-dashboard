export interface MonthlySummaryRow {
  year: number
  month: number
  month_name: string
  partner_name: string
  service_family: string
  total_pec_amount: number
  total_unit_amount: number
}

export interface ForecastRow {
  year: number
  month: number
  month_name: string
  partner_name: string
  actual_pec_amount: number | null
  forecasted_pec_amount: number | null
  forecast_lower: number | null
  forecast_upper: number | null
}

export interface QueryResponse {
  sql: string
  columns: string[]
  rows: unknown[][]
}
