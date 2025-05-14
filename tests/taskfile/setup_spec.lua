local plugin = require("taskfile")
local core = require("taskfile.core")

describe("setup", function()
  it("can be required", function()
    require("taskfile")
  end)

  it("should fallback to default config if no opts provided", function()
    core.setup()

    local opts = require("taskfile.core")._options
    assert.are.same("rounded", opts.windows.output.border)
    assert.are.same("rounded", opts.windows.list.border)
  end)

  it("should apply custom float config", function()
    plugin.setup({
      windows = {
        output = {
          width = 0.5,
          height = 0.5,
          border = "double",
        },
      },
    })

    local output_cfg = core._options.windows.output
    assert.are.same(output_cfg.width, 0.5)
    assert.are.same(output_cfg.border, "double")
  end)

  it("should return windows list cfg", function()
    plugin.setup({
      windows = {
        list = {
          width = 0.4,
          height = 0.4,
          border = "single",
        },
      },
    })

    local list_cfg = core.get_list_config()
    assert.are.same(list_cfg.width, 0.4)
  end)

  it("should apply scroll option", function()
    plugin.setup({
      scroll = { auto = false },
    })

    local scroll_cfg = core._options.scroll
    assert.is_false(scroll_cfg.auto)
  end)

  it("should apply custom keymap config", function()
    plugin.setup({
      keymap = {
        rerun = "<leader>tt",
      },
    })

    local keymap_cfg = core._options.keymap
    assert.are.same(keymap_cfg.rerun, "<leader>tt")
  end)

  it("should apply valid width_ratio", function()
    plugin.setup({
      windows = {
        list = {
          width_ratio = 0.9,
        },
      },
    })

    local ratio = core._options.windows.list.width_ratio
    assert.are.same(0.9, ratio)
  end)

  it("should raise error for invalid output width < 0", function()
    local ok, err = pcall(function()
      plugin.setup({
        windows = {
          output = {
            width = -0.1,
          },
        },
      })
    end)
    assert.is_false(ok)
    assert.matches("output.width", err)
  end)

  it("should raise error for invalid list height > 1", function()
    local ok, err = pcall(function()
      plugin.setup({
        windows = {
          list = {
            height = 1.5,
          },
        },
      })
    end)
    assert.is_false(ok)
    assert.matches("list.height", err)
  end)

  it("should raise error for invalid width_ratio type", function()
    local ok, err = pcall(function()
      plugin.setup({
        windows = {
          list = {
            width_ratio = "wide",
          },
        },
      })
    end)
    assert.is_false(ok)
    assert.matches("width_ratio", err)
  end)
end)
