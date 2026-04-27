-- NOTE: compile stb_image.c into shared library first
--       or use compile.sh if you have cc in your path.
local image_id = 69
local image_path = 'image.jpg'
local chunk_size = 4096

local stdout = vim.uv.new_tty(1, false)
assert(stdout)

local function get_screen_cursor()
  local row, col = unpack(vim.api.nvim_win_get_position(0))
  return row + vim.fn.winline(), col + vim.fn.wincol()
end

-- synchronized output.
-- it might be useless since neovim can read to stdout in between our write.
--   https://github.com/contour-terminal/vt-extensions/blob/master/synchronized-output.md
local function sync(callback)
  stdout:write('\x1b[?2026h')
  callback()
  stdout:write('\x1b[?2026l')
end

-- cursor movement.
--   https://vt100.net/docs/vt510-rm/DECSC.html
--   https://vt100.net/docs/vt510-rm/DECRC.html
local function temp_move_cursor(row, col, callback)
  stdout:write('\x1b7')
  stdout:write(string.format('\x1b[%d;%dH', row, col))
  callback()
  stdout:write('\x1b8')
end

local augroup = vim.api.nvim_create_augroup('pussy', { clear = true })
vim.api.nvim_create_autocmd('CursorHold', {
  group = augroup,
  callback = function()
    local stb_image = require('stb_image')
    local image = stb_image.load(image_path)
    assert(image)

    -- a=T        : transmit + display.
    -- i=<n>      : assign image an id.
    --              https://sw.kovidgoyal.net/kitty/graphics-protocol/#display-images-on-screen
    -- f=32       : raw rgba pixels.
    --              https://sw.kovidgoyal.net/kitty/graphics-protocol/#transferring-pixel-data
    -- q=2        : dont response.
    -- s=<n>,v=<n>: image width and height.
    -- c=<n>,r=<n>: columns and rows.
    local controls = string.format(
      'a=T,i=%d,f=32,s=%d,v=%d,c=30,r=10,q=2',
      image_id,
      image.width,
      image.height
    )
    local encoded = vim.base64.encode(image.data)

    local row, col = get_screen_cursor()
    sync(function()
      temp_move_cursor(row, col, function()
        for i = 1, #encoded, chunk_size do
          local chunk = encoded:sub(i, i + chunk_size - 1):gsub('%s', '')
          if chunk ~= '' then
            local has_more = i + chunk_size <= #encoded
            local control = ((i == 1) and (controls .. ',') or '')
              .. 'm='
              .. (has_more and 1 or 0)
            stdout:write(string.format('\x1b_G%s;%s\x1b\\', control, chunk))

            if has_more then
              vim.uv.sleep(1)
            end
          end
        end
      end)
    end)
  end,
})

local function delete_image()
  -- a=d   : delete.
  -- d=<n> : assign image an id.
  stdout:write(string.format('\x1b_Ga=d,d=i,i=%d,q=2\x1b\\', image_id))
end

vim.api.nvim_create_autocmd({ 'CursorMovedI', 'CursorMoved' }, {
  group = augroup,
  callback = delete_image,
})

vim.keymap.set('n', '<C-x>', function()
  delete_image()
  vim.api.nvim_clear_autocmds({ group = augroup })
end)
