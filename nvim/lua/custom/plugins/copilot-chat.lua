return {
  'CopilotC-Nvim/CopilotChat.nvim',
  dependencies = {
    'github/copilot.vim',
    'nvim-lua/plenary.nvim',
  },
  cmd = {
    'CopilotChat',
    'CopilotChatOpen',
    'CopilotChatToggle',
    'CopilotChatExplain',
    'CopilotChatFix',
    'CopilotChatOptimize',
    'CopilotChatTests',
    'CopilotChatDocs',
  },
  keys = {
    { '<leader>cc', '<cmd>CopilotChatToggle<cr>', desc = '[C]opilot [c]hat toggle' },
    { '<leader>ce', '<cmd>CopilotChatExplain<cr>', mode = { 'n', 'v' }, desc = '[C]opilot [e]xplain' },
    { '<leader>cf', '<cmd>CopilotChatFix<cr>', mode = { 'n', 'v' }, desc = '[C]opilot [f]ix' },
    { '<leader>co', '<cmd>CopilotChatOptimize<cr>', mode = { 'n', 'v' }, desc = '[C]opilot [o]ptimize' },
    { '<leader>ct', '<cmd>CopilotChatTests<cr>', mode = { 'n', 'v' }, desc = '[C]opilot [t]ests' },
    { '<leader>cd', '<cmd>CopilotChatDocs<cr>', mode = { 'n', 'v' }, desc = '[C]opilot [d]ocs' },
  },
  opts = {},
}
