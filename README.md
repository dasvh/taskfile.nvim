# taskfile.nvim

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/dasvh/taskfile.nvim/lint-test.yml?branch=main&style=for-the-badge)
![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A simple plugin for [taskfiles](https://taskfile.dev/)

## Features

- Run a specific task directly within Neovim
- Browse available tasks with a floating window
- Preview each task’s command before execution
- Run tasks in a floating terminal
- Automatically scroll to bottom of output (optional)
- Rerun last task via command or key-map

## Requirements

- [task](https://taskfile.dev/#/installation) CLI installed and in your `$PATH`
- Neovim 0.8 or higher (0.9+ recommended)

## Setup

```lua
{
  "dasvh/taskfile.nvim",
  config = function()
    require("taskfile").setup()
  end,
}
```

### Configuration

You can pass options to the `setup()` function to customise behaviour.
All fields are optional and shown below with their default values:

```lua
require('taskfile').setup({
  windows = {
    output = {           -- Task output window
      width = 0.8,       -- Width of the window (percentage of editor width)
      height = 0.8,      -- Height of window (percentage of editor height)
      border = "rounded" -- Border style: 'single', 'double', 'rounded', etc.
    },
    list = {             -- Task list and preview window
      width = 0.6,
      height = 0.4,
      border = "rounded"
      width_ratio = 0.4  -- Ratio (0-1) of list vs preview width
    },
  },
  scroll = {
    auto = true,         -- Auto-scroll output to bottom when new lines are printed
  },
  keymaps = {
    rerun = "<leader>tr" -- Key-map to rerun the last executed task
  },
})
```

## Usage

This plugin reads your Taskfile and displays available tasks.

### Commands

- `:Task <task_name>`: Run a specific task by name
- `:Task`: Show a floating task selector with preview
- `:TaskRerun`: Rerun the last executed task

You can also bind a key to rerun using the `keymaps.rerun` config.

<!-- panvimdoc-ignore-start -->

## Demo

![Demo GIF](./demo/demo.gif)

<!-- panvimdoc-ignore-end -->
