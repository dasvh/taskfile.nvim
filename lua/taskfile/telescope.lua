--@class telescope
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local putils = require("telescope.previewers.utils")

local utils = require("taskfile.utils")
local ui = require("taskfile.ui")

local C = utils.const

-- cache constants
local TASK_NAME_DESC_GAP = C.TASK_NAME_DESC_GAP
local MIN_PREVIEW_HEIGHT = C.MIN_PREVIEW_HEIGHT
local MIN_PREVIEW_WIDTH = C.MIN_PREVIEW_WIDTH
local NO_WRAP_WIDTH = C.NO_WRAP_WIDTH
local TELESCOPE_HEIGHT = C.TELESCOPE_HEIGHT
local TELESCOPE_WIDTH = C.TELESCOPE_WIDTH
local SELECTION_CARET = C.SELECTION_CARET

M.const = C

---@class TelescopeLayoutConfig
---@field width integer           Total window width
---@field height integer          Total window height
---@field preview_width? integer  Horizontal: Specific width for preview
---@field preview_height? integer Vertical: Specific height for preview
---@field prompt_position? "top"|"bottom"
---@field mirror? boolean         If true, mirrors the layout (prompt/list on top in vertical)
---@field label_width? integer    Cached max width of task labels

--- Calculate layout to match native behavior
---@param opts table Taskfile configuration
---@param tasks table List of tasks
---@return string strategy, TelescopeLayoutConfig layout_conf
local function get_layout_config(opts, tasks)
  opts = opts or {}
  local list_conf = (opts.windows and opts.windows.list) or {}

  local strategy = opts.layout or "horizontal"

  local total_width, total_height, _, _ = utils.calculate_dimensions(list_conf.width, list_conf.height)
  local label_width = utils.max_task_label_length(tasks)

  ---@type TelescopeLayoutConfig
  local layout_conf = {
    width = total_width,
    height = total_height,
    label_width = label_width,
  }

  if strategy == "vertical" then
    layout_conf.mirror = true
    layout_conf.prompt_position = "bottom"

    local available_content_h = math.max(0, total_height - TELESCOPE_HEIGHT)

    local list_h =
      ui.calculate_list_height(tasks, list_conf.height_ratio, available_content_h, total_width, label_width)
    local preview_h = available_content_h - list_h

    if preview_h < MIN_PREVIEW_HEIGHT then
      preview_h = MIN_PREVIEW_HEIGHT
    end

    layout_conf.preview_height = preview_h
  else
    layout_conf.prompt_position = "bottom"

    local available_content_w = math.max(0, total_width - TELESCOPE_WIDTH)
    local list_w = ui.calculate_list_width(tasks, list_conf.width_ratio, available_content_w, label_width)

    local preview_w = available_content_w - list_w
    layout_conf.preview_width = math.max(MIN_PREVIEW_WIDTH, preview_w)
  end

  return strategy, layout_conf
end

local function task_previewer()
  return previewers.new_buffer_previewer({
    title = "Preview",
    define_preview = function(self, entry)
      local cmd = "task " .. entry.value.name .. " --dry"
      local output = vim.fn.system(cmd)
      local lines = vim.split(output, "\n")
      local cleaned_lines = utils.clean_dry_output(lines)

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, cleaned_lines)
      putils.highlighter(self.state.bufnr, "sh")
    end,
  })
end

M.pick_task = function(tasks, run_callback, plugin_opts)
  local strategy, layout_conf = get_layout_config(plugin_opts, tasks)

  pickers
    .new({}, {
      prompt_title = "Find Task",
      results_title = "Tasks",
      selection_caret = SELECTION_CARET,

      finder = finders.new_table({
        results = tasks,
        entry_maker = function(task)
          local name = task.name or ""
          local desc = task.desc or ""

          -- we pass NO_WRAP_WIDTH to effectively disable wrapping.
          local formatted_lines =
            utils.format_task_lines(name, desc, layout_conf.label_width, NO_WRAP_WIDTH, TASK_NAME_DESC_GAP)

          return {
            value = task,
            display = formatted_lines[1],
            ordinal = name .. " " .. desc,
          }
        end,
      }),

      sorter = conf.generic_sorter({}),
      previewer = task_previewer(),

      layout_strategy = strategy,
      layout_config = layout_conf,

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection.value then
            run_callback(selection.value.name)
          end
        end)
        return true
      end,
    })
    :find()
end

return M
