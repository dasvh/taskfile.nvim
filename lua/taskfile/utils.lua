---@Class utils
local M = {}

M.calculate_dimensions = function(percent_width, percent_height)
  local width = math.floor(vim.o.columns * percent_width)
  local height = math.floor(vim.o.lines * percent_height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return width, height, row, col
end

M.window_layout = function(config)
  local width, height, row, col = M.calculate_dimensions(config.width or 0.8, config.height or 0.8)
  return width, height, row, col, config.border or "rounded"
end

M.cleanup_terminal = function(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

M.clean_dry_output = function(lines)
  local cleaned = {}
  for _, line in ipairs(lines) do
    local cleaned_line = line:gsub("^task:%s+%[.-%]%s*", "")
    table.insert(cleaned, cleaned_line)
  end
  return cleaned
end

M.highlight_line = function(buf, ns, line)
  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
    end_line = line + 1,
    hl_group = "Visual",
    hl_mode = "combine",
    hl_eol = true,
  })
end

M.scroll_to_bottom = function()
  vim.schedule(function()
    vim.cmd("normal! G")
  end)
end

M.open_floating_win = function(buf, opts, enter)
  return vim.api.nvim_open_win(
    buf,
    enter or false,
    vim.tbl_extend("force", {
      relative = "editor",
      style = "minimal",
      border = "single",
    }, opts or {})
  )
end

--- Validate numeric fields fall within a given range
---@param t table<string, number|nil>
---@param min number
---@param max number
M.validate_range = function(t, min, max)
  for name, value in pairs(t) do
    vim.validate({
      [name] = {
        value,
        function(v)
          return (v == nil) or ((type(v) == "number") and ((v >= min) and (v <= max)))
        end,
        string.format("number between %s and %s", min, max),
      },
    })
  end
end

--- Normalize layout configuration string to standard format
---@param layout string|nil Layout string to normalize
---@return string Normalized layout ("horizontal" or "vertical")
M.normalize_layout = function(layout)
  local layouts = {
    h = "horizontal",
    horiz = "horizontal",
    horizontal = "horizontal",
    v = "vertical",
    vert = "vertical",
    vertical = "vertical",
  }

  local input = type(layout) == "string" and layout:lower() or "horizontal"

  vim.validate({
    layout = {
      input,
      function(v)
        return layouts[v] ~= nil
      end,
      "must be one of: h, horizontal, horz, v, vertical, vert",
    },
  })

  return layouts[input]
end

--- Calculates the maximum rendered task line length (label + spacing + desc).
---@param tasks table
---@param label_width integer Width of the aligned task label
---@param gap integer Gap between label and description
---@return integer max_length
M.max_task_line_width = function(tasks, label_width, gap)
  local max = 0
  for _, task in ipairs(tasks) do
    local name = task.name or ""
    local desc = task.desc or ""

    local label = string.format("%-" .. label_width .. "s", name .. ":")
    local line = label .. string.rep(" ", gap) .. desc

    max = math.max(max, #line)
  end
  return max
end

--- Calculates the maximum length of task labels (e.g., "name:").
---@param tasks table
---@return integer max_label_length The length of the longest label
M.max_task_label_length = function(tasks)
  local max = 0
  for _, task in ipairs(tasks) do
    local label = (task.name or "") .. ":"
    max = math.max(max, #label)
  end
  return max
end

--- Format task lines with label + wrapped description
---@param name string
---@param desc string
---@param label_width integer
---@param max_width integer
---@param gap integer
---@return string[]
M.format_task_lines = function(name, desc, label_width, max_width, gap)
  local label = string.format("%-" .. label_width .. "s", name .. ":")
  local desc_indent = string.rep(" ", label_width + gap)
  local desc_gap = string.rep(" ", gap)
  local no_desc = "(no task desc)"

  -- wrap description words into lines that fit max_width
  local lines, current = {}, ""
  for word in desc:gmatch("%S+") do
    if #current + #word + 1 > max_width then
      table.insert(lines, current)
      current = word
    else
      current = current == "" and word or (current .. " " .. word)
    end
  end
  if current ~= "" then
    table.insert(lines, current)
  end

  local formatted = {}
  if #lines == 0 then
    table.insert(formatted, label .. desc_gap .. no_desc)
  else
    table.insert(formatted, label .. desc_gap .. lines[1])
    for i = 2, #lines do
      table.insert(formatted, desc_indent .. lines[i])
    end
  end

  return formatted
end

return M
