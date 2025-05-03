---@Class core
local M = {}
local ui = require("taskfile.ui")
local utils = require("taskfile.utils")

--- default configuration
local config = {
  float = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  scroll = {
    auto = true,
  },
  keymaps = {
    rerun = "<leader>tr",
  },
}

M._win = nil
M._buf = nil
M._last_task = nil
M._options = vim.tbl_deep_extend("force", {}, config, opts or {})

local function setup_global_keymaps()
  if M._options.keymaps and M._options.keymaps.rerun then
    local rerun_key = M._options.keymaps.rerun
    vim.keymap.set("n", rerun_key, function()
      if M._last_task then
        M.execute_task(M._last_task)
      else
        vim.notify("No task has been run yet.", vim.log.levels.WARN)
      end
    end, { desc = string.format("[%s] Rerun last task", rerun_key) })
  end
end

local function run_task_in_terminal(buf, task)
  local opts = {}
  if M._options.scroll.auto then
    opts.on_stdout = utils.scroll_to_bottom
    opts.on_stderr = utils.scroll_to_bottom
    opts.on_exit = utils.scroll_to_bottom
  end

  local term_opts = next(opts) and opts or vim.empty_dict()
  vim.fn.termopen("task " .. task, term_opts)
end

local function set_quit_key(buf, win)
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, nowait = true, silent = true })
end

local function taskfile_check()
  if vim.fn.executable("task") ~= 1 then
    vim.notify("'task' executable not found in PATH", vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Taskfile plugin configuration
---@class TaskfileConfig
---@field float? { width?: number, height?: number, border?: string } Floating window dimensions and border
---@field scroll? { auto?: boolean } Auto-scroll output to the bottom
---@field keymaps? { rerun?: string } Keymap configuration for commands like rerun
--- Setup the Taskfile plugin
---@param opts TaskfileConfig?
M.setup = function(opts)
  ui.set_execute_task(M.execute_task)

  vim.validate({
    opts = { opts, "table", true },
  })
  M._options = vim.tbl_deep_extend("force", {}, config, opts or {})

  if M._options.keymaps ~= false then
    setup_global_keymaps()
  end
end

M.get_tasks = function()
  if not taskfile_check() then
    return {}
  end
  local response = vim.fn.system("task --list-all --json")
  if vim.v.shell_error ~= 0 then
    vim.notify("Task command failed (missing Taskfile?)", vim.log.levels.ERROR)
    return {}
  end
  local ok, data = pcall(vim.fn.json_decode, response)
  if not ok or not data or not data.tasks then
    vim.notify("Failed to parse task output.", vim.log.levels.ERROR)
    return {}
  end
  return data.tasks
end

M.get_last_task = function()
  return M._last_task
end

M.execute_task = function(task)
  if not taskfile_check() then
    return
  end

  local tasks = M.get_tasks()
  local exists = false
  for _, t in ipairs(tasks) do
    if t.name == task then
      exists = true
      break
    end
  end

  if not exists then
    vim.notify("Task '" .. task .. "' not found in Taskfile", vim.log.levels.ERROR)
    return
  end

  utils.cleanup_terminal(M._win, M._buf)
  local buf, win = ui.create_terminal_window(M._options.float)

  run_task_in_terminal(buf, task)
  M._last_task = task

  set_quit_key(buf, win)
end

M.on_choice = function(item)
  if not item or not item.name then
    vim.notify("Invalid task selection: no 'name' field", vim.log.levels.WARN)
    return
  end
  M.execute_task(item.name)
end

return M
