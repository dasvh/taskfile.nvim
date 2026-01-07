local spy = require("luassert.spy")
local utils = require("taskfile.utils")

describe("taskfile.telescope", function()
  local ts_ext

  local mock_pickers = {}
  local mock_finders = {}
  local mock_conf = { values = { generic_sorter = function() end } }
  local mock_actions = { select_default = { replace = function() end }, close = function() end }
  local mock_previewers = { new_buffer_previewer = function() end }
  local mock_utils_preview = { highlighter = function() end }

  local picker_new_spy

  before_each(function()
    mock_pickers.new = function()
      return { find = function() end }
    end
    mock_finders.new_table = function(opts)
      return opts
    end

    package.loaded["telescope.pickers"] = mock_pickers
    package.loaded["telescope.finders"] = mock_finders
    package.loaded["telescope.config"] = mock_conf
    package.loaded["telescope.actions"] = mock_actions
    package.loaded["telescope.previewers"] = mock_previewers
    package.loaded["telescope.previewers.utils"] = mock_utils_preview

    picker_new_spy = spy.on(mock_pickers, "new")

    package.loaded["taskfile.telescope"] = nil
    ts_ext = require("taskfile.telescope")
  end)

  after_each(function()
    package.loaded["taskfile.telescope"] = nil
  end)

  describe("Layout Logic Parity", function()
    local tasks = { { name = "task1", desc = "desc1" }, { name = "task2", desc = "desc2" } }
    local noop = function() end

    it("Horizontal: calculates exact window size based on % config", function()
      local config = {
        layout = "horizontal",
        windows = { list = { width = 0.8, height = 0.8 } },
      }

      ts_ext.pick_task(tasks, noop, config)

      local opts = picker_new_spy.calls[1].vals[2]
      local lc = opts.layout_config

      local expected_w, expected_h = utils.calculate_dimensions(0.8, 0.8)

      assert.equals(expected_w, lc.width)
      assert.equals(expected_h, lc.height)
      assert.equals("bottom", lc.prompt_position)
    end)

    it("Horizontal: respects width_ratio by adjusting preview_width", function()
      local ratio = 0.3
      local config = {
        layout = "horizontal",
        windows = { list = { width = 0.9, height = 0.5, width_ratio = ratio } },
      }

      ts_ext.pick_task(tasks, noop, config)

      local opts = picker_new_spy.calls[1].vals[2]
      local lc = opts.layout_config

      local available_w = lc.width - ts_ext.const.TELESCOPE_WIDTH
      local expected_list_w = math.floor(available_w * ratio)
      local expected_preview_w = available_w - expected_list_w

      assert.equals(expected_preview_w, lc.preview_width)
    end)

    it("Vertical: respects height_ratio by adjusting preview_height", function()
      local ratio = 0.2
      local config = {
        layout = "vertical",
        windows = { list = { width = 0.8, height = 0.9, height_ratio = ratio } },
      }

      ts_ext.pick_task(tasks, noop, config)

      local opts = picker_new_spy.calls[1].vals[2]
      local lc = opts.layout_config

      assert.is_true(lc.mirror)
      assert.equals("bottom", lc.prompt_position)

      local available_h = lc.height - ts_ext.const.TELESCOPE_HEIGHT

      local raw_wanted_list_h = math.floor(available_h * ratio)
      local expected_list_h = math.max(ts_ext.const.MIN_STACK_HEIGHT, raw_wanted_list_h)

      local expected_preview_h = available_h - expected_list_h

      assert.equals(expected_preview_h, lc.preview_height)
    end)

    it("Vertical: uses dynamic sizing (shrinks list) when height_ratio is nil", function()
      local few_tasks = { { name = "1" }, { name = "2" } }
      local config = {
        layout = "vertical",
        windows = { list = { width = 0.5, height = 0.9 } },
      }

      ts_ext.pick_task(few_tasks, noop, config)
      local lc = picker_new_spy.calls[1].vals[2].layout_config

      local available_h = lc.height - ts_ext.const.TELESCOPE_HEIGHT

      assert.is_true(
        lc.preview_height > (available_h / 2),
        "Preview should take the majority of space when list is tiny"
      )
    end)

    it("Vertical: enforces minimum preview height when list is huge", function()
      local many_tasks = {}
      for i = 1, 100 do
        table.insert(many_tasks, { name = "t" .. i })
      end

      local config = {
        layout = "vertical",
        windows = { list = { width = 0.5, height = 0.5 } },
      }

      ts_ext.pick_task(many_tasks, noop, config)
      local lc = picker_new_spy.calls[1].vals[2].layout_config

      assert.equals(ts_ext.const.MIN_PREVIEW_HEIGHT, lc.preview_height)
    end)
  end)
end)
