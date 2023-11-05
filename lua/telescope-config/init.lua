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
    return '[' .. path .. '] → '
  end
  return '→ '
end

local function set_path(path, opts)
  opts = opts or {}
  if path ~= nil and path ~= '.' then
    if string.sub(path, 1, paths.home:len()) == paths.home then
      path = '~' .. string.sub(path, paths.home:len() + 1)
    end

    return vim.tbl_extend('keep', {
      cwd = path,
      prompt_prefix = get_prompt_prefix(path),
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
    print(vim.inspect(fn))
    return fn(require('jg.telescope-workspaces').get_current_workspace_path())
  end
end

function ts.find_files(path)
  local builtin = require('telescope.builtin')
  builtin.find_files(set_path(path, set_entry_maker(path)))
end

function ts.find_string(path)
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
  telescope.load_extension('file_browser')

  -- TODO extract into josa42/nvim-telescope-workspaces
  function ts.select_workspace()
    local ws = require('jg.telescope-workspaces')

    vim.ui.select(ws.get_workspaces(), { prompt = 'Workspace' }, function(w)
      ws.set_current_workspace(w)
    end)
  end

  function ts.find_string_in_buffer()
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({ previewer = false }))
  end

  vim.api.nvim_create_user_command('Find', function(opts)
    ts.find_files(opts.args)
  end, {
    nargs = 1,
    complete = 'file',
  })
end

M.commands = {
  global = {
    find_files = ts.find_files,
    find_string = ts.find_string,
    file_browser = ts.file_browser,
  },

  workspace = {
    select = ts.select_workspace,
    find_files = ts.in_workspace(ts.find_files),
    find_string = ts.in_workspace(ts.find_string),
    file_browser = ts.in_workspace(ts.file_browser),
  },

  root = {
    find_files = ts.in_root(ts.find_files),
    find_string = ts.in_root(ts.find_string),
    file_browser = ts.in_root(ts.file_browser),
  },

  config = {
    find_files = ts.in_config(ts.find_files),
    find_string = ts.in_config(ts.find_string),
    file_browser = ts.in_config(ts.file_browser),
  },
}

return M