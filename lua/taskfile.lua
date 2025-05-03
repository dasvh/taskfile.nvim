local core = require("taskfile.core")
local ui = require("taskfile.ui")

---@class Taskfile
local M = {}

M.setup = core.setup
--- Execute a task in a floating terminal
--@param task string: name of the task to execute
M.execute_task = core.execute_task
--- Return the last task executed
-- @return string|nil
M.get_last_task = core.get_last_task
--- Opens the basic task selection window
-- @param tasks table: list of task definitions
M.open_window = ui.open_window
--- Opens task selection window with preview
-- @param tasks table: list of task definitions
M.select_task_with_preview = ui.select_task_with_preview
--- Execute a task by name or open selection if none provided
-- @param task string|nil
M.execute_or_select = function(task)
  if task then
    core.execute_task(task)
  else
    local tasks = core.get_tasks()
    if #tasks == 0 then
      vim.notify("No tasks available", vim.log.levels.WARN)
      return
    end
    ui.select_task_with_preview(tasks)
  end
end

return M
