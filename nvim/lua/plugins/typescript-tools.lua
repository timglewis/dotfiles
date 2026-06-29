return {
  'pmizio/typescript-tools.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
  opts = {},
  config = function()
    require('typescript-tools').setup {}
    vim.keymap.set('n', '<leader>tsi', '<cmd>TSToolsAddMissingImports<cr>', { desc = '[TS]Tools Add Missing [I]mports' })
    vim.keymap.set('n', '<leader>tso', '<cmd>TSToolsOrganizeImports<cr>', { desc = 'TS: [O]rganize Imports' })
    vim.keymap.set('n', '<leader>tsr', '<cmd>TSToolsRenameFile<cr>', { desc = 'TS: [R]ename file' })
    vim.keymap.set('n', '<leader>tsu', '<cmd>TSToolsRemoveUnusedImports<cr>', { desc = 'TS: Remove [U]nused Imports' })
  end,
}
