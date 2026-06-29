return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('lualine').setup {
      options = {
        icons_enabled = true,
        theme = 'auto',
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = true,
        globalstatus = false,
        -- showtabline=1: only render the tabline when >1 tab exists (i.e. when
        -- diffview opens its own tab). Avoids an always-on tabline since tabs
        -- aren't used otherwise.
        always_show_tabline = false,
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000,
        },
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {
        lualine_a = {
          {
            'tabs',
            mode = 1,
            -- Diffview opens in its own tab and names its panel buffer with an
            -- internal URI (diffview:///panels/N/DiffviewFilePanel), which the
            -- native tabline would shorten to "d///p/1/DiffviewFilePanel".
            -- Relabel any tab containing a diffview buffer to a clean name.
            fmt = function(name, tab)
              local buflist = vim.fn.tabpagebuflist(tab.tabnr)
              if type(buflist) == 'table' then
                for _, b in ipairs(buflist) do
                  local ft = vim.bo[b].filetype
                  if ft == 'DiffviewFileHistory' then
                    return 'File History'
                  elseif ft == 'DiffviewFiles' then
                    return 'Diffview'
                  end
                end
              end
              return name
            end,
          },
        },
      },
      winbar = {},
      inactive_winbar = {},
      extensions = {},
    }
  end,
}
