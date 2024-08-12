-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
lvim.keys.insert_mode['jj'] = "<ESC>"
lvim.keys.insert_mode['jk'] = "<ESC>:w<CR>"
lvim.keys.normal_mode["<C-h>"] = ":bprev<CR>"
lvim.keys.normal_mode["<C-j>"] = false
lvim.keys.normal_mode["<C-k>"] = false
lvim.keys.normal_mode["<C-l>"] = ":bnext<CR>"
lvim.builtin.terminal.open_mapping = "<c-t>"
lvim.builtin.cmp.mapping["<Tab>"] = lvim.builtin.cmp.mapping["<CR>"]
lvim.builtin.cmp.mapping["<Right>"] = lvim.builtin.cmp.mapping["<CR>"]
