local M = {}

local paths = {}
local appName = os.getenv('NVIM_APPNAME') or 'nvim'
paths.home = os.getenv('HOME')
paths.data_home = os.getenv('XDG_DATA_HOME') or M.home .. '/.local/share'
paths.data_dir = paths.data_home .. '/' .. appName
paths.config_home = os.getenv('XDG_CONFIG_HOME') or paths.home .. '/.config'
paths.config_dir = paths.config_home .. '/' .. appName

local ts = {}

local function get_prompt_prefix(path)
  if path ~= nil and path ~= '.' then
    return path .. ' → '
  end
  return '→ '
end

local function replacePrefix(path, prefix, replace)
  if prefix ~= nil and string.sub(path, 1, prefix:len()) == prefix then
    return replace .. string.sub(path, prefix:len() + 2)
  end
  return path
end

local function git_root()
  local git_path = vim.fs.find('.git', { upward = true, limit = 1 })[1]
  if git_path ~= nil then
    return vim.fs.dirname(git_path)
  end
end

local function set_path(path, opts)
  opts = opts or {}
  if path ~= nil and path ~= '.' then
    local prefix = path
    prefix = replacePrefix(prefix, vim.uv.cwd(), '')
    if string.sub(prefix, 1, 1) == '/' then
      prefix = replacePrefix(prefix, git_root(), ' ')
    end
    prefix = replacePrefix(prefix, paths.home, '~/')

    return vim.tbl_extend('keep', {
      cwd = path,
      prompt_prefix = get_prompt_prefix(prefix),
    }, opts)
  end

  return opts
end

local function make_gen_from_file(opts)
  local make_entry = require('telescope.make_entry')
  local gen = make_entry.gen_from_file(opts)
  return function(filename)
    return gen(filename:gsub('^%./', ''))
  end
end

local function entry_path(entry)
  return entry.path or entry.filename
end

local function set_entry_maker(path, opts)
  opts = opts or {}
  if path ~= nil and path ~= '.' then
    return vim.tbl_extend('keep', {
      entry_maker = make_gen_from_file({ cwd = path }),
    }, opts)
  end

  return opts
end

function ts.in_root(fn)
  return function()
    local git_path = vim.fs.find('.git', { upward = true, limit = 1 })[1]

    if git_path ~= nil then
      fn(vim.fs.dirname(git_path))
    else
      print('Could not find root')
    end
  end
end

function ts.in_config(fn)
  return function()
    return fn(paths.config_dir)
  end
end

function ts.in_workspace(fn)
  return function()
    return fn(require('jg.telescope-workspaces').get_current_workspace_path())
  end
end

function ts.in_github_workflows(fn)
  return ts.in_root(function(root)
    fn(vim.fs.joinpath(root, '.github/workflows'))
  end)
end

-- TODO extract into josa42/nvim-telescope-workspaces
function ts.select_workspace()
  local ws = require('jg.telescope-workspaces')

  vim.ui.select(ws.get_workspaces(), { prompt = 'Workspace' }, function(w)
    ws.set_current_workspace(w)
  end)
end

function M.find_files(path)
  local builtin = require('telescope.builtin')
  builtin.find_files(set_path(path, set_entry_maker(path)))
end

function M.find_string(path)
  local builtin = require('telescope.builtin')
  builtin.live_grep(set_path(path))
end

function ts.file_browser(path)
  vim.cmd.Telescope('file_browser', path and ('path=%s'):format(path))
end

M.setup = function(opts)
  local telescope = require('telescope')
  local builtin = require('telescope.builtin')
  local actions = require('telescope.actions')
  local action_layout = require('telescope.actions.layout')
  local action_set = require('telescope.actions.set')
  local action_state = require('telescope.actions.state')

  local open = require('telescope-config.open').open
  local edit = require('telescope-config.open').edit

  local function action_toggle_width(prompt_bufnr)
    local current_picker = action_state.get_current_picker(prompt_bufnr)
    if current_picker.layout_config.width == nil then
      current_picker.layout_config.width = 0.9
    else
      current_picker.layout_config.width = nil
    end
    current_picker:full_layout_update()
  end

  local function action_edit(prompt_bufnr, type)
    action_set.edit(prompt_bufnr, action_state.select_key_to_edit_key('default'))
  end

  local function action_select(bufnr)
    local entry = action_state.get_selected_entry()
    local filepath = entry_path(entry)
    if filepath then
      actions.close(bufnr)
      open(filepath, entry.lnum and { entry.lnum, entry.col or 0 } or nil)
    end
  end

  local function create_action(prompt_bufnr)
    local current_picker = action_state.get_current_picker(prompt_bufnr)
    local file = action_state.get_current_line()
    if file == '' then
      return
    end

    if current_picker.cwd then
      file = current_picker.cwd .. '/' .. file
    end

    actions.close(prompt_bufnr)
    edit('tabe', file)
  end

  local function default_opts(opts)
    opts = opts or {}

    return vim.tbl_extend('keep', opts, {
      attach_mappings = function()
        action_set.select:replace_if(function(_, type)
          local entry = action_state.get_selected_entry()
          return type == 'default' and entry_path(entry) and not entry.cmd
        end, action_select)

        return true
      end,
    })
  end

  local function picker_default_opts(pickers)
    for key in pairs(builtin) do
      pickers[key] = default_opts(pickers[key])
    end
    return pickers
  end

  local has_filebrowser, _ = pcall(require, 'telescope._extensions.file_browser')

  telescope.setup({
    pickers = picker_default_opts({
      find_files = {
        hidden = true,
        entry_maker = make_gen_from_file(),
      },
      live_grep = {
        additional_args = function()
          return { '--hidden' }
        end,
        preview = { hide_on_startup = false },
      },
      help_tags = {
        preview = { hide_on_startup = false },
      },
      git_bcommits = {
        preview = { hide_on_startup = false },
      },
      git_commits = {
        preview = { hide_on_startup = false },
      },
      highlights = {
        preview = { hide_on_startup = false },
      },
      jumplist = {
        preview = { hide_on_startup = false },
      },
    }),
    defaults = {
      layout_strategy = 'minimal',
      layout_config = {
        prompt_position = 'top',
      },
      sorting_strategy = 'ascending',
      prompt_prefix = get_prompt_prefix(),
      selection_caret = '→ ',
      entry_prefix = '  ',
      preview = {
        hide_on_startup = true,
      },
      mappings = {
        i = {
          ['<C-Down>'] = actions.cycle_history_next,
          ['<C-Up>'] = actions.cycle_history_prev,

          ['<C-j>'] = actions.move_selection_next,
          ['<C-k>'] = actions.move_selection_previous,

          ['<esc>'] = actions.close,

          ['<Down>'] = actions.move_selection_next,
          ['<Up>'] = actions.move_selection_previous,

          ['<CR>'] = actions.select_default + actions.center,
          ['<C-e>'] = action_edit,
          ['<C-x>'] = actions.select_horizontal,
          ['<C-v>'] = actions.select_vertical,
          ['<C-t>'] = actions.select_tab,
          ['<C-n>'] = create_action,

          ['<C-u>'] = actions.preview_scrolling_up,
          ['<C-d>'] = actions.preview_scrolling_down,

          ['<Tab>'] = actions.toggle_selection + actions.move_selection_worse,
          ['<S-Tab>'] = actions.toggle_selection + actions.move_selection_better,
          ['<C-l>'] = actions.complete_tag,

          ['<C-q>'] = actions.smart_send_to_qflist + actions.open_qflist,
          ['<C-a>'] = actions.add_selected_to_qflist + actions.open_qflist,

          ['<c-p>'] = action_layout.toggle_preview,
          ['<c-w>'] = action_toggle_width,
        },
      },
      borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
      file_ignore_patterns = {
        '%.git$',
        '%.git/',
        '%.DS_Store$',
        'node_modules/',
        '%.(png|PNG|jpe?g|JPE?G|pdf|PDF)$',
      },
    },
    extensions = {
      ['ui-select'] = {
        {
          layout_config = {
            width = 60,
            height = 16,
          },
        },
      },
      file_browser = {
        dir_icon = opts.icons.dir_icon,
        hijack_netrw = true,
        mappings = {
          ['i'] = {
            ['<CR>'] = actions.select_default,
          },
        },
      },
    },
  })

  telescope.load_extension('fzf')
  telescope.load_extension('minimal_layout')
  telescope.load_extension('ui-select')

  if has_filebrowser then
    telescope.load_extension('file_browser')
  end

  vim.api.nvim_create_user_command('Find', function(opts)
    M.find_files(opts.args)
  end, {
    nargs = 1,
    complete = 'file',
  })
end

M.find_files = M.find_files
M.find_string = M.find_string

M.commands = {
  global = {
    find_files = M.find_files,
    find_string = M.find_string,
    file_browser = ts.file_browser,
  },

  workspace = {
    select = ts.select_workspace,
    find_files = ts.in_workspace(M.find_files),
    find_string = ts.in_workspace(M.find_string),
    file_browser = ts.in_workspace(ts.file_browser),
  },

  root = {
    find_files = ts.in_root(M.find_files),
    find_string = ts.in_root(M.find_string),
    file_browser = ts.in_root(ts.file_browser),
  },

  config = {
    find_files = ts.in_config(M.find_files),
    find_string = ts.in_config(M.find_string),
    file_browser = ts.in_config(ts.file_browser),
  },

  workflows = {
    find_files = ts.in_github_workflows(M.find_files),
    find_string = ts.in_github_workflows(M.find_string),
    file_browser = ts.in_github_workflows(ts.file_browser),
  },
}

return M
