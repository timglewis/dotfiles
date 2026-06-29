return {
  -- Actively-maintained Roslyn C# language server integration (successor to the
  -- archived jmederosalvarado/roslyn.nvim). Uses the official Microsoft Roslyn
  -- server. Requires `roslyn-language-server` (or the `roslyn` Mason package) to be
  -- installed locally — see install note in the repo.
  'seblyng/roslyn.nvim',
  ft = 'cs',
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  opts = {},
}
