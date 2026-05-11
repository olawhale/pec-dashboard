import axios from 'axios'
import type { MonthlySummaryRow, ForecastRow, QueryResponse } from '../types'

const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '',
})

export async function fetchSummary(partner?: string, year?: number): Promise<MonthlySummaryRow[]> {
  const params: Record<string, string | number> = {}
  if (partner) params.partner_name = partner
  if (year)    params.year = year
  const { data } = await http.get<MonthlySummaryRow[]>('/api/pec/summary', { params })
  return data
}

export async function fetchForecast(partner?: string): Promise<ForecastRow[]> {
  const params: Record<string, string> = {}
  if (partner) params.partner_name = partner
  const { data } = await http.get<ForecastRow[]>('/api/pec/forecast', { params })
  return data
}

export async function fetchPartners(): Promise<string[]> {
  const { data } = await http.get<string[]>('/api/pec/partners')
  return data
}

export async function runNlQuery(question: string): Promise<QueryResponse> {
  const { data } = await http.post<QueryResponse>('/api/query', { question })
  return data
}
