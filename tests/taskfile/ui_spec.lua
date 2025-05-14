local Path = require("plenary.path")
local core = require("taskfile.core")
local ui = require("taskfile.ui")

describe("ui integration", function()
  if vim.fn.executable("task") ~= 1 then
    pending("Skipping tests: 'task' executable not found")
    return
  end

  local tasks, temp_dir, taskfile_path, original_dir

  before_each(function()
    temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    taskfile_path = Path:new(temp_dir, "Taskfile.yml")
    taskfile_path:write(
      [[
version: '3'

tasks:
  first:
    desc: first task desc
    cmds:
      - echo "first task with desc"
  second:
    desc: second task desc
    cmds:
      - echo "second task without desc"
]],
      "w"
    )

    original_dir = vim.loop.cwd()
    vim.cmd("cd " .. temp_dir)

    tasks = core.get_tasks()
    assert.is_true(#tasks > 0, "Expected tasks to be available for testing")
    ui.close_all_windows()
  end)

  after_each(function()
    vim.cmd("cd " .. original_dir)
    taskfile_path:rm()
    vim.fn.delete(temp_dir, "rf")
    ui.close_all_windows()
  end)

  it("closes previous list/preview windows when reopening :Task", function()
    ui.select_task_with_preview(tasks, {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    })
    local first_list_win = ui._list_win
    assert.is_true(vim.api.nvim_win_is_valid(first_list_win))

    ui.select_task_with_preview(tasks, {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    })

    assert.is_false(vim.api.nvim_win_is_valid(first_list_win))
    assert.is_true(vim.api.nvim_win_is_valid(ui._list_win))
  end)

  it("allows :TaskRerun even if preview windows are open", function()
    local task_name = tasks[1].name
    core.execute_task(task_name)

    ui.select_task_with_preview(tasks, {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    })

    core.execute_task(core.get_last_task())

    assert.are.same(task_name, core.get_last_task())
  end)

  it("highlights the correct task on open", function()
    ui.select_task_with_preview(tasks, {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    })

    local cursor = vim.api.nvim_win_get_cursor(ui._list_win)
    assert.are.same(1, cursor[1], "Expected cursor to be on first task")

    local ns_marks =
      vim.api.nvim_buf_get_extmarks(ui._list_buf, vim.api.nvim_create_namespace("TaskPreview"), 0, -1, {})
    assert.is_true(#ns_marks > 0, "Expected a highlight on the first task")
  end)

  it("cleans up buffers after closing task UI", function()
    ui.select_task_with_preview(tasks, {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    })

    local list_buf = ui._list_buf
    local preview_buf = ui._preview_buf
    ui.close_all_windows()

    assert.is_false(vim.api.nvim_buf_is_valid(list_buf), "List buffer should be cleaned up")
    assert.is_false(vim.api.nvim_buf_is_valid(preview_buf), "Preview buffer should be cleaned up")
  end)

  it("safely handles nil input", function()
    assert.has_no.errors(function()
      core.on_choice(nil)
    end)
  end)

  it("safely handles item without name", function()
    assert.has_no.errors(function()
      core.on_choice({})
    end)
  end)

  it("does not crash on nonexistent task", function()
    assert.has_no.errors(function()
      core.execute_task("does_not_exist")
    end)
  end)

  it("handles empty task list gracefully", function()
    assert.has_no.errors(function()
      ui.select_task_with_preview({})
    end)
  end)

  it("respects width_ratio when calculating window sizes", function()
    local ratio = 0.5
    local available_width = 1.0
    local total_width = math.floor(vim.o.columns * available_width)
    local expected_list_width = math.floor(total_width * ratio)

    ui.select_task_with_preview(tasks, {
      width = available_width,
      height = 0.4,
      border = "rounded",
      width_ratio = ratio,
    })

    local list_win_config = vim.api.nvim_win_get_config(ui._list_win)
    assert.are.same(expected_list_width, list_win_config.width)
  end)
end)
