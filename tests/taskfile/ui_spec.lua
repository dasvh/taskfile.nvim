local core = require("taskfile.core")
local ui = require("taskfile.ui")
local helpers = require("tests.env_helper")

describe("ui integration", function()
  if vim.fn.executable("task") ~= 1 then
    pending("Skipping tests: 'task' executable not found")
    return
  end

  helpers.with_taskfile()
  local tasks

  local function win_cfg(win, name)
    assert.is_not_nil(win, (name or "window") .. " handle is nil")
    assert.is_number(win, (name or "window") .. " handle must be a number")
    assert.is_true(vim.api.nvim_win_is_valid(win), (name or "window") .. " is not a valid window")
    return vim.api.nvim_win_get_config(win)
  end

  before_each(function()
    tasks = core.get_tasks()
    assert.is_true(#tasks > 0, "Expected tasks to be available for testing")
    ui.close_all_windows()
  end)

  it("closes previous list/preview windows on new preview", function()
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

  it("allows get_last_task even if preview windows are open", function()
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

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")
    assert.are.equal(total_width, list_cfg.width + ui.const.WINDOW_GAP + preview_cfg.width)
    assert.are.same(expected_list_width, list_cfg.width)
  end)

  it("uses dynamic sizing when width_ratio is nil", function()
    local utils = require("taskfile.utils")
    local long_task = {
      name = string.rep("N", 30),
      desc = string.rep("D", 80),
      cmds = { "echo hi" },
    }
    table.insert(tasks, long_task)
    local cfg_width = 0.9
    local total_width = math.floor(vim.o.columns * cfg_width)

    ui.select_task_with_preview(tasks, {
      width = cfg_width,
      height = 0.5,
      border = "rounded",
      -- width_ratio = nil (dynamic)
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")
    assert.are.equal(total_width, list_cfg.width + ui.const.WINDOW_GAP + preview_cfg.width)
    assert.is_true(preview_cfg.width >= ui.const.MIN_PREVIEW_WIDTH)

    -- desc wrap width should never be below ui.const.MIN_WRAP_WIDTH
    local label_width = utils.max_task_label_length(tasks)
    local wrap_width = list_cfg.width - label_width - ui.const.TASK_NAME_DESC_GAP
    assert.is_true(wrap_width >= ui.const.MIN_WRAP_WIDTH)
  end)

  it("uses explicit ratio when width_ratio is set", function()
    local ratio = 0.4
    local cfg_width = 1.0
    local total_width = math.floor(vim.o.columns * cfg_width)
    local expected_list_width = math.floor(total_width * ratio)

    ui.select_task_with_preview(tasks, {
      width = cfg_width,
      height = 0.5,
      width_ratio = ratio,
      border = "rounded",
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")
    assert.are.equal(total_width, list_cfg.width + ui.const.WINDOW_GAP + preview_cfg.width)
    assert.are.same(expected_list_width, list_cfg.width)
  end)

  it("caps dynamic list width and prevents overflow", function()
    local very_long = {
      name = string.rep("A", 60),
      desc = string.rep("Z", 200),
      cmds = { "echo y" },
    }
    table.insert(tasks, very_long)
    local cfg_width = 0.9
    local total_width = math.floor(vim.o.columns * cfg_width)

    ui.select_task_with_preview(tasks, {
      width = cfg_width,
      height = 0.5,
      border = "rounded",
      -- width_ratio = nil
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")
    assert.are.equal(total_width, list_cfg.width + ui.const.WINDOW_GAP + preview_cfg.width)
  end)

  it("highlights all lines of a wrapped task", function()
    local long_task = {
      name = "wraptest",
      desc = string.rep("word ", 30), -- long enough to wrap
      cmds = { "echo hello" },
    }
    table.insert(tasks, 1, long_task) -- ensure it's selected on open

    ui.select_task_with_preview(tasks, {
      width = 0.5,
      height = 0.5,
      border = "rounded",
    })

    local marks = vim.api.nvim_buf_get_extmarks(
      ui._list_buf,
      vim.api.nvim_create_namespace("TaskPreview"),
      0,
      -1,
      { details = false }
    )

    assert.is_true(#marks > 1, "Expected multiple lines to be highlighted for wrapped task description")

    local cursor = vim.api.nvim_win_get_cursor(ui._list_win)
    assert.are.same(1, cursor[1], "Cursor should be on the first line of the wrapped task")

    local lines = vim.api.nvim_buf_get_lines(ui._list_buf, 0, -1, false)
    local highlight_lines = {}
    for _, mark in ipairs(marks) do
      highlight_lines[mark[2] + 1] = true
    end

    local count = 0
    for i = 1, #lines do
      if highlight_lines[i] then
        count = count + 1
      end
    end
    assert.are.same(count, #marks, "All highlight marks should align with contiguous wrapped lines")
  end)

  it("horizontal layout by default", function()
    ui.select_task_with_preview(tasks, { width = 0.9, height = 0.5, border = "rounded" })
    local lwindow = win_cfg(ui._list_win, "list")
    local pwindow = win_cfg(ui._preview_win, "preview")

    assert.are.equal(lwindow.row, pwindow.row)
    assert.is_true(lwindow.col < pwindow.col)
    assert.are.equal(math.floor(vim.o.columns * 0.9), lwindow.width + ui.const.WINDOW_GAP + pwindow.width)
  end)

  it("vertical layout when configured", function()
    ui.select_task_with_preview(tasks, {
      width = 0.9,
      height = 0.6,
      border = "rounded",
      layout = "vertical",
      height_ratio = 0.6,
    })

    local lwindow = win_cfg(ui._list_win, "list")
    local pwindow = win_cfg(ui._preview_win, "preview")

    assert.are.equal(lwindow.col, pwindow.col)
    assert.is_true(lwindow.row < pwindow.row)
    assert.is_true(lwindow.height >= ui.const.MIN_STACK_HEIGHT)
    assert.is_true(pwindow.height >= ui.const.MIN_STACK_HEIGHT)
    assert.are.equal(math.floor(vim.o.lines * 0.6), lwindow.height + ui.const.WINDOW_GAP + pwindow.height)
  end)

  it("reopens UI with flipped layout", function()
    local orig = ui.select_task_with_preview

    local calls = {}
    -- stub only to record the layout value
    ui.select_task_with_preview = function(_, cfg)
      table.insert(calls, cfg.layout)
    end

    -- initial call uses default config from core
    ui.select_task_with_preview({}, require("taskfile.core").get_list_config())
    assert.equals("horizontal", calls[#calls])

    -- flip layout and "reopen"
    local opts = require("taskfile.core")._options
    opts.layout = (opts.layout == "horizontal") and "vertical" or "horizontal"

    local tasks = require("taskfile.core").get_tasks()
    local cfg = require("taskfile.core").get_list_config()
    ui.select_task_with_preview(tasks, cfg)

    assert.equals("vertical", calls[#calls])

    -- restore original function
    ui.select_task_with_preview = orig
  end)

  it("layout toggle persists within session but resets next session", function()
    core.setup({ layout = "horizontal" })
    ui.select_task_with_preview(tasks, { width = 0.8, height = 0.4, border = "rounded" })
    local l1, p1 = win_cfg(ui._list_win, "list"), win_cfg(ui._preview_win, "preview")
    assert.are.equal(l1.row, p1.row)
    assert.is_true(l1.col < p1.col)

    -- switch to vertical in same session
    core._options.layout = "vertical"
    ui.select_task_with_preview(tasks, core.get_list_config())
    local l2, p2 = win_cfg(ui._list_win, "list"), win_cfg(ui._preview_win, "preview")
    assert.are.equal(l2.col, p2.col)
    assert.is_true(l2.row < p2.row)

    -- "new session": reset options to defaults
    ui.close_all_windows()
    core._options = nil
    core.setup({})

    -- verify default layout
    local cfg = core.get_list_config()
    assert.are.equal("horizontal", cfg.layout)

    -- and UI opens horizontally again
    ui.select_task_with_preview(core.get_tasks(), cfg)
    local l3, p3 = win_cfg(ui._list_win, "list"), win_cfg(ui._preview_win, "preview")
    assert.are.equal(l3.row, p3.row)
    assert.is_true(l3.col < p3.col)
  end)

  it("respects height_ratio when calculating window sizes (vertical)", function()
    local ratio = 0.5
    local available_height = 1.0
    local total_height = math.floor(vim.o.lines * available_height)
    local expected_list_height = math.floor(total_height * ratio)

    ui.select_task_with_preview(tasks, {
      width = 1,
      height = available_height,
      border = "rounded",
      height_ratio = ratio,
      layout = "vertical",
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")

    -- clamp if preview would be starved
    if (total_height - expected_list_height - ui.const.WINDOW_GAP) < ui.const.MIN_STACK_HEIGHT then
      expected_list_height = total_height - ui.const.WINDOW_GAP - ui.const.MIN_STACK_HEIGHT
    end

    assert.are.equal(expected_list_height, list_cfg.height)
    assert.are.equal(total_height, list_cfg.height + ui.const.WINDOW_GAP + preview_cfg.height)
  end)

  it("uses dynamic sizing when height_ratio is nil (vertical)", function()
    local utils = require("taskfile.utils")
    local long_task = { name = string.rep("N", 30), desc = string.rep("D", 80), cmds = { "echo hi" } }
    table.insert(tasks, long_task)

    local cfg_width, cfg_height = 0.8, 0.5
    local total_height = math.floor(vim.o.lines * cfg_height)
    local total_width = math.floor(vim.o.columns * cfg_width)

    ui.select_task_with_preview(tasks, {
      width = cfg_width,
      height = cfg_height,
      border = "rounded",
      layout = "vertical",
      -- height_ratio = nil  -- dynamic
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")

    -- dynamic vertical: list height fits rendered lines (post-wrap), clamped by available space
    local label_width = utils.max_task_label_length(tasks)
    local wrap_width = math.max(ui.const.MIN_WRAP_WIDTH, total_width - label_width - ui.const.TASK_NAME_DESC_GAP)

    local needed = 0
    for _, t in ipairs(tasks) do
      needed = needed
        + #utils.format_task_lines(t.name or "", t.desc or "", label_width, wrap_width, ui.const.TASK_NAME_DESC_GAP)
    end
    local available = total_height - ui.const.WINDOW_GAP - ui.const.MIN_STACK_HEIGHT
    local expected_list_height = math.max(ui.const.MIN_STACK_HEIGHT, math.min(needed, available))

    assert.are.equal(expected_list_height, list_cfg.height)
    assert.is_true(preview_cfg.height >= ui.const.MIN_STACK_HEIGHT)
    assert.are.equal(total_height, list_cfg.height + ui.const.WINDOW_GAP + preview_cfg.height)
  end)

  it("caps fixed height_ratio to keep preview min height (vertical)", function()
    ui.select_task_with_preview({ { name = "a", desc = "b", cmds = { "true" } } }, {
      width = 0.7,
      height = 0.3,
      border = "rounded",
      layout = "vertical",
      height_ratio = 0.98, -- try to starve preview
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")

    local total_height = math.floor(vim.o.lines * 0.3)
    local expected_list_h = total_height - ui.const.WINDOW_GAP - ui.const.MIN_STACK_HEIGHT
    assert.are.equal(expected_list_h, list_cfg.height)
    assert.are.equal(ui.const.MIN_STACK_HEIGHT, preview_cfg.height)
    assert.are.equal(total_height, list_cfg.height + ui.const.WINDOW_GAP + preview_cfg.height)
  end)

  it("vertical: wrap width used for rendering is at least ui.const.MIN_WRAP_WIDTH", function()
    ui.select_task_with_preview({ { name = "x", desc = "y", cmds = { "true" } } }, {
      width = 0.2,
      height = 0.5,
      border = "rounded",
      layout = "vertical",
      height_ratio = 0.5,
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local utils = require("taskfile.utils")
    local label_width = utils.max_task_label_length({ { name = "x" } })
    local wrap_width = list_cfg.width - label_width - ui.const.TASK_NAME_DESC_GAP
    assert.is_true(wrap_width >= ui.const.MIN_WRAP_WIDTH, "wrap width should be at least ui.const.MIN_WRAP_WIDTH")
  end)

  it("vertical: tiny container still opens two panes without overflow", function()
    local lines = vim.o.lines
    local target_height = math.max(2, ui.const.WINDOW_GAP + 1)
    local cfg_height = (target_height + 0.01) / lines

    ui.select_task_with_preview({ { name = "a", desc = "b", cmds = { "true" } } }, {
      width = 0.4,
      height = cfg_height,
      border = "rounded",
      layout = "vertical",
      height_ratio = 0.9,
    })

    local list_cfg = win_cfg(ui._list_win, "list")
    local preview_cfg = win_cfg(ui._preview_win, "preview")

    assert.are.equal(list_cfg.col, preview_cfg.col)
    assert.are.equal(list_cfg.row + list_cfg.height + ui.const.WINDOW_GAP, preview_cfg.row)
    assert.is_true(list_cfg.height >= 1)
    assert.is_true(preview_cfg.height >= 1)
  end)

  it("vertical: small but feasible container partitions exactly and keeps preview >= min", function()
    local lines = vim.o.lines
    local feasible = ui.const.WINDOW_GAP + 2 * ui.const.MIN_STACK_HEIGHT

    -- choose total_h >= feasible (+ a little) to guarantee both mins fit
    local target_height = feasible + 1
    local cfg_height = (target_height + 0.01) / lines
    ui.select_task_with_preview({ { name = "a", desc = "b", cmds = { "true" } } }, {
      width = 0.4,
      height = cfg_height,
      border = "rounded",
      layout = "vertical",
      height_ratio = 0.9, -- tries to starve preview
    })

    local list_cfg, preview_cfg = win_cfg(ui._list_win), win_cfg(ui._preview_win)
    local total_height = math.floor(lines * cfg_height)

    assert.is_true(total_height >= ui.const.WINDOW_GAP + 2 * ui.const.MIN_STACK_HEIGHT)
    assert.are.equal(total_height, list_cfg.height + ui.const.WINDOW_GAP + preview_cfg.height)
  end)

  it("horizontal honors width_ratio and ignores height_ratio", function()
    local cfg_width = 0.9
    local total_weight = math.floor(vim.o.columns * cfg_width)
    local width_ratio = 0.3

    ui.select_task_with_preview(require("taskfile.core").get_tasks(), {
      width = cfg_width,
      height = 0.4,
      border = "rounded",
      layout = "horizontal",
      width_ratio = width_ratio,
      height_ratio = 0.99, -- should be ignored in horizontal
    })

    local list_cfg, preview_cfg = win_cfg(ui._list_win), win_cfg(ui._preview_win)

    assert.are.equal(math.floor(total_weight * width_ratio), list_cfg.width)
    assert.are.equal(total_weight, list_cfg.width + 2 + preview_cfg.width) -- gap=2
  end)

  it("vertical honors height_ratio and ignores width_ratio", function()
    local cfg_height = 0.6
    local total_height = math.floor(vim.o.lines * cfg_height)
    local height_ratio = 0.4

    ui.select_task_with_preview(require("taskfile.core").get_tasks(), {
      width = 0.8,
      height = cfg_height,
      border = "rounded",
      layout = "vertical",
      height_ratio = height_ratio,
      width_ratio = 0.99, -- should be ignored in vertical
    })

    local list_cfg, preview_cfg = win_cfg(ui._list_win), win_cfg(ui._preview_win)

    local expected = math.floor(total_height * height_ratio)
    if (total_height - expected - ui.const.WINDOW_GAP) < ui.const.MIN_STACK_HEIGHT then
      expected = total_height - ui.const.WINDOW_GAP - ui.const.MIN_STACK_HEIGHT
    end

    assert.are.equal(expected, list_cfg.height)
    assert.are.equal(total_height, list_cfg.height + ui.const.WINDOW_GAP + preview_cfg.height)
  end)
end)
