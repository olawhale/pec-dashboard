import { useState } from 'react'
import { runNlQuery } from '../api/client'
import type { QueryResponse } from '../types'

export function QueryPanel() {
  const [question, setQuestion] = useState('')
  const [result, setResult]     = useState<QueryResponse | null>(null)
  const [error, setError]       = useState<string | null>(null)
  const [loading, setLoading]   = useState(false)
  const [showSql, setShowSql]   = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!question.trim()) return
    setLoading(true)
    setError(null)
    setResult(null)
    try {
      const res = await runNlQuery(question)
      setResult(res)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Unknown error'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
      <h2 className="text-base font-semibold text-gray-700 mb-4">AI Query Agent</h2>

      <form onSubmit={handleSubmit} className="flex gap-2">
        <input
          value={question}
          onChange={e => setQuestion(e.target.value)}
          placeholder="e.g. Which partner earned the most PEC last month?"
          className="flex-1 rounded-lg border border-gray-300 px-4 py-2 text-sm
                     focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-brand-500 px-4 py-2 text-sm font-medium text-white
                     hover:bg-brand-700 disabled:opacity-50"
        >
          {loading ? 'Querying…' : 'Ask'}
        </button>
      </form>

      {error && (
        <p className="mt-3 text-sm text-red-600">{error}</p>
      )}

      {result && (
        <div className="mt-4 space-y-3">
          <button
            onClick={() => setShowSql(s => !s)}
            className="text-xs text-brand-500 hover:underline"
          >
            {showSql ? 'Hide SQL' : 'Show generated SQL'}
          </button>
          {showSql && (
            <pre className="rounded-lg bg-gray-50 p-3 text-xs overflow-x-auto">
              {result.sql}
            </pre>
          )}

          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead>
                <tr className="border-b border-gray-200">
                  {result.columns.map(col => (
                    <th key={col} className="py-2 pr-4 font-medium text-gray-600">
                      {col}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {result.rows.map((row, i) => (
                  <tr key={i} className="border-b border-gray-100 hover:bg-gray-50">
                    {row.map((cell, j) => (
                      <td key={j} className="py-2 pr-4 text-gray-700">
                        {String(cell ?? '')}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
            {result.rows.length === 0 && (
              <p className="mt-2 text-sm text-gray-400">No rows returned.</p>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
