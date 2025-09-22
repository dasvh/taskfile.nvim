local this = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(this, ":h:h")

vim.opt.rtp:append(root)

local pack = vim.fn.stdpath("data") .. "/site/pack/deps/start"
local plenary_dir = pack .. "/plenary.nvim"
if vim.fn.isdirectory(plenary_dir) == 0 then
  vim.fn.mkdir(pack, "p")
  vim.fn.system({ "git", "clone", "--depth=1", "https://github.com/nvim-lua/plenary.nvim", plenary_dir })
end

if not string.find(vim.o.packpath, vim.fn.stdpath("data"), 1, true) then
  vim.opt.packpath:append(vim.fn.stdpath("data") .. "/site")
end

vim.cmd("packadd plenary.nvim")
require("plenary.busted")
