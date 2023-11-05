local M = {}

function M.open(filepath, pos)
  if not M.switch_to(filepath, pos) then
    if M.buf_is_empty() then
      M.edit('edit', filepath, pos)
    else
      M.edit('tabedit', filepath, pos)
    end
  end
end

function M.switch_to(filepath, pos)
  local file = vim.loop.fs_realpath(filepath)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if file == vim.api.nvim_buf_get_name(buf) then
      vim.api.nvim_set_current_win(win)
      if pos ~= nil then
        pcall(vim.api.nvim_win_set_cursor, win, pos)
      end
      return true
    end
  end

  return false
end

function M.edit(command, filename, pos)
  vim.cmd(('%s %s'):format(command, vim.fn.fnameescape(filename)))
  if pos ~= nil then
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end
end

function M.buf_is_empty()
  if vim.api.nvim_buf_get_name(0) ~= '' or vim.api.nvim_buf_line_count(0) > 1 then
    return false
  end

  return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == ''
end

return M
