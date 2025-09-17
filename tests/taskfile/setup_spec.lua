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
    assert.are.same(true, opts.scroll.auto)
    assert.are.same("<leader>tr", opts.keymaps.rerun)
    assert.are.same("horizontal", opts.layout)
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

  it("should treat ratio nil/unset as 0", function()
    plugin.setup({
      windows = {
        list = {
          width_ratio = nil,
          -- height_ratio is not set
        },
      },
    })

    local width_ratio = core._options.windows.list.width_ratio
    local height_ratio = core._options.windows.list.height_ratio

    assert.are.same(0, width_ratio)
    assert.are.same(0, height_ratio)
  end)

  it("should apply valid height_ratio", function()
    plugin.setup({
      windows = {
        list = {
          height_ratio = 0.5,
        },
      },
    })

    local ratio = core._options.windows.list.height_ratio
    assert.are.same(0.5, ratio)
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

  it("should raise error for invalid height_ratio type", function()
    local ok, err = pcall(function()
      plugin.setup({
        windows = {
          list = {
            height_ratio = "tall",
          },
        },
      })
    end)
    assert.is_false(ok)
    assert.matches("height_ratio", err)
  end)

  it("should raise error for invalid layout value", function()
    local ok, err = pcall(function()
      plugin.setup({
        layout = "grid",
      })
    end)
    assert.is_false(ok)
    assert.matches("must be one of", err)
  end)

  it("should allow abbreviated layout values", function()
    plugin.setup({ layout = "v" })
    local cfg = core.get_list_config()
    assert.equals("vertical", cfg.layout)

    plugin.setup({ layout = "vert" })
    local cfg = core.get_list_config()
    assert.equals("vertical", cfg.layout)

    plugin.setup({ layout = "h" })
    cfg = core.get_list_config()
    assert.equals("horizontal", cfg.layout)

    plugin.setup({ layout = "horiz" })
    cfg = core.get_list_config()
    assert.equals("horizontal", cfg.layout)
  end)

  it("should allow mixed case layout values", function()
    plugin.setup({ layout = "Vertical" })
    local cfg = core.get_list_config()
    assert.equals("vertical", cfg.layout)

    plugin.setup({ layout = "HORIZONTAL" })
    cfg = core.get_list_config()
    assert.equals("horizontal", cfg.layout)
  end)

  it("should fallback to horizontal layout if layout is not a string", function()
    plugin.setup({ layout = 123 })
    local cfg = core.get_list_config()
    assert.equals("horizontal", cfg.layout)

    plugin.setup({ layout = true })
    cfg = core.get_list_config()
    assert.equals("horizontal", cfg.layout)

    plugin.setup({ layout = nil })
    cfg = core.get_list_config()
    assert.equals("horizontal", cfg.layout)
  end)

  it("should default to horizontal layout", function()
    local cfg = core.get_list_config()
    assert.equals("horizontal", cfg.layout)
  end)

  it("should allow vertical layout", function()
    core.setup({ layout = "vertical" })
    local cfg = core.get_list_config()
    assert.equals("vertical", cfg.layout)
  end)
end)
