local core = require("taskfile.core")
local ui = require("taskfile.ui")

---@class Taskfile
local M = {}

--- Sets up the Taskfile plugin with optional configuration
M.setup = core.setup

--- Executes a task in a floating terminal
M.execute_task = core.execute_task

--- Returns the last task that was executed
M.get_last_task = core.get_last_task

--- Returns the window configuration for the list
M.get_list_config = core.get_list_config

--- Close all windows opened by taskfile.nvim
M.close_all_windows = ui.close_all_windows

--- Opens task selection window with side-by-side preview
M.select_task_with_preview = ui.select_task_with_preview

--- Executes a task by name if provided or opens task selection if no task specified
---@param task? string Name of the task to execute (optional)
M.execute_or_select = function(task)
  if task then
    core.execute_task(task)
  else
    local tasks = core.get_tasks()
    if #tasks == 0 then
      vim.notify("No tasks available", vim.log.levels.WARN)
      return
    end

    local opts = core._options or {}

    if opts.picker == "telescope" then
      -- Try to load telescope extension
      local ok, telescope_ext = pcall(require, "taskfile.telescope")
      if ok then
        telescope_ext.pick_task(tasks, core.execute_task, opts)
        return
      else
        vim.notify("Telescope not installed. Falling back to native UI.", vim.log.levels.WARN)
      end
    end

    local preview_win_cfg = core.get_list_config()
    ui.select_task_with_preview(tasks, preview_win_cfg)
  end
end

return M
