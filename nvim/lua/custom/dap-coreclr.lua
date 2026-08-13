-- .NET (coreclr) debugging via netcoredbg, driven by .vscode/launch.json.
--
-- nvim-dap's own `load_launchjs` almost works for the ModelTiler repo, but it
-- resolves ${workspaceFolder} against vim.fn.getcwd() and ignores preLaunchTask.
-- This module finds the launch.json by walking up from the current file,
-- substitutes the workspace root itself, and turns each preLaunchTask into a
-- synchronous `dotnet build` of the owning csproj.

local M = {}

local function netcoredbg_path()
  local mason = vim.fn.stdpath 'data' .. '/mason/bin/netcoredbg'
  if vim.uv.fs_stat(mason) then
    return mason
  end
  return vim.fn.exepath 'netcoredbg'
end

--- Nearest ancestor of `start` containing .vscode/launch.json.
local function find_workspace(start)
  local found = vim.fs.find({ 'launch.json' }, {
    upward = true,
    path = start,
    type = 'file',
    -- vim.fs.find looks in `path` itself, so search for the .vscode dir instead
    -- and derive the file from it.
  })
  if #found > 0 and found[1]:match '%.vscode/launch%.json$' then
    return vim.fs.dirname(vim.fs.dirname(found[1])), found[1]
  end

  local vscode = vim.fs.find({ '.vscode' }, { upward = true, path = start, type = 'directory' })[1]
  if not vscode then
    return nil
  end
  local launch = vscode .. '/launch.json'
  if vim.uv.fs_stat(launch) then
    return vim.fs.dirname(vscode), launch
  end
  return nil
end

--- `<root>/apps/Foo/bin/Debug/.../Bar.dll` -> `<root>/apps/Foo/Foo.csproj`
local function csproj_for(program)
  local appdir = program:match '^(.*)/bin/'
  if not appdir then
    return nil
  end
  local projects = vim.fn.glob(appdir .. '/*.csproj', false, true)
  return projects[1]
end

--- Stand-in for VSCode's preLaunchTask: build, then hand back the dll path.
local function build_then_program(program)
  return function()
    local csproj = csproj_for(program)
    if csproj then
      vim.notify('dotnet build ' .. vim.fs.basename(csproj), vim.log.levels.INFO)
      local out = vim.fn.system { 'dotnet', 'build', csproj }
      if vim.v.shell_error ~= 0 then
        vim.notify(out, vim.log.levels.ERROR)
        error('build failed: ' .. vim.fs.basename(csproj))
      end
    end
    return program
  end
end

--- Read launch.json and register its configurations as dap.configurations.cs.
---@param start? string directory to search upward from (defaults to cwd)
---@return integer count
function M.load(start)
  local dap = require 'dap'
  local root, launch = find_workspace(start or vim.fn.getcwd())
  if not root then
    return 0
  end

  local ok, configs = pcall(require('dap.ext.vscode').getconfigs, launch)
  if not ok then
    vim.notify('launch.json: ' .. tostring(configs), vim.log.levels.ERROR)
    return 0
  end

  local loaded = {}
  for _, config in ipairs(configs) do
    if config.type == 'coreclr' then
      local c = vim.deepcopy(config)
      -- Resolve ${workspaceFolder} against the real root rather than cwd, so
      -- debugging works from any directory in the repo.
      for _, key in ipairs { 'program', 'cwd' } do
        if type(c[key]) == 'string' then
          c[key] = c[key]:gsub('%${workspaceFolder[^}]*}', root)
        end
      end
      if type(c.program) == 'string' and c.preLaunchTask then
        c.program = build_then_program(c.program)
        c.preLaunchTask = nil
      end
      table.insert(loaded, c)
    end
  end

  dap.configurations.cs = loaded
  return #loaded
end

function M.setup()
  local dap = require 'dap'

  dap.adapters.coreclr = {
    type = 'executable',
    command = netcoredbg_path(),
    args = { '--interpreter=vscode' },
  }

  M.load()

  vim.api.nvim_create_user_command('DapReloadLaunchJson', function()
    local n = M.load(vim.fn.expand '%:p:h')
    vim.notify(string.format('loaded %d coreclr configuration(s)', n), vim.log.levels.INFO)
  end, { desc = 'Re-read .vscode/launch.json into nvim-dap' })
end

return M
