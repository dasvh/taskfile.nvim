local this = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(this, ":h:h")

vim.opt.rtp:append(root)

local pack = vim.fn.stdpath("data") .. "/site/pack/deps/start"

-- 1. Setup paths
local plenary_dir = pack .. "/plenary.nvim"
local telescope_dir = pack .. "/telescope.nvim"

-- 2. Ensure directory exists
if vim.fn.isdirectory(pack) == 0 then
  vim.fn.mkdir(pack, "p")
end

-- 3. Download Plenary
if vim.fn.isdirectory(plenary_dir) == 0 then
  vim.fn.system({ "git", "clone", "--depth=1", "https://github.com/nvim-lua/plenary.nvim", plenary_dir })
end

-- 4. Download Telescope (NEW)
if vim.fn.isdirectory(telescope_dir) == 0 then
  vim.fn.system({ "git", "clone", "--depth=1", "https://github.com/nvim-telescope/telescope.nvim", telescope_dir })
end

if not string.find(vim.o.packpath, vim.fn.stdpath("data"), 1, true) then
  vim.opt.packpath:append(vim.fn.stdpath("data") .. "/site")
end

-- 5. Load plugins
vim.cmd("packadd plenary.nvim")
vim.cmd("packadd telescope.nvim")

require("plenary.busted")
