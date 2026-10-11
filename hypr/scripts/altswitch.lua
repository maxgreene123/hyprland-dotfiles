-- Adapted from Pablo-Merino/omarchy-altswitch at 8f54d684c89d66ecf51e6e5a9c5c574758de79be.
-- MIT license: ../../quickshell/modules/switcher/LICENSE in the dotfiles repository.

local altswitch = { windows = {}, index = 1, active = false }

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function altswitch_send(method, argument)
  local command = "quickshell ipc -p " .. shell_quote(os.getenv("HOME") .. "/.config/quickshell")
    .. " call -- altswitch " .. method
  if argument then
    command = command .. " " .. shell_quote(argument)
  end
  hl.exec_cmd(command)
end

local function altswitch_json_string(value)
  local escaped = tostring(value or "")
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("[%c]", function(control) return string.format("\\u%04x", control:byte()) end)
  return '"' .. escaped .. '"'
end

local function altswitch_payload()
  local rows = {}
  for _, window in ipairs(altswitch.windows) do
    rows[#rows + 1] = string.format(
      '{"title":%s,"appClass":%s,"workspace":%s}',
      altswitch_json_string(window.title),
      altswitch_json_string(window.class),
      altswitch_json_string(window.workspace and window.workspace.name or "")
    )
  end

  return string.format(
    '{"windows":[%s],"index":%d}',
    table.concat(rows, ","),
    altswitch.index - 1 -- Quickshell uses zero-based indexes.
  )
end

local function altswitch_teardown()
  altswitch.active = false
  altswitch.windows = {}
  altswitch_send("hide")
end

local function altswitch_commit()
  if not altswitch.active then
    return
  end

  -- Resolve the live target before clearing the snapshot.
  local target = altswitch.windows[altswitch.index]
  local address = nil
  for _, window in ipairs(hl.get_windows()) do
    if target and window.mapped and window.address == target.address then
      address = target.address
      break
    end
  end

  altswitch_teardown()

  -- External dispatch avoids focus waiting for the next input event.
  if address then
    local focus = string.format('hl.dsp.focus({ window = "address:%s" })', address)
    hl.exec_cmd("hyprctl dispatch " .. shell_quote(focus))
  end
end

local function altswitch_snapshot()
  local windows = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace
    if window.mapped and workspace and not workspace.special then
      windows[#windows + 1] = {
        address = window.address, title = window.title, class = window.class,
        workspace = { name = workspace.name }, focus_history_id = window.focus_history_id,
      }
    end
  end

  table.sort(windows, function(a, b) return a.focus_history_id < b.focus_history_id end)
  return windows
end

local function altswitch_step(delta)
  if altswitch.active then
    altswitch.index = (altswitch.index - 1 + delta) % #altswitch.windows + 1
    altswitch_send("select", tostring(altswitch.index - 1))
    return
  end

  altswitch.windows = altswitch_snapshot()
  if #altswitch.windows < 2 then
    return
  end

  -- Skip the focused window; reverse starts at the oldest.
  altswitch.index = delta % #altswitch.windows + 1
  altswitch.active = true
  altswitch_send("show", altswitch_payload())
end

-- The panel watchdog cancels missed Alt releases.
_G.__altswitch_cancel = altswitch_teardown

hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
hl.bind("ALT + TAB", function() altswitch_step(1) end, { description = "Switch window" })
hl.bind("ALT + SHIFT + TAB", function() altswitch_step(-1) end, { description = "Switch window (reverse)" })
hl.bind("ALT + ESCAPE", altswitch_teardown, { non_consuming = true, description = "Cancel window switch" })

-- Modifier release binds miss Alt-Tab; watch raw Alt_L/Alt_R releases.
local ALT_KEYCODES = { [64] = true, [108] = true }

hl.on("input.keyboard.key", function(keycode, _, state)
  if state == 0 and altswitch.active and ALT_KEYCODES[keycode] then
    altswitch_commit()
  end
end)
