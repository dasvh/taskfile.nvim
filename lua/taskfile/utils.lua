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
  local content = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)[1] or ""
  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
    end_col = #content,
    hl_group = "Visual",
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

return M
