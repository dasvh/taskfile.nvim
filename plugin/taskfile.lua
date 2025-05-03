vim.api.nvim_create_user_command("Task", function(input)
  require("taskfile").execute_or_select(input.args ~= "" and input.args or nil)
end, {
  bang = true,
  desc = "Run tasks defined in a Taskfile",
  nargs = "?",
  complete = function(ArgLead)
    local tasks = require("taskfile.core").get_tasks()
    local matches = {}
    for _, task in ipairs(tasks) do
      if task.name:lower():match("^" .. ArgLead:lower()) then
        table.insert(matches, task.name)
      end
    end
    table.sort(matches)
    return matches
  end,
})

vim.api.nvim_create_user_command("TaskRerun", function()
  local task = require("taskfile").get_last_task()
  if not task then
    vim.notify("No task has been run yet.", vim.log.levels.WARN)
    return
  end
  require("taskfile").execute_task(task)
end, {
  desc = "Rerun last Task",
})
