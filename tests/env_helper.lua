local Path = require("plenary.path")

local M = {}

M.with_empty_dir = function()
  local env = {}

  before_each(function()
    env.temp_dir = vim.fn.tempname()
    vim.fn.mkdir(env.temp_dir, "p")

    env.original_dir = vim.loop.cwd()
    vim.cmd("cd " .. env.temp_dir)
  end)

  after_each(function()
    vim.cmd("cd " .. env.original_dir)
    vim.fn.delete(env.temp_dir, "rf")
  end)

  return env
end

M.with_taskfile = function(taskfile_content)
  local env = {}

  taskfile_content = taskfile_content
    or [[
version: '3'

tasks:
  first:
    desc: first task desc
    cmds:
      - echo "first task with desc"
  second:
    cmds:
      - echo "second task without desc"
]]

  before_each(function()
    env.temp_dir = vim.fn.tempname()
    vim.fn.mkdir(env.temp_dir, "p")

    env.taskfile_path = Path:new(env.temp_dir, "Taskfile.yml")
    env.taskfile_path:write(taskfile_content, "w")

    env.original_dir = vim.loop.cwd()
    vim.cmd("cd " .. env.temp_dir)
  end)

  after_each(function()
    vim.cmd("cd " .. env.original_dir)
    if env.taskfile_path and vim.fn.filereadable(env.taskfile_path.filename) == 1 then
      env.taskfile_path:rm()
    end
    vim.fn.delete(env.temp_dir, "rf")
  end)

  return env
end

return M
