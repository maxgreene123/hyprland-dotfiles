-- Exercise compositor callbacks without focusing real windows.
local bindings, events, commands = {}, {}, {}
local windows = {
    { address = "0x3", title = "Oldest", class = "old", mapped = true, focus_history_id = 2, workspace = { name = "11" } },
    { address = "0x1", title = "Current", class = "current", mapped = true, focus_history_id = 0, workspace = { name = "1" } },
    { address = "0x2", title = "Previous 'quoted' $() \"title\"\nnext", class = "previous", mapped = true, focus_history_id = 1, workspace = { name = "2" } },
    { address = "0x4", mapped = true, focus_history_id = -1, workspace = { name = "special", special = true } },
}
hl = {
    exec_cmd = function(command) commands[#commands + 1] = command end,
    get_windows = function() return windows end,
    unbind = function() end,
    bind = function(chord, callback) bindings[chord] = callback end,
    on = function(event, callback) events[event] = callback end,
}
dofile("../hypr/scripts/altswitch.lua")
local function last() return commands[#commands] end
local function step() bindings["ALT + TAB"]() end
local function back() bindings["ALT + SHIFT + TAB"]() end
local function release() events["input.keyboard.key"](64, nil, 0) end
step()
assert(last():find('"index":1', 1, true))
assert(not last():find('"workspace":"special"', 1, true))
assert(last():find("quickshell ipc -p", 1, true))
assert(last():find("call -- altswitch show", 1, true))
assert(last():find("\\u000a", 1, true))
step()
assert(last():find("select '2'", 1, true))
windows[1].focus_history_id = 0 -- Freeze order despite compositor updates.
release()
assert(last():find('address:0x3', 1, true))
windows[1].focus_history_id = 2
back()
assert(last():find('"index":2', 1, true))
bindings["ALT + ESCAPE"]()
assert(last():find(' hide', 1, true))
local count = #commands
release()
assert(#commands == count)
step()
table.remove(windows, 3) -- Closing the selected window must not crash or focus it.
release()
assert(last():find(' hide', 1, true))
step()
__altswitch_cancel()
assert(last():find(' hide', 1, true))
windows = { windows[1] }
count = #commands
step()
assert(#commands == count)
print("Alt-Tab: MRU, reverse, cancellation, closed windows, watchdog, and single-window checks passed")
