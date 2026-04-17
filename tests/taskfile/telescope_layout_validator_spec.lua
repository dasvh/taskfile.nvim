describe("taskfile.telescope layout validation", function()
  local ts_ext
  local telescope_pickers
  local original_pickers_new
  local captured_picker_opts

  before_each(function()
    package.loaded["taskfile.telescope"] = nil

    telescope_pickers = require("telescope.pickers")
    original_pickers_new = telescope_pickers.new
    captured_picker_opts = nil

    telescope_pickers.new = function(_, opts)
      captured_picker_opts = opts
      return {
        find = function() end,
      }
    end

    ts_ext = require("taskfile.telescope")
  end)

  after_each(function()
    if telescope_pickers and original_pickers_new then
      telescope_pickers.new = original_pickers_new
    end
    package.loaded["taskfile.telescope"] = nil
  end)

  it("passes vertical layout_config accepted by Telescope validator", function()
    local tasks = {
      { name = "build", desc = "compile project" },
      { name = "test", desc = "run tests" },
    }

    ts_ext.pick_task(tasks, function() end, {
      layout = "vertical",
      windows = { list = { width = 0.8, height = 0.8, height_ratio = 0.35 } },
    })

    assert.is_not_nil(captured_picker_opts)
    assert.equals("vertical", captured_picker_opts.layout_strategy)
    assert.is_nil(captured_picker_opts.layout_config.label_width)

    local layout_strategies = require("telescope.pickers.layout_strategies")
    local ok, err = pcall(
      layout_strategies._validate_layout_config,
      "vertical",
      layout_strategies._configurations.vertical,
      captured_picker_opts.layout_config
    )

    assert.is_true(ok, err)
  end)
end)
