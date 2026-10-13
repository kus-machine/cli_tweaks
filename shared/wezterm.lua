-- ============================================================================
-- cli_tweaks -- WezTerm config (Windows + Ubuntu)
-- ----------------------------------------------------------------------------
-- Deployed to ~/.config/wezterm/wezterm.lua by
--   windows/install.ps1 -WezTerm        (Windows: the only terminal)
--   Ubuntu24/install.sh --wezterm       (Ubuntu: the alternative to
--                                        --alacritty, pick one or both)
-- Saved -> WezTerm reloads it by itself (no restart needed).
-- The few OS differences are under `if IS_WINDOWS` -- keep them few.
--
-- WezTerm replaces Alacritty + tmux: tabs and panes are built in, and the
-- keys mirror Ubuntu's tmux setup (Ubuntu24/configs/.tmux.conf). On Ubuntu
-- tmux stays installed (ssh, detach), WezTerm just does not start it:
--   Alt+1..9 / Alt+T / Alt+N / Alt+K   tabs, no prefix
--   Ctrl+B then a key                  the tmux keys (| - z x w ...)
--   Alt+\ Alt+- Alt+Z Alt+X            the everyday pane keys, no prefix
--
-- NO Ctrl+Shift bindings of our own: Ctrl+Shift switches the keyboard layout
-- on the owner's machine. Everything is on Alt+… or the Ctrl+B prefix.
-- (WezTerm's stock Ctrl+Shift+… defaults are still there, just not needed.)
--
-- Every binding uses PHYSICAL key positions, so it works the same with the
-- Ukrainian layout on -- no Cyrillic twins needed (unlike Alacritty/tmux).
--
-- Cheat sheet: Ctrl+B ?  or  `keys`. KEEP BOTH IN SYNC when a binding here
-- changes: Windows -- windows/keys.txt (deployed to
-- ~\.config\cli_tweaks\keys.txt); Ubuntu -- the WEZTERM section of `keys`
-- in Ubuntu24/configs/.bash_aliases.
-- ============================================================================

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local IS_WINDOWS = wezterm.target_triple:find('windows') ~= nil

-- ===========================================================================
-- Shell
-- ===========================================================================
config.default_cwd = wezterm.home_dir
if IS_WINDOWS then
  -- PowerShell 7 with the cli_tweaks profile (~\Documents\PowerShell\profile.ps1).
  local PWSH = { 'pwsh.exe', '-NoLogo' }
  config.default_prog = PWSH
  -- Ctrl+B l  -- launcher: other shells in a new tab. WSL distros show up
  -- there by themselves.
  config.launch_menu = {
    { label = 'PowerShell 7 (cli_tweaks)', args = PWSH },
    { label = 'Windows PowerShell 5.1',    args = { 'powershell.exe', '-NoLogo' } },
    { label = 'cmd',                       args = { 'cmd.exe' } },
  }
else
  -- No default_prog: WezTerm starts your login shell (bash, as a login
  -- shell -- like tmux does, see the bash-completion note in .bashrc).
  --
  -- The wezterm package drops a shell integration into /etc/profile.d. It
  -- hooks PROMPT_COMMAND and the DEBUG trap (bash-preexec) BEFORE ~/.bashrc
  -- loads ble.sh, and ble.sh wants to own both. Switched off here; .bashrc
  -- sends the prompt/output marks it would have sent (OSC 133) through
  -- ble.sh's own hooks instead. The cwd WezTerm reads from /proc.
  config.set_environment_variables = { WEZTERM_SHELL_SKIP_ALL = '1' }
  config.launch_menu = {
    { label = 'bash (cli_tweaks)',  args = { 'bash', '-l' } },
    { label = 'tmux (session main)', args = { 'tmux', 'new-session', '-A', '-s', 'main' } },
    { label = 'bash without ble.sh / cli_tweaks', args = { 'bash', '--norc', '--noprofile' } },
  }
end


-- ===========================================================================
-- Look
-- ===========================================================================
config.color_scheme = 'Tokyo Night'
config.font = wezterm.font('FiraCode Nerd Font')
config.font_size = 11.5
config.window_background_opacity = 0.9      -- Ctrl+B o toggles 0.9 <-> 1.0
-- Windows 11 blur behind the window -- prettier, a bit less readable:
-- config.win32_system_backdrop = 'Acrylic'
config.window_padding = { left = 12, right = 12, top = 12, bottom = 12 }
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 600
config.scrollback_lines = 50000
config.initial_cols = 120
config.initial_rows = 32

-- The pane you are NOT in is dimmed, so it is obvious where you type.
config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.65 }

-- A bell (e.g. Backspace on an empty line) flashes the screen instead of
-- beeping.
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_function = 'EaseIn', fade_in_duration_ms = 60,
  fade_out_function = 'EaseOut', fade_out_duration_ms = 120,
  target = 'CursorColor',
}

-- `alert` -> Windows toast / Ubuntu notify-send popup, even while focused.
config.notification_handling = 'AlwaysShow'

-- The normal Windows title bar with the normal _ □ X buttons, tabs right
-- under it. (WezTerm can also draw the buttons inside the tab bar --
-- 'INTEGRATED_BUTTONS|RESIZE' -- but with a Nerd Font they came out as a dot
-- and a dash.) Plain ("retro") tab bar so it is coloured exactly like tmux's.
config.window_decorations = 'TITLE|RESIZE'
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.show_new_tab_button_in_tab_bar = true
config.colors = {
  tab_bar = {
    background = '#16161e',
    active_tab = { bg_color = '#7aa2f7', fg_color = '#1a1b26' },
    inactive_tab = { bg_color = '#16161e', fg_color = '#a9b1d6' },
    inactive_tab_hover = { bg_color = '#283457', fg_color = '#c0caf5' },
    new_tab = { bg_color = '#16161e', fg_color = '#565f89' },
    new_tab_hover = { bg_color = '#283457', fg_color = '#c0caf5' },
  },
  visual_bell = '#283457',
}

-- Tab title = "N folder" while the shell is idle, "N program" while
-- something runs (btop, ssh, ...) -- the same rule as tmux's automatic-rename.
-- A title set with Alt+N wins.
local function basename(s) return (s:gsub('[/\\]+$', ''):match('([^/\\]+)$')) or s end
-- a path in one spelling: forward slashes, no trailing one, no "/" before
-- "C:" (file URLs have it), case-folded on Windows only
local function norm(p)
  p = p:gsub('\\', '/'):gsub('/+$', ''):gsub('^/(%a:)', '%1')
  return IS_WINDOWS and p:lower() or p
end
local SHELLS = { pwsh = true, powershell = true, cmd = true, bash = true, zsh = true, sh = true }
wezterm.on('format-tab-title', function(tab)
  local title = tab.tab_title
  if not title or title == '' then
    local pane = tab.active_pane
    local proc = basename(pane.foreground_process_name or ''):gsub('%.exe$', '')
    if proc == '' or SHELLS[proc] then
      local cwd = pane.current_working_dir
      title = cwd and basename(cwd.file_path or tostring(cwd)) or proc
      if cwd and norm(cwd.file_path or '') == norm(wezterm.home_dir) then
        title = '~'
      end
    else
      title = proc
    end
  end
  local zoom = tab.active_pane.is_zoomed and ' [z]' or ''
  return ' ' .. (tab.tab_index + 1) .. ' ' .. title .. zoom .. ' '
end)

-- Right end of the tab bar = the Ubuntu tmux hint line, squeezed into one row:
--   normally      : grey reminder of the tab/pane keys (+ workspace + clock)
--   after Ctrl+B  : yellow badge + the keys that may follow
--   resize mode   : magenta badge + how to leave it
--   after Ctrl+B y: green "copied N lines" for 2 s
-- Below 110 columns the texts get shorter so the tabs keep their room
-- (same rule as tmux's status-right on Ubuntu). The full list: Ctrl+B ?
local HINTS = {
  idle   = { 'Alt+T new tab · Alt+K close tab · Alt+\\ Alt+- split · Alt+X close pane · Ctrl+B ? all keys',
             'Ctrl+B ? all keys' },
  prefix = { 'then: | split right · - split below · z zoom · x close pane · Ctrl+← ↑ → ↓ resize · ? all keys',
             '| - split · z zoom · x close · ? keys' },
  resize = { '← ↑ → ↓ resize · Esc done', '← ↑ → ↓ · Esc' },
}
local flash = { text = nil, until_ = 0 }
wezterm.on('update-right-status', function(window)
  local tab = window:active_tab()
  local wide = (tab and tab:get_size().cols or 120) >= 110
  local function pick(h) return wide and h[1] or h[2] end
  local cells = {}
  local function badge(bg, text, hint)
    table.insert(cells, { Background = { Color = bg } })
    table.insert(cells, { Foreground = { Color = '#1a1b26' } })
    table.insert(cells, { Text = ' ' .. text .. ' ' })
    table.insert(cells, 'ResetAttributes')
    table.insert(cells, { Foreground = { Color = bg } })
    table.insert(cells, { Text = '  ' .. hint .. ' ' })
  end
  if window:leader_is_active() then
    badge('#e0af68', 'Ctrl+B …', pick(HINTS.prefix))
  elseif window:active_key_table() == 'resize' then
    badge('#bb9af7', 'RESIZE', pick(HINTS.resize))
  elseif flash.text and os.time() <= flash.until_ then
    badge('#9ece6a', 'OK', flash.text)
  else
    table.insert(cells, { Foreground = { Color = '#565f89' } })
    table.insert(cells, { Text = ' ' .. pick(HINTS.idle) .. '  ' })
    local ws = window:active_workspace()
    if ws ~= 'default' then
      table.insert(cells, { Foreground = { Color = '#bb9af7' } })
      table.insert(cells, { Text = ws .. ' · ' })
    end
    table.insert(cells, { Foreground = { Color = '#7aa2f7' } })
    table.insert(cells, { Text = wezterm.strftime('%H:%M ') })
  end
  window:set_right_status(wezterm.format(cells))
end)
config.status_update_interval = 1000

-- ===========================================================================
-- Keys
-- ===========================================================================
config.key_map_preference = 'Physical'

-- tmux-style prefix. Ctrl+B is "cursor left" in pwsh and bash -- nobody
-- misses it;
-- Ctrl+B Ctrl+B sends a real Ctrl+B through. 5 s to press the next key
-- (tmux itself waits forever; the yellow badge shows it is still armed).
config.leader = { key = 'phys:B', mods = 'CTRL', timeout_milliseconds = 5000 }

-- Overlays that put labels on screen (Ctrl+B q, Ctrl+B Space) use DIGITS:
-- they are the same on the Latin and the Ukrainian layout, so switching the
-- layout half-way does not matter.
config.quick_select_alphabet = '1234567890'
local DIGITS = '1234567890'

-- New tabs and splits open in the current folder and run the same shell.
-- A new tab shows the cat banner (like a new window); splits get
-- CLI_TWEAKS_BANNER=0 so a half-width pane is not filled with the cat.
local NO_BANNER = { CLI_TWEAKS_BANNER = '0' }
local NEW_TAB = act.SpawnCommandInNewTab { domain = 'CurrentPaneDomain' }
local SPLIT_R = act.SplitHorizontal { domain = 'CurrentPaneDomain', set_environment_variables = NO_BANNER }
local SPLIT_D = act.SplitVertical { domain = 'CurrentPaneDomain', set_environment_variables = NO_BANNER }
-- the "+" in the tab bar: same as Alt+T (right-click on it = launcher)
wezterm.on('new-tab-button-click', function(window, pane, button)
  if button == 'Left' then
    window:perform_action(NEW_TAB, pane)
    return false
  end
end)
local RESIZE_MODE = act.ActivateKeyTable { name = 'resize', one_shot = false, timeout_milliseconds = 3000 }

-- Ctrl+B ?: the full cheatsheet in a new tab; q closes it. `keys` comes from
-- the pwsh profile / ~/.bash_aliases; no banner in that tab.
local SHOW_KEYS = act.SpawnCommandInNewTab {
  args = IS_WINDOWS and { 'pwsh.exe', '-NoLogo', '-Command', 'keys -Stay' }
                     or { 'bash', '-c', '. ~/.bash_aliases && keys --stay' },
  set_environment_variables = NO_BANNER,
}

-- Ctrl+B y: copy the output of the last finished command. Needs the
-- OSC 133;C mark the shell sends on Enter (pwsh profile; on Ubuntu .bashrc
-- through ble.sh -- without ble.sh there are no marks and this finds nothing).
local copy_last_output = wezterm.action_callback(function(window, pane)
  local zones = pane:get_semantic_zones('Output')
  for i = #zones, 1, -1 do
    local text = pane:get_text_from_semantic_zone(zones[i]):gsub('%s+$', '')
    if text ~= '' then
      window:copy_to_clipboard(text, 'Clipboard')
      local _, n = text:gsub('\n', '')
      flash.text, flash.until_ = 'copied ' .. (n + 1) .. ' line(s) of output', os.time() + 2
      return
    end
  end
  flash.text, flash.until_ = 'no command output found', os.time() + 2
end)

-- Ctrl+B o: toggle opacity 0.9 <-> 1.0 (for reading over a busy desktop)
local toggle_opacity = wezterm.action_callback(function(window)
  local o = window:get_config_overrides() or {}
  o.window_background_opacity = (o.window_background_opacity == 1.0) and 0.9 or 1.0
  window:set_config_overrides(o)
end)

-- Ctrl+C: copy if something is selected, otherwise the usual Ctrl+C
-- (interrupt). Ctrl+V: paste. The Windows habit, since Ctrl+Shift+C/V would
-- flip the keyboard layout there. (WezTerm's own Ctrl+Shift+C/V still work,
-- Ubuntu's terminal habit. bash's Ctrl+V = "insert next key verbatim" is
-- what this costs.)
local smart_copy = wezterm.action_callback(function(window, pane)
  local sel = window:get_selection_text_for_pane(pane)
  if sel ~= '' then
    window:perform_action(act.CopyTo 'Clipboard', pane)
    window:perform_action(act.ClearSelection, pane)
  else
    window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
  end
end)

local keys = {
  { key = 'phys:B', mods = 'LEADER|CTRL', action = act.SendKey { key = 'b', mods = 'CTRL' } },

  -- --- copy / paste ---------------------------------------------------------
  { key = 'phys:C', mods = 'CTRL', action = smart_copy },
  { key = 'phys:V', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  { key = 'phys:Y', mods = 'LEADER', action = copy_last_output },
  { key = 'phys:LeftBracket', mods = 'LEADER', action = act.ActivateCopyMode },

  -- --- tabs, no prefix (Ubuntu: tmux root bindings) -------------------------
  { key = 'phys:T', mods = 'ALT', action = NEW_TAB },
  { key = 'phys:K', mods = 'ALT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'phys:N', mods = 'ALT', action = act.PromptInputLine {
      description = 'tab name (empty = automatic):',
      action = wezterm.action_callback(function(window, _, line)
        if line then window:active_tab():set_title(line) end
      end),
  } },
  -- tabs with the prefix, tmux letters
  { key = 'phys:C', mods = 'LEADER', action = NEW_TAB },
  { key = 'phys:N', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'phys:P', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  { key = 'phys:W', mods = 'LEADER', action = act.ShowTabNavigator },
  { key = 'phys:Comma',  mods = 'LEADER|SHIFT', action = act.MoveTabRelative(-1) },  -- <
  { key = 'phys:Period', mods = 'LEADER|SHIFT', action = act.MoveTabRelative(1) },   -- >

  -- --- panes ----------------------------------------------------------------
  -- the everyday ones directly on Alt (no prefix) ...
  { key = 'phys:Backslash', mods = 'ALT', action = SPLIT_R },             -- Alt+\  split right
  { key = 'phys:Minus',     mods = 'ALT', action = SPLIT_D },             -- Alt+-  split below
  { key = 'phys:Z', mods = 'ALT', action = act.TogglePaneZoomState },
  { key = 'phys:X', mods = 'ALT', action = act.CloseCurrentPane { confirm = true } },
  { key = 'LeftArrow',  mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Left', 3 } },
  { key = 'RightArrow', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Right', 3 } },
  { key = 'UpArrow',    mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Up', 2 } },
  { key = 'DownArrow',  mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Down', 2 } },
  -- ... and all of them also tmux-style after Ctrl+B
  { key = 'LeftArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'phys:Backslash', mods = 'LEADER|SHIFT', action = SPLIT_R },  -- |
  { key = 'phys:Backslash', mods = 'LEADER',       action = SPLIT_R },  -- \  (same key, no Shift)
  { key = 'phys:5',         mods = 'LEADER|SHIFT', action = SPLIT_R },  -- %
  { key = 'phys:Minus',     mods = 'LEADER',       action = SPLIT_D },  -- -
  { key = 'phys:Quote',     mods = 'LEADER|SHIFT', action = SPLIT_D },  -- "
  { key = 'phys:Z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'phys:X', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  -- numbers appear on every pane: press one to jump there / swap with it
  { key = 'phys:Q', mods = 'LEADER', action = act.PaneSelect { alphabet = DIGITS } },
  { key = 'phys:LeftBracket', mods = 'LEADER|SHIFT', action = act.PaneSelect { mode = 'SwapWithActive', alphabet = DIGITS } }, -- {
  -- ! = move this pane out into its own tab (tmux break-pane)
  { key = 'phys:1', mods = 'LEADER|SHIFT', action = wezterm.action_callback(function(_, pane) pane:move_to_new_tab() end) },
  -- resize: Ctrl+B Ctrl+arrow, then keep pressing arrows
  { key = 'LeftArrow',  mods = 'LEADER|CTRL', action = act.Multiple { act.AdjustPaneSize { 'Left', 3 },  RESIZE_MODE } },
  { key = 'RightArrow', mods = 'LEADER|CTRL', action = act.Multiple { act.AdjustPaneSize { 'Right', 3 }, RESIZE_MODE } },
  { key = 'UpArrow',    mods = 'LEADER|CTRL', action = act.Multiple { act.AdjustPaneSize { 'Up', 2 },    RESIZE_MODE } },
  { key = 'DownArrow',  mods = 'LEADER|CTRL', action = act.Multiple { act.AdjustPaneSize { 'Down', 2 },  RESIZE_MODE } },

  -- --- find things on screen ------------------------------------------------
  -- Space: numbers over every hash / path / URL / IP on screen;
  --        type one -> copied
  { key = 'Space', mods = 'LEADER', action = act.QuickSelect },
  -- u: same, but only URLs, and the picked one opens in the browser
  { key = 'phys:U', mods = 'LEADER', action = act.QuickSelectArgs {
      label = 'open url',
      patterns = { 'https?://\\S+' },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        wezterm.open_with(url)
      end),
  } },
  { key = 'phys:Slash', mods = 'LEADER', action = act.Search { CaseInSensitiveString = '' } },

  -- --- scrolling ------------------------------------------------------------
  { key = 'PageUp',   mods = 'SHIFT', action = act.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT', action = act.ScrollByPage(1) },
  -- jump between commands (OSC 133 prompt marks, see Ctrl+B y)
  { key = 'PageUp',   mods = 'ALT', action = act.ScrollToPrompt(-1) },
  { key = 'PageDown', mods = 'ALT', action = act.ScrollToPrompt(1) },

  -- --- window, workspaces, misc --------------------------------------------
  { key = 'phys:O', mods = 'LEADER', action = toggle_opacity },
  { key = 'phys:L', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS|DOMAINS' } },
  { key = 'phys:Semicolon', mods = 'LEADER|SHIFT', action = act.ActivateCommandPalette },  -- :
  { key = 'phys:Slash', mods = 'LEADER|SHIFT', action = SHOW_KEYS },  -- ?
  { key = 'phys:R', mods = 'LEADER', action = act.ReloadConfiguration },
  -- workspaces = tmux sessions: a named set of tabs; switch between sets
  { key = 'phys:S', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  { key = 'phys:S', mods = 'LEADER|SHIFT', action = act.PromptInputLine {
      description = 'new workspace name:',
      action = wezterm.action_callback(function(window, pane, line)
        if line and line ~= '' then
          window:perform_action(act.SwitchToWorkspace { name = line }, pane)
        end
      end),
  } },
  { key = 'phys:4', mods = 'LEADER|SHIFT', action = act.PromptInputLine {  -- $
      description = 'rename workspace:',
      action = wezterm.action_callback(function(_, _, line)
        if line and line ~= '' then
          wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
        end
      end),
  } },
}
for i = 1, 9 do
  table.insert(keys, { key = 'phys:' .. i, mods = 'ALT', action = act.ActivateTab(i - 1) })
end

-- Linux + the Ukrainian layout: Ctrl+R typed as Ctrl+К must still reach bash
-- as Ctrl+R (and Alt+C as Alt+C, for fzf). Windows' console does that on its
-- own; on Linux WezTerm would send the Cyrillic letter. So every Ctrl+letter
-- and Alt+letter that is not bound above is sent by its PHYSICAL key -- the
-- WezTerm twin of the generated Ukrainian block in shared/alacritty.toml.
if not IS_WINDOWS then
  local taken = { ['CTRL phys:B'] = true }   -- the leader is not in `keys`
  for _, k in ipairs(keys) do taken[k.mods .. ' ' .. k.key] = true end
  for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):gmatch('.') do
    for _, m in ipairs { 'CTRL', 'ALT' } do
      if not taken[m .. ' phys:' .. c] then
        table.insert(keys, { key = 'phys:' .. c, mods = m,
                             action = act.SendKey { key = c:lower(), mods = m } })
      end
    end
  end
end
config.keys = keys

local function resize_keys()
  local t = {}
  for _, m in ipairs { 'NONE', 'CTRL' } do
    table.insert(t, { key = 'LeftArrow',  mods = m, action = act.AdjustPaneSize { 'Left', 3 } })
    table.insert(t, { key = 'RightArrow', mods = m, action = act.AdjustPaneSize { 'Right', 3 } })
    table.insert(t, { key = 'UpArrow',    mods = m, action = act.AdjustPaneSize { 'Up', 2 } })
    table.insert(t, { key = 'DownArrow',  mods = m, action = act.AdjustPaneSize { 'Down', 2 } })
  end
  table.insert(t, { key = 'Escape', action = 'PopKeyTable' })
  return t
end
config.key_tables = { resize = resize_keys() }

-- ===========================================================================
-- Mouse
-- ===========================================================================
--   drag / 2x / 3x click   select (copied right away) · word · line
--   4x click               the whole output of that one command
--   Ctrl+click             open a link (a plain click only selects)
--   right click            paste
--   Ctrl+wheel             font size
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection' },
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor },
  { event = { Down = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.Nop },
  { event = { Down = { streak = 4, button = 'Left' } }, mods = 'NONE',
    action = act.SelectTextAtMouseCursor 'SemanticZone' },
  { event = { Up = { streak = 4, button = 'Left' } }, mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection' },
  { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE',
    action = act.PasteFrom 'Clipboard' },
  { event = { Down = { streak = 1, button = { WheelUp = 1 } } }, mods = 'CTRL',
    action = act.IncreaseFontSize },
  { event = { Down = { streak = 1, button = { WheelDown = 1 } } }, mods = 'CTRL',
    action = act.DecreaseFontSize },
}

return config
