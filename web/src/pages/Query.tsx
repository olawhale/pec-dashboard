import { QueryPanel } from '../components/QueryPanel'

export function Query() {
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold text-gray-800">AI Query</h1>
        <p className="mt-1 text-sm text-gray-500">
          Ask questions about your PEC data in plain English. The AI generates
          safe, read-only SQL against the Partner Earned Credit dataset.
        </p>
      </div>
      <QueryPanel />
    </div>
  )
}
