local plugin = require("taskfile")
local core = require("taskfile.core")

describe("setup", function()
  it("can be required", function()
    require("taskfile")
  end)

  it("should fallback to default config if no opts provided", function()
    core.setup()
    local opts = require("taskfile.core")._options
    assert.are.same("rounded", opts.float.border)
  end)

  it("should apply custom float config", function()
    plugin.setup({
      float = {
        width = 0.5,
        height = 0.5,
        border = "double",
      },
    })

    local float_cfg = core._options.float

    assert.are.same(float_cfg.width, 0.5)
    assert.are.same(float_cfg.border, "double")
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
end)
