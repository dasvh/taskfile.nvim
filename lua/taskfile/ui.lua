--@Class ui
local M = {}
local utils = require("taskfile.utils")
local C = utils.const

-- cache constants
local WINDOW_GAP = C.WINDOW_GAP
local TASK_NAME_DESC_GAP = C.TASK_NAME_DESC_GAP
local TASK_LIST_PADDING = C.TASK_LIST_PADDING
local MIN_PREVIEW_WIDTH = C.MIN_PREVIEW_WIDTH
local MIN_STACK_HEIGHT = C.MIN_STACK_HEIGHT
local MIN_WRAP_WIDTH = C.MIN_WRAP_WIDTH

M.const = C

M._list_win = nil
M._preview_win = nil
M._list_buf = nil
M._preview_buf = nil
local preview_ns = vim.api.nvim_create_namespace("TaskPreview")
local current_task_idx = 1

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
  current_task_idx = 1
end

local function highlight_task(task_idx, task_line_ranges)
  vim.api.nvim_buf_clear_namespace(M._list_buf, preview_ns, 0, -1)

  local range = task_line_ranges[task_idx]
  if not range then
    return
  end

  for line = range[1], range[2] do
    utils.highlight_line(M._list_buf, preview_ns, line - 1)
  end

  vim.api.nvim_win_set_cursor(M._list_win, { range[1], 0 })
  current_task_idx = task_idx
end

local function is_dynamic_ratio(ratio)
  return ratio == nil or ratio == 0
end

local function calculate_list_width(tasks, ratio, total_width, label_width)
  if is_dynamic_ratio(ratio) then
    local max_task_line_width = utils.max_task_line_width(tasks, label_width, TASK_NAME_DESC_GAP)
    local available_list_space = total_width - WINDOW_GAP - MIN_PREVIEW_WIDTH
    return math.min(max_task_line_width + TASK_LIST_PADDING, available_list_space)
  else
    local wanted = math.floor(total_width * ratio)
    local max_ok = total_width - WINDOW_GAP - MIN_PREVIEW_WIDTH
    return math.min(wanted, max_ok)
  end
end

local function calculate_list_height(tasks, ratio, total_height, list_window_width, label_width)
  local available_list_space = total_height - WINDOW_GAP - MIN_STACK_HEIGHT
  local wrap_width = math.max(MIN_WRAP_WIDTH, list_window_width - label_width - TASK_NAME_DESC_GAP)

  local list_h
  if is_dynamic_ratio(ratio) then
    local needed = 0
    for _, t in ipairs(tasks) do
      local lines = utils.format_task_lines(t.name or "", t.desc or "", label_width, wrap_width, TASK_NAME_DESC_GAP)
      needed = needed + #lines
    end
    list_h = math.max(MIN_STACK_HEIGHT, math.min(needed, available_list_space))
  else
    local wanted = math.floor(total_height * ratio)
    list_h = math.max(MIN_STACK_HEIGHT, math.min(wanted, available_list_space))
  end

  return list_h, wrap_width
end

local function compute_horizontal_view(tasks, config, width, height, row, col, label_width)
  local list_w = calculate_list_width(tasks, config.width_ratio, width, label_width)
  local preview_w = width - list_w - WINDOW_GAP
  local wrap_width = math.max(MIN_WRAP_WIDTH, list_w - label_width - TASK_NAME_DESC_GAP)

  local view = {
    list = { row = row, col = col, width = list_w, height = height },
    preview = { row = row, col = col + list_w + WINDOW_GAP, width = preview_w, height = height },
  }
  return view, wrap_width
end

local function compute_vertical_view(tasks, config, width, height, row, col, label_width)
  local list_h, wrap_width = calculate_list_height(tasks, config.height_ratio, height, width, label_width)
  local preview_h = height - list_h - WINDOW_GAP
  -- shrink list to favor preview
  if preview_h < MIN_STACK_HEIGHT then
    preview_h = MIN_STACK_HEIGHT
    list_h = height - WINDOW_GAP - preview_h
    if list_h < 1 then
      list_h = 1
      preview_h = math.max(1, height - WINDOW_GAP - list_h)
    end
  end

  local view = {
    list = { row = row, col = col, width = width, height = list_h },
    preview = { row = row + list_h + WINDOW_GAP, col = col, width = width, height = preview_h },
  }
  return view, wrap_width
end

local function open_windows(view, config)
  M._list_win = utils.open_floating_win(M._list_buf, {
    row = view.list.row,
    col = view.list.col,
    width = view.list.width,
    height = view.list.height,
    title = "Tasks",
    title_pos = "center",
    border = config.border,
  }, true)

  M._preview_win = utils.open_floating_win(M._preview_buf, {
    row = view.preview.row,
    col = view.preview.col,
    width = view.preview.width,
    height = view.preview.height,
    title = "Preview",
    title_pos = "center",
    border = config.border,
  }, false)
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
  local width, height, row, col, border = utils.window_layout(config)
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
---@param config ListWindowConfig Window Configuration for the list
M.select_task_with_preview = function(tasks, config)
  if #tasks == 0 then
    vim.notify("No tasks available", vim.log.levels.WARN)
    return
  end

  close_task_output()
  close_task_list_and_preview()

  local total_width, total_height, row, col = utils.calculate_dimensions(config.width, config.height)
  local label_width = utils.max_task_label_length(tasks)

  M._list_buf = vim.api.nvim_create_buf(false, true)
  M._preview_buf = vim.api.nvim_create_buf(false, true)

  local view, wrap_width
  if config.layout == "vertical" then
    view, wrap_width = compute_vertical_view(tasks, config, total_width, total_height, row, col, label_width)
  else
    view, wrap_width = compute_horizontal_view(tasks, config, total_width, total_height, row, col, label_width)
  end

  open_windows(view, config)

  local task_line_ranges, lines, current_line = {}, {}, 1
  for task_idx, task in ipairs(tasks) do
    local formatted =
      utils.format_task_lines(task.name or "", task.desc or "", label_width, wrap_width, TASK_NAME_DESC_GAP)
    local start_line, end_line = current_line, current_line + #formatted - 1
    task_line_ranges[task_idx] = { start_line, end_line }
    vim.list_extend(lines, formatted)
    current_line = end_line + 1
  end
  vim.api.nvim_buf_set_lines(M._list_buf, 0, -1, false, lines)

  vim.keymap.set("n", "<CR>", function()
    local task = tasks[current_task_idx]
    if task then
      execute_task(task.name)
    end
  end, { buffer = M._list_buf })

  local function jump_to_task(direction)
    local next_idx = current_task_idx + direction
    if next_idx >= 1 and next_idx <= #tasks then
      highlight_task(next_idx, task_line_ranges)
      update_preview_buf(tasks, next_idx)
    end
  end

  for _, buf in ipairs({ M._list_buf, M._preview_buf }) do
    for _, key in ipairs({ "q", "<Esc>" }) do
      vim.keymap.set("n", key, close_task_list_and_preview, { buffer = buf })
    end
  end

  vim.keymap.set("n", "j", function()
    jump_to_task(1)
  end, { buffer = M._list_buf })
  vim.keymap.set("n", "k", function()
    jump_to_task(-1)
  end, { buffer = M._list_buf })

  highlight_task(current_task_idx, task_line_ranges)
  update_preview_buf(tasks, current_task_idx)
end

return M
