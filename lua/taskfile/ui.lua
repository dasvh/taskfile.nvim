---@Class ui
local M = {}
local utils = require("taskfile.utils")

local execute_task = function() end
function M.set_execute_task(fn)
  execute_task = fn
end

local preview_ns = vim.api.nvim_create_namespace("TaskPreview")

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
  return buf, win
end

-- TODO: fix undefined global
M.open_window = function()
  if #tasks == 0 then
    vim.notify("No tasks available", vim.log.levels.WARN)
    return
  end
  vim.ui.select(tasks, {
    prompt = "Task:",
    format_item = function(task)
      return string.format("%-20s %s", task.name, task.desc or "")
    end,
  }, M.on_choice)
end

M.select_task_with_preview = function(tasks)
  if #tasks == 0 then
    vim.notify("No tasks available", vim.log.levels.WARN)
    return
  end

  local total_width, total_height, row, col = utils.calculate_dimensions(0.8, 0.6)
  local list_width = math.floor(total_width * 0.4)
  local preview_width = total_width - list_width - 2
  local list_buf = vim.api.nvim_create_buf(false, true)
  local preview_buf = vim.api.nvim_create_buf(false, true)

  local lines = {}
  for _, task in ipairs(tasks) do
    table.insert(lines, string.format("%-20s %s", task.name, task.desc or ""))
  end
  vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)

  local list_win = utils.open_floating_win(list_buf, {
    row = row,
    col = col,
    width = list_width,
    height = total_height,
    title = "Tasks",
    title_pos = "center",
  }, true)

  local preview_win = utils.open_floating_win(preview_buf, {
    row = row,
    col = col + list_width + 2,
    width = preview_width,
    height = total_height,
    title = "Preview",
    title_pos = "center",
  }, false)

  local current_line = 1
  local line = current_line - 1
  utils.highlight_line(list_buf, preview_ns, line)

  local function update_preview(index)
    local task = tasks[index]
    if not task then
      return
    end
    local output = vim.fn.system({ "task", task.name, "--dry" })
    local cleaned_output = utils.clean_dry_output(vim.split(output, "\n"))
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, cleaned_output)
  end

  update_preview(current_line)

  vim.keymap.set("n", "<CR>", function()
    local task = tasks[current_line]
    if task then
      vim.api.nvim_win_close(list_win, true)
      vim.api.nvim_win_close(preview_win, true)
      execute_task(task.name)
    end
  end, { buffer = list_buf })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(list_win, true)
    vim.api.nvim_win_close(preview_win, true)
  end, { buffer = list_buf })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(list_win, true)
    vim.api.nvim_win_close(preview_win, true)
  end, { buffer = list_buf })

  vim.keymap.set("n", "j", function()
    if current_line < #tasks then
      vim.api.nvim_buf_clear_namespace(list_buf, preview_ns, 0, -1)
      current_line = current_line + 1
      utils.highlight_line(list_buf, preview_ns, current_line - 1)
      update_preview(current_line)
      vim.api.nvim_win_set_cursor(list_win, { current_line, 0 })
    end
  end, { buffer = list_buf })

  vim.keymap.set("n", "k", function()
    if current_line > 1 then
      vim.api.nvim_buf_clear_namespace(list_buf, preview_ns, 0, -1)
      current_line = current_line - 1
      utils.highlight_line(list_buf, preview_ns, current_line - 1)
      update_preview(current_line)
      vim.api.nvim_win_set_cursor(list_win, { current_line, 0 })
    end
  end, { buffer = list_buf })
end

return M

