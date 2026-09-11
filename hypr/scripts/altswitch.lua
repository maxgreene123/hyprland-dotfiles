-- Adapted from Pablo-Merino/omarchy-altswitch at 8f54d684c89d66ecf51e6e5a9c5c574758de79be.
-- MIT license: ../../quickshell/modules/switcher/LICENSE in the dotfiles repository.
-- Hyprland owns the frozen window order, selection, and Alt-release handling.

local altswitch = { windows = {}, index = 1, active = false }

-- Quote arbitrary titles and paths before passing them to the shell.
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

-- Minimal JSON string escaping. Window titles are arbitrary text and routinely
-- contain quotes and backslashes.
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
    altswitch.index - 1 -- the plugin indexes from zero
  )
end

local function altswitch_teardown()
  altswitch.active = false
  altswitch.windows = {}
  altswitch_send("hide")
end

local function altswitch_commit()
  if not altswitch.active then
    return -- nothing in flight; the Alt release fires on every switch-less tap
  end

  -- Read the address before tearing down. Teardown drops the snapshot, and the
  -- window handles do not survive it: reading `.address` afterwards throws
  -- inside the key callback, which silently loses the switch.
  local target = altswitch.windows[altswitch.index]
  local address = nil
  for _, window in ipairs(hl.get_windows()) do
    if target and window.mapped and window.address == target.address then
      address = target.address
      break
    end
  end

  altswitch_teardown()

  -- Dispatched out of process on purpose. Focusing directly from inside the key
  -- callback updates Hyprland's idea of the active window but does not settle
  -- until the next input event, so the switch looks like it did nothing until
  -- you tap a key again. Going through hyprctl runs the same dispatcher from
  -- outside the input callback, where it takes effect at once.
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
  -- Already switching: just move the cursor, wrapping at both ends.
  if altswitch.active then
    altswitch.index = (altswitch.index - 1 + delta) % #altswitch.windows + 1
    altswitch_send("select", tostring(altswitch.index - 1))
    return
  end

  altswitch.windows = altswitch_snapshot()
  if #altswitch.windows < 2 then
    return
  end

  -- Entry 1 is the window you are already on, so one tap has to land on entry 2
  -- and one back-tap has to wrap to the oldest.
  altswitch.index = delta % #altswitch.windows + 1
  altswitch.active = true
  altswitch_send("show", altswitch_payload())
end

-- Self-heal hook for the panel. If the ALT release is ever missed, the panel
-- gives up on its own after a few seconds and calls this, so the two halves
-- cannot disagree about whether a switch is still in progress.
_G.__altswitch_cancel = altswitch_teardown

-- Replace existing Alt-Tab bindings before registering this switcher.
hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
hl.bind("ALT + TAB", function() altswitch_step(1) end, { description = "Switch window" })
hl.bind("ALT + SHIFT + TAB", function() altswitch_step(-1) end, { description = "Switch window (reverse)" })
hl.bind("ALT + ESCAPE", altswitch_teardown, { non_consuming = true, description = "Cancel window switch" })

-- Committing on ALT release cannot be a keybind. A release bind on a modifier
-- only fires when that modifier is tapped on its own; pressing TAB in between
-- cancels it, which is exactly what every switch does. So the raw key stream is
-- read instead, where the release always shows up.
--
-- 64 is Alt_L and 108 is Alt_R. This runs for every keystroke on the system, so
-- it stays down to two integer compares and a boolean unless a switch is up.
local ALT_KEYCODES = { [64] = true, [108] = true }

hl.on("input.keyboard.key", function(keycode, _, state)
  if state == 0 and altswitch.active and ALT_KEYCODES[keycode] then
    altswitch_commit()
  end
end)
