local Path = require("plenary.path")
local core = require("taskfile.core")

describe("without taskfile", function()
  it("should return empty table", function()
    local tasks = core.get_tasks()

    assert.are.same({}, tasks)
  end)

  it("should not update last_task", function()
    core.execute_task("hello")
    assert.is_nil(core.get_last_task())
  end)
end)

describe("with taskfile", function()
  if vim.fn.executable("task") ~= 1 then
    pending("Skipping test: 'task' executable not found")
    return
  end

  local temp_dir, taskfile_path, original_dir

  before_each(function()
    temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    taskfile_path = Path:new(temp_dir, "Taskfile.yml")
    taskfile_path:write([[
version: '3'

tasks:
  first:
    desc: first task desc
    cmds:
      - echo "first task with desc"
  second:
    cmds:
      - echo "second task without desc"
]], "w")

    original_dir = vim.loop.cwd()
    vim.cmd("cd " .. temp_dir)
  end)

  after_each(function()
    vim.cmd("cd " .. original_dir)
    taskfile_path:rm()
    vim.fn.delete(temp_dir, "rf")
  end)

  it("should parse task name and desc", function()
    local tasks = core.get_tasks()
    assert.are.same("first", tasks[1].name)
    assert.are.same("first task desc", tasks[1].desc)
  end)

  it("should parse task with no desc", function()
    local tasks = core.get_tasks()
    assert.are.same("second", tasks[2].name)
    assert.are.same("", tasks[2].desc)
  end)

  it("get_last_task is nil", function()
    assert.is_nil(core.get_last_task())
  end)

  it("should execute task and set last_task", function()
    core.execute_task("first")
    core.execute_task("second")

    assert.are.same("second", core.get_last_task())
  end)
end)
