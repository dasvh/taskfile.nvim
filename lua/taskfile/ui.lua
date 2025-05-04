--@Class ui
local M = {}
local utils = require("taskfile.utils")

M._list_win = nil
M._preview_win = nil
M._list_buf = nil
M._preview_buf = nil
local preview_ns = vim.api.nvim_create_namespace("TaskPreview")

---@type fun(task: string)
local execute_task = function(_) end
---@type fun()
local close_task_output = function() end

--- Wrapper function for task execution
---@param fn function Function to execute a task
function M.set_execute_task(fn)
  execute_task = fn
end

--- Wrapper function for closing the task output window
---@param fn function Function to close the task output window
function M.set_close_task_output(fn)
  close_task_output = fn
end

local function update_preview_buf(tasks, current_line)
  local task = tasks[current_line]
  if not task then
    return
  end

  local output = vim.fn.system({ "task", task.name, "--dry" })
  local cleaned_output = utils.clean_dry_output(vim.split(output, "\n"))
  vim.api.nvim_buf_set_lines(M._preview_buf, 0, -1, false, cleaned_output)
end

local function close_task_list_and_preview()
  utils.cleanup_terminal(M._list_win, M._list_buf)
  utils.cleanup_terminal(M._preview_win, M._preview_buf)
  M._list_win = nil
  M._list_buf = nil
  M._preview_win = nil
  M._preview_buf = nil
end

--- Close all open taskfile.nvim related windows
M.close_all_windows = function()
  close_task_output()
  close_task_list_and_preview()
end

--- Creates a floating terminal window for task execution.
---@param config WindowConfig
---@return number, number Buffer and window handles
M.create_terminal_window = function(config)
  local width, height, row, col, border = utils.float_size(config)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = utils.open_floating_win(buf, {
    row = row,
    col = col,
    width = width,
    height = height,
    border = border,
  }, true)

  vim.api.nvim_set_current_buf(buf)
  M._task_buf = buf
  M._task_win = win
  return buf, win
end

--- Opens a floating window with a list of tasks and a preview of the selected task.
---@param tasks table List of tasks
---@param config WindowConfig The window config for the preview
M.select_task_with_preview = function(tasks, config)
  if #tasks == 0 then
    vim.notify("No tasks available", vim.log.levels.WARN)
    return
  end

  close_task_output()
  close_task_list_and_preview()

  local total_width, total_height, row, col = utils.calculate_dimensions(config.width, config.height)
  local list_width = math.floor(total_width * 0.3)
  local preview_width = total_width - list_width - 2

  M._list_buf = vim.api.nvim_create_buf(false, true)
  M._preview_buf = vim.api.nvim_create_buf(false, true)

  local lines = vim.tbl_map(function(task)
    return string.format("%-10s %s", task.name, task.desc or "")
  end, tasks)
  vim.api.nvim_buf_set_lines(M._list_buf, 0, -1, false, lines)

  M._list_win = utils.open_floating_win(M._list_buf, {
    row = row,
    col = col,
    width = list_width,
    height = total_height,
    title = "Tasks",
    title_pos = "center",
    border = config.border,
  }, true)

  M._preview_win = utils.open_floating_win(M._preview_buf, {
    row = row,
    col = col + list_width + 2,
    width = preview_width,
    height = total_height,
    title = "Preview",
    title_pos = "center",
    border = config.border,
  }, false)

  local current_line = 1
  utils.highlight_line(M._list_buf, preview_ns, current_line - 1)
  update_preview_buf(tasks, current_line)

  vim.keymap.set("n", "<CR>", function()
    local task = tasks[current_line]
    if task then
      execute_task(task.name)
    end
  end, { buffer = M._list_buf })

  vim.keymap.set("n", "q", close_task_list_and_preview, { buffer = M._list_buf })
  vim.keymap.set("n", "<Esc>", close_task_list_and_preview, { buffer = M._list_buf })

  vim.keymap.set("n", "j", function()
    if current_line < #tasks then
      vim.api.nvim_buf_clear_namespace(M._list_buf, preview_ns, 0, -1)
      current_line = current_line + 1
      utils.highlight_line(M._list_buf, preview_ns, current_line - 1)
      update_preview_buf(tasks, current_line)
      vim.api.nvim_win_set_cursor(M._list_win, { current_line, 0 })
    end
  end, { buffer = M._list_buf })

  vim.keymap.set("n", "k", function()
    if current_line > 1 then
      vim.api.nvim_buf_clear_namespace(M._list_buf, preview_ns, 0, -1)
      current_line = current_line - 1
      utils.highlight_line(M._list_buf, preview_ns, current_line - 1)
      update_preview_buf(tasks, current_line)
      vim.api.nvim_win_set_cursor(M._list_win, { current_line, 0 })
    end
  end, { buffer = M._list_buf })
end

return M
