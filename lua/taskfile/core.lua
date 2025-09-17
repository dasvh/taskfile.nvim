---@Class core
local M = {}
local ui = require("taskfile.ui")
local utils = require("taskfile.utils")

--- default configuration
local config = {
  layout = "horizontal",
  windows = {
    output = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
    list = {
      width = 0.6,
      height = 0.4,
      border = "rounded",
      width_ratio = 0,
      height_ratio = 0,
    },
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
M._options = vim.tbl_deep_extend("force", {}, config or {})

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

local function run_task_in_terminal(task)
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
    utils.cleanup_terminal(win, buf)
  end, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    utils.cleanup_terminal(win, buf)
  end, { buffer = buf, nowait = true, silent = true })
end

local function taskfile_check()
  if vim.fn.executable("task") ~= 1 then
    vim.notify("'task' executable not found in PATH", vim.log.levels.ERROR)
    return false
  end
  return true
end

---@class WindowConfig
---@field width? number  # Width of the window (0–1 for percentage)
---@field height? number # Height of the window (0–1 for percentage)
---@field border? string # Border style (e.g., "single", "rounded")

---@class ListWindowConfig : WindowConfig
---@field width_ratio? number # Ratio (0–1) of list vs preview width. Default is 0.4

---@class TaskfileConfig
---@field windows? { output?: WindowConfig, list?: ListWindowConfig } # Floating window layouts
---@field scroll? { auto?: boolean } # Auto-scroll output to the bottom
---@field keymaps? { rerun?: string } # Keymap configuration for commands like rerun
--- Setup the Taskfile plugin
---@param opts TaskfileConfig?
M.setup = function(opts)
  ui.set_execute_task(M.execute_task)
  ui.set_close_task_output(M.close_task_output_window)

  vim.validate({
    opts = { opts, "table", true },
  })
  M._options = vim.tbl_deep_extend("force", {}, config, opts or {})

  M._options.layout = utils.normalize_layout(M._options.layout)

  utils.validate_range({
    ["windows.output.width"] = M._options.windows.output.width,
    ["windows.output.height"] = M._options.windows.output.height,
    ["windows.list.width"] = M._options.windows.list.width,
    ["windows.list.height"] = M._options.windows.list.height,
    ["windows.list.width_ratio"] = M._options.windows.list.width_ratio,
    ["windows.list.height_ratio"] = M._options.windows.list.height_ratio,
  }, 0, 1)

  if M._options.keymaps ~= false then
    setup_global_keymaps()
  end
end

--- Get the list of tasks from the Taskfile
---@return table A list of tasks from the Taskfile, or an empty table if an error occurs
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

--- Get the last executed task
---@return string Name of the last executed task
M.get_last_task = function()
  return M._last_task
end

--- Execute a task from the Taskfile
---@param task string Name of the task to execute
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

  ui.close_all_windows()
  local buf, win = ui.create_terminal_window(M._options.windows.output)
  M._buf, M._win = buf, win

  run_task_in_terminal(task)
  M._last_task = task
  set_quit_key(buf, win)
end

--- Handles task selection from the UI
---@param item table Selected task item
M.on_choice = function(item)
  if not item or not item.name then
    vim.notify("Invalid task selection: no 'name' field", vim.log.levels.WARN)
    return
  end
  M.execute_task(item.name)
end

M.close_task_output_window = function()
  utils.cleanup_terminal(M._win, M._buf)
  M._win = nil
  M._buf = nil
end

--- Return the window configuration for the list
---@return ListWindowConfig
M.get_list_config = function()
  local list = vim.deepcopy(M._options.windows.list)
  list.layout = list.layout or M._options.layout or "horizontal"
  return list
end

return M
