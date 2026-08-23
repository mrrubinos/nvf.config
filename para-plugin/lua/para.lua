-- PARA Method note, task and log management.
--
-- A project, area or resource is a directory under its category root holding
-- an optional page (<slug>/<slug>.md), a notes/ directory and its own log.md.
-- Subdirectories are created the first time something goes in them, so the
-- layout matches whatever the store actually holds.

local M = {}

M.config = {
  base_path = vim.fn.expand("~/Documents/PARA"),
  log_file = nil,
  log_archive_dir = nil,
  tasks_file = nil,
  tasks_archive_file = nil,
  date_format = "%Y-%m-%d",
  time_format = "%H:%M",
  datetime_format = "%Y-%m-%d %H:%M:%S",
  archive_dir = "4_archive",
  categories = {
    project  = { dir = "1_projects",  label = "Project",  plural = "Projects",  order = 1 },
    area     = { dir = "2_areas",     label = "Area",     plural = "Areas",     order = 2 },
    resource = { dir = "3_resources", label = "Resource", plural = "Resources", order = 3 },
  },
  keymaps = {
    menu = "<leader>pp",
    find_entity = "<leader>pf",
    new_entity = "<leader>pN",
    new_note = "<leader>pc",
    projects = "<leader>pP",
    areas = "<leader>pA",
    resources = "<leader>pR",
    entity_log = "<leader>pe",
    archive_entity = "<leader>px",
    open_log = "<leader>pl",
    add_log = "<leader>pla",
    archive_log = "<leader>plx",
    insert_log_template = "<leader>pli",
    open_tasks = "<leader>pt",
    add_task = "<leader>pta",
    archive_done_tasks = "<leader>ptx",
    insert_task_template = "<leader>pti",
    toggle_task = "<leader>tt",
    search_by_name = "<leader>pn",
    search_by_content = "<leader>ps",
    stats = "<leader>pS",
  },
  priority_order = {
    A = "Critical",
    B = "High",
    C = "Normal",
    D = "Low",
    E = "Someday",
  },
}

local CATEGORY_ORDER = { "project", "area", "resource" }

-- ── Utilities ───────────────────────────────────────────────────────────────

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "PARA" })
end

local function ensure_directory(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

local function ensure_file(path, initial_content)
  if vim.fn.filereadable(path) == 0 then
    ensure_directory(vim.fn.fnamemodify(path, ":h"))
    local file = io.open(path, "w")
    if file then
      file:write(initial_content or "")
      file:close()
    end
  end
end

local function read_lines(path)
  local lines = {}
  local file = io.open(path, "r")
  if not file then return lines end
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()
  return lines
end

local function write_lines(path, lines)
  ensure_directory(vim.fn.fnamemodify(path, ":h"))
  local file = io.open(path, "w")
  if not file then return false end
  for _, line in ipairs(lines) do
    file:write(line .. "\n")
  end
  file:close()
  return true
end

local function append_line(path, line)
  local file = io.open(path, "a")
  if not file then return false end
  file:write(line .. "\n")
  file:close()
  return true
end

local function now() return os.date(M.config.datetime_format) end
local function today() return os.date(M.config.date_format) end

local function slugify(text)
  local slug = tostring(text):lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  return slug
end

local function titlecase(slug)
  return (slug:gsub("%-", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

local function category_of(name)
  return M.config.categories[name]
end

-- Reload the buffer holding path when it is already open, otherwise open it.
local function open_file(path)
  ensure_directory(vim.fn.fnamemodify(path, ":h"))
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function refresh_or_open(path, goto_end)
  local bufnr = vim.fn.bufnr(path)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("edit!")
      if goto_end then vim.cmd("normal! G") end
    end)
  else
    open_file(path)
    if goto_end then vim.cmd("normal! G") end
  end
end

-- ── Paths ───────────────────────────────────────────────────────────────────

local function category_root(category)
  return M.config.base_path .. "/" .. category_of(category).dir
end

local function archive_root()
  return M.config.base_path .. "/" .. M.config.archive_dir
end

local function entity_dir(category, slug)
  return category_root(category) .. "/" .. slug
end

local function entity_page(category, slug)
  return entity_dir(category, slug) .. "/" .. slug .. ".md"
end

local function entity_notes_dir(category, slug)
  return entity_dir(category, slug) .. "/notes"
end

local function entity_log(category, slug)
  return entity_dir(category, slug) .. "/log.md"
end

local function entity_log_archive(category, slug)
  return entity_dir(category, slug) .. "/logs/archive"
end

-- A flat <slug>.md from the old layout becomes <slug>/<slug>.md, so that
-- notes/ and log.md have somewhere to live.
local function promote_entity(category, slug)
  local root = category_root(category)
  local flat = root .. "/" .. slug .. ".md"
  local dir = root .. "/" .. slug
  if vim.fn.filereadable(flat) == 1 and vim.fn.isdirectory(dir) == 0 then
    ensure_directory(dir)
    vim.fn.rename(flat, dir .. "/" .. slug .. ".md")
  end
  ensure_directory(dir)
end

function M.init_directories()
  ensure_directory(M.config.base_path)
  ensure_directory(M.config.log_archive_dir)
  for _, name in ipairs(CATEGORY_ORDER) do
    ensure_directory(category_root(name))
  end
  ensure_directory(archive_root())
  ensure_file(M.config.log_file, "# Log\nCreated: " .. now() .. "\n\n")
  ensure_file(M.config.tasks_file, "# Tasks\nCreated: " .. now() .. "\n\n")
end

-- ── Listing ─────────────────────────────────────────────────────────────────

--- Slugs of every entity in a category, directories and legacy flat files.
function M.entities(category)
  local root = category_root(category)
  local seen, out = {}, {}
  for _, dir in ipairs(vim.fn.glob(root .. "/*/", false, true)) do
    local slug = vim.fn.fnamemodify(dir:sub(1, -2), ":t")
    if not seen[slug] then
      seen[slug] = true
      table.insert(out, slug)
    end
  end
  for _, file in ipairs(vim.fn.glob(root .. "/*.md", false, true)) do
    local slug = vim.fn.fnamemodify(file, ":t:r")
    if not seen[slug] then
      seen[slug] = true
      table.insert(out, slug)
    end
  end
  table.sort(out)
  return out
end

function M.notes_of(category, slug)
  local dir = entity_notes_dir(category, slug)
  local out = {}
  for _, file in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
    table.insert(out, { name = vim.fn.fnamemodify(file, ":t:r"), path = file })
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

local function count_notes(category, slug)
  return #M.notes_of(category, slug)
end

local function count_log_entries(category, slug)
  local path = entity_log(category, slug)
  if vim.fn.filereadable(path) == 0 then return 0 end
  local n = 0
  for _, line in ipairs(read_lines(path)) do
    if line:match("^%d%d%d%d%-%d%d%-%d%d") then n = n + 1 end
  end
  return n
end

local function page_field(category, slug, field)
  local path = entity_page(category, slug)
  if vim.fn.filereadable(path) == 0 then return nil end
  for _, line in ipairs(read_lines(path)) do
    local value = line:match("^" .. field .. ":%s*(.+)$")
    if value then return value end
  end
  return nil
end

local function plural(word, n)
  if n == 1 then return word end
  if word == "entry" then return "entries" end
  return word .. "s"
end

local function entity_summary(category, slug)
  local notes = count_notes(category, slug)
  local logs = count_log_entries(category, slug)
  local parts = {}
  local status = page_field(category, slug, "Status")
  if status then table.insert(parts, status) end
  table.insert(parts, notes .. " " .. plural("note", notes))
  table.insert(parts, logs .. " log " .. plural("entry", logs))
  if vim.fn.filereadable(entity_page(category, slug)) == 0 then
    table.insert(parts, "no page")
  end
  return table.concat(parts, " | ")
end

-- ── Pickers ─────────────────────────────────────────────────────────────────

--- Choose one of entries ({ display, value }) and pass its value to on_choice.
local function pick(title, entries, on_choice)
  if #entries == 0 then
    notify("Nothing to choose from", vim.log.levels.WARN)
    return
  end

  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_conf, telescope_conf = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")

  if ok_pickers and ok_finders and ok_conf and ok_actions and ok_state then
    pickers.new({}, {
      prompt_title = title,
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return { value = entry.value, display = entry.display, ordinal = entry.display }
        end,
      }),
      sorter = telescope_conf.values.generic_sorter({}),
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(bufnr)
          if selection then on_choice(selection.value) end
        end)
        return true
      end,
    }):find()
    return
  end

  local displays = {}
  for _, entry in ipairs(entries) do
    table.insert(displays, entry.display)
  end
  vim.ui.select(displays, { prompt = title }, function(_, idx)
    if idx then on_choice(entries[idx].value) end
  end)
end

--- Show a menu of { label, fn } pairs.
local function menu(title, items)
  local entries = {}
  for _, item in ipairs(items) do
    table.insert(entries, { display = item[1], value = item[2] })
  end
  pick(title, entries, function(fn)
    if type(fn) == "function" then fn() end
  end)
end

local function ask(prompt, default, on_done)
  vim.ui.input({ prompt = prompt, default = default }, function(input)
    if input and input ~= "" then on_done(input) end
  end)
end

--- Pick an entity of a category. Offers creation when the category is empty.
function M.pick_entity(category, prompt, on_choice)
  local cat = category_of(category)
  local slugs = M.entities(category)
  if #slugs == 0 then
    ask("No " .. cat.plural:lower() .. " yet. New " .. cat.label .. " name: ", nil, function(name)
      M.create_entity(category, name, { open = false, on_done = on_choice })
    end)
    return
  end
  local entries = {}
  for _, slug in ipairs(slugs) do
    table.insert(entries, {
      display = string.format("%-28s %s", slug, entity_summary(category, slug)),
      value = slug,
    })
  end
  pick(prompt or (cat.label .. ":"), entries, on_choice)
end

--- Pick any entity across every category. Passes (category, slug).
function M.pick_any_entity(prompt, on_choice)
  local entries = {}
  for _, category in ipairs(CATEGORY_ORDER) do
    local cat = category_of(category)
    for _, slug in ipairs(M.entities(category)) do
      table.insert(entries, {
        display = string.format("%-9s %-28s %s", cat.label, slug, entity_summary(category, slug)),
        value = { category = category, slug = slug },
      })
    end
  end
  if #entries == 0 then
    notify("No projects, areas or resources yet", vim.log.levels.WARN)
    return
  end
  pick(prompt or "PARA:", entries, function(value)
    on_choice(value.category, value.slug)
  end)
end

local function pick_category(prompt, on_choice)
  local entries = {}
  for _, name in ipairs(CATEGORY_ORDER) do
    table.insert(entries, { display = category_of(name).label, value = name })
  end
  pick(prompt or "Category:", entries, on_choice)
end

-- ── Templates ───────────────────────────────────────────────────────────────

local function page_template(category, name)
  local stamp = now()
  if category == "project" then
    return table.concat({
      "# Project: " .. name, "",
      "Created: " .. stamp,
      "Status: Active",
      "Due:",
      "Priority: Normal", "",
      "## Objective", "",
      "## Success criteria", "",
      "## Tasks",
      "- [ ]", "",
      "## Notes", "",
      "## Resources", "",
      "## Retrospective",
    }, "\n")
  elseif category == "area" then
    return table.concat({
      "# Area: " .. name, "",
      "Created: " .. stamp,
      "Status: Active", "",
      "## Overview", "",
      "## Responsibilities", "",
      "## Standards", "",
      "## Recurring tasks",
      "- [ ]", "",
      "## Notes", "",
      "## Resources",
    }, "\n")
  end
  return table.concat({
    "# Resource: " .. name, "",
    "Created: " .. stamp,
    "Source:",
    "Tags:", "",
    "## Summary", "",
    "## Content", "",
    "## References",
  }, "\n")
end

local function note_template(title, category, parent)
  return table.concat({
    "# " .. title, "",
    "Created: " .. now(),
    "Category: " .. category_of(category).label,
    "Parent: " .. parent,
    "Tags:", "",
    "---", "",
    "## Summary", "",
    "## Content", "",
    "## References",
  }, "\n")
end

-- ── Entities ────────────────────────────────────────────────────────────────

--- Create a project, area or resource. opts: { bare, open, on_done }.
function M.create_entity(category, name, opts)
  opts = opts or {}
  local cat = category_of(category)

  local function build(chosen_name)
    local slug = slugify(chosen_name)
    if slug == "" then
      notify("Name produces an empty slug: " .. chosen_name, vim.log.levels.ERROR)
      return
    end
    local dir = entity_dir(category, slug)
    local page = entity_page(category, slug)
    local existed = vim.fn.isdirectory(dir) == 1
    ensure_directory(dir)
    if not opts.bare and vim.fn.filereadable(page) == 0 then
      write_lines(page, vim.split(page_template(category, titlecase(slug)), "\n"))
    end
    if existed then
      notify(cat.label .. " already exists: " .. slug, vim.log.levels.WARN)
    else
      notify(cat.label .. " created: " .. slug)
    end
    if opts.open ~= false then
      if vim.fn.filereadable(page) == 1 then open_file(page) end
    end
    if opts.on_done then opts.on_done(slug) end
  end

  if name and name ~= "" then
    build(name)
  else
    ask("New " .. cat.label .. " name: ", nil, build)
  end
end

--- Open an entity page, or pick among its files when it has no page.
function M.open_entity(category, slug)
  local function open(chosen)
    promote_entity(category, chosen)
    local page = entity_page(category, chosen)
    if vim.fn.filereadable(page) == 1 then
      open_file(page)
      return
    end
    local files = vim.fn.glob(entity_dir(category, chosen) .. "/**/*.md", false, true)
    if #files == 0 then
      write_lines(page, vim.split(page_template(category, titlecase(chosen)), "\n"))
      open_file(page)
      return
    end
    local root = entity_dir(category, chosen) .. "/"
    local entries = {}
    for _, file in ipairs(files) do
      table.insert(entries, { display = file:gsub("^" .. vim.pesc(root), ""), value = file })
    end
    pick("Open in " .. chosen .. ":", entries, open_file)
  end

  if slug then open(slug) else M.pick_entity(category, nil, open) end
end

--- Create a note inside an entity of a category.
function M.create_note_in(category, slug, title)
  local function build(chosen_slug, chosen_title)
    promote_entity(category, chosen_slug)
    local dir = entity_notes_dir(category, chosen_slug)
    ensure_directory(dir)
    local path = dir .. "/" .. slugify(chosen_title) .. ".md"
    if vim.fn.filereadable(path) == 1 then
      notify("Note already exists: " .. path, vim.log.levels.WARN)
    else
      write_lines(path, vim.split(note_template(chosen_title, category, chosen_slug), "\n"))
      notify("Note created in " .. chosen_slug)
    end
    open_file(path)
  end

  local function with_slug(chosen_slug)
    if title and title ~= "" then
      build(chosen_slug, title)
    else
      ask("Note title: ", nil, function(input) build(chosen_slug, input) end)
    end
  end

  if slug then with_slug(slug) else M.pick_entity(category, nil, with_slug) end
end

--- Pick a category, then an entity, then create a note in it.
function M.create_note()
  pick_category("Note in which category?", function(category)
    M.create_note_in(category)
  end)
end

--- List the notes of an entity and open the chosen one.
function M.browse_notes(category, slug)
  local function browse(chosen)
    local notes = M.notes_of(category, chosen)
    if #notes == 0 then
      notify("No notes in " .. chosen .. " yet", vim.log.levels.WARN)
      return
    end
    local entries = {}
    for _, note in ipairs(notes) do
      table.insert(entries, { display = note.name, value = note.path })
    end
    pick("Notes in " .. chosen .. ":", entries, open_file)
  end

  if slug then browse(slug) else M.pick_entity(category, nil, browse) end
end

--- List every entity of a category and open the chosen one.
function M.list_entities(category)
  local cat = category_of(category)
  local slugs = M.entities(category)
  if #slugs == 0 then
    notify("No " .. cat.plural:lower() .. " yet", vim.log.levels.WARN)
    return
  end
  M.pick_entity(category, cat.plural .. ":", function(slug)
    M.open_entity(category, slug)
  end)
end

--- Move a whole entity directory into the archive.
function M.archive_entity(category, slug)
  local function archive(chosen)
    promote_entity(category, chosen)
    local src = entity_dir(category, chosen)
    local dst = archive_root() .. "/" .. chosen
    if vim.fn.isdirectory(dst) == 1 or vim.fn.filereadable(dst) == 1 then
      dst = archive_root() .. "/" .. chosen .. "_" .. os.date("%Y%m%d_%H%M%S")
    end
    ensure_directory(archive_root())
    if vim.fn.rename(src, dst) == 0 then
      notify("Archived " .. chosen .. " to " .. dst)
    else
      notify("Could not archive " .. chosen, vim.log.levels.ERROR)
    end
  end

  local function confirm(chosen)
    pick("Archive " .. chosen .. "?", {
      { display = "No", value = false },
      { display = "Yes, archive it", value = true },
    }, function(yes) if yes then archive(chosen) end end)
  end

  if slug then confirm(slug) else M.pick_entity(category, "Archive:", confirm) end
end

function M.archive_any_entity()
  M.pick_any_entity("Archive:", function(category, slug)
    M.archive_entity(category, slug)
  end)
end

-- ── Log ─────────────────────────────────────────────────────────────────────

local function log_target(category, slug)
  if not category then
    return {
      path = M.config.log_file,
      archive = M.config.log_archive_dir,
      label = "global",
    }
  end
  promote_entity(category, slug)
  return {
    path = entity_log(category, slug),
    archive = entity_log_archive(category, slug),
    label = category_of(category).label:lower() .. " " .. slug,
  }
end

local function append_log(target, text)
  ensure_file(target.path, "# Log\nCreated: " .. now() .. "\n\n")
  append_line(target.path, now() .. " - " .. text)
  notify("Log entry added to " .. target.label)
end

function M.open_log()
  ensure_file(M.config.log_file, "# Log\nCreated: " .. now() .. "\n\n")
  refresh_or_open(M.config.log_file, true)
end

function M.add_log_entry()
  ask("Log entry: ", nil, function(text)
    local target = log_target(nil, nil)
    append_log(target, text)
    refresh_or_open(target.path, true)
  end)
end

--- Append to the log of a project, area or resource.
function M.add_entity_log_entry()
  M.pick_any_entity("Log entry for:", function(category, slug)
    ask("Log entry: ", nil, function(text)
      local target = log_target(category, slug)
      append_log(target, text)
    end)
  end)
end

function M.open_entity_log(category, slug)
  local function open(chosen)
    local target = log_target(category, chosen)
    ensure_file(target.path, "# Log\nCreated: " .. now() .. "\n\n")
    refresh_or_open(target.path, true)
  end
  if slug then open(slug) else M.pick_entity(category, "Open log of:", open) end
end

local function archive_log_file(target)
  ask("Archive entries before date (YYYY-MM-DD): ", today(), function(cutoff)
    if not cutoff:match("^%d%d%d%d%-%d%d%-%d%d$") then
      notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
      return
    end
    if vim.fn.filereadable(target.path) == 0 then
      notify("No log for " .. target.label, vim.log.levels.ERROR)
      return
    end

    local keep, moved = {}, {}
    for _, line in ipairs(read_lines(target.path)) do
      local stamp = line:match("^(%d%d%d%d%-%d%d%-%d%d)")
      if stamp and stamp < cutoff then
        table.insert(moved, line)
      else
        table.insert(keep, line)
      end
    end

    if #moved == 0 then
      notify("No entries before " .. cutoff .. " in " .. target.label)
      return
    end

    ensure_directory(target.archive)
    local path = string.format("%s/log_archive_%s.md", target.archive, os.date("%Y%m%d_%H%M%S"))
    local header = {
      "# Archived Log Entries",
      "Archived: " .. now(),
      "Source: " .. target.label,
      "Entries before: " .. cutoff,
      "",
    }
    write_lines(path, vim.list_extend(header, moved))
    write_lines(target.path, keep)
    notify(string.format("Archived %d %s from %s", #moved, plural("entry", #moved), target.label))
    refresh_or_open(target.path, true)
  end)
end

function M.archive_log()
  archive_log_file(log_target(nil, nil))
end

function M.archive_entity_log()
  M.pick_any_entity("Archive log of:", function(category, slug)
    archive_log_file(log_target(category, slug))
  end)
end

function M.insert_log_template()
  local template = now() .. " - "
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_set_current_line(line:sub(1, col) .. template .. line:sub(col + 1))
  vim.api.nvim_win_set_cursor(0, { row, col + #template })
  vim.cmd("startinsert!")
end

-- ── Tasks ───────────────────────────────────────────────────────────────────

local function priority_entries()
  local keys = {}
  for key in pairs(M.config.priority_order) do
    table.insert(keys, key)
  end
  table.sort(keys)
  local entries = {}
  for _, key in ipairs(keys) do
    table.insert(entries, { display = key .. " - " .. M.config.priority_order[key], value = key })
  end
  return entries
end

local function is_task(line)
  return line:match("^%[%w%] %- %[[ x]%]") ~= nil or line:match("^%- %[[ x]%]") ~= nil
end

local function sort_tasks_in_file()
  local header, tasks = {}, {}
  local in_header = true
  for _, line in ipairs(read_lines(M.config.tasks_file)) do
    if in_header and is_task(line) then in_header = false end
    if in_header then
      table.insert(header, line)
    elseif line ~= "" then
      table.insert(tasks, line)
    end
  end
  table.sort(tasks)
  write_lines(M.config.tasks_file, vim.list_extend(header, tasks))
end

function M.open_tasks()
  ensure_file(M.config.tasks_file, "# Tasks\nCreated: " .. now() .. "\n\n")
  refresh_or_open(M.config.tasks_file, false)
end

function M.add_task_to_file(task_line)
  ensure_file(M.config.tasks_file, "# Tasks\nCreated: " .. now() .. "\n\n")
  append_line(M.config.tasks_file, task_line)
  sort_tasks_in_file()
  refresh_or_open(M.config.tasks_file, false)
  notify("Task added")
end

local function build_task_line(priority, description, link)
  local line
  if priority == "C" then
    line = "- [ ] " .. description
  else
    line = string.format("[%s] - [ ] %s", priority, description)
  end
  if link then line = line .. " (" .. link .. ")" end
  return line
end

--- Add a task. When link_to is true, also ask which entity it belongs to.
function M.add_task(link_to)
  ask("Task description: ", nil, function(description)
    pick("Priority:", priority_entries(), function(priority)
      if not link_to then
        M.add_task_to_file(build_task_line(priority, description, nil))
        return
      end
      M.pick_any_entity("Link task to:", function(category, slug)
        M.add_task_to_file(build_task_line(priority, description, category .. " " .. slug))
      end)
    end)
  end)
end

function M.add_linked_task()
  M.add_task(true)
end

function M.archive_done_tasks()
  if vim.fn.filereadable(M.config.tasks_file) == 0 then
    notify("Tasks file not found", vim.log.levels.ERROR)
    return
  end
  local active, done = {}, {}
  for _, line in ipairs(read_lines(M.config.tasks_file)) do
    if line:match("%[x%]") then
      table.insert(done, line)
    else
      table.insert(active, line)
    end
  end
  if #done == 0 then
    notify("No completed tasks to archive")
    return
  end
  ensure_file(M.config.tasks_archive_file, "# Archived Tasks\n\n")
  append_line(M.config.tasks_archive_file, "\n## Archived on " .. now())
  for _, line in ipairs(done) do
    append_line(M.config.tasks_archive_file, line)
  end
  write_lines(M.config.tasks_file, active)
  notify(string.format("Archived %d completed %s", #done, plural("task", #done)))
  refresh_or_open(M.config.tasks_file, false)
end

function M.toggle_task()
  local line = vim.api.nvim_get_current_line()
  local new_line
  if line:match("%- %[ %]") then
    new_line = line:gsub("%- %[ %]", "- [x]", 1)
  elseif line:match("%- %[x%]") then
    new_line = line:gsub("%- %[x%]", "- [ ]", 1)
  else
    return
  end
  vim.api.nvim_set_current_line(new_line)
  if vim.fn.expand("%:p") == M.config.tasks_file then
    vim.cmd("silent write")
    sort_tasks_in_file()
    vim.cmd("edit!")
  end
end

function M.insert_task_template()
  pick("Priority:", priority_entries(), function(priority)
    local template = priority == "C" and "- [ ] " or string.format("[%s] - [ ] ", priority)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    vim.api.nvim_set_current_line(line:sub(1, col) .. template .. line:sub(col + 1))
    vim.api.nvim_win_set_cursor(0, { row, col + #template })
    vim.cmd("startinsert!")
  end)
end

--- Show tasks in a picker. filter: nil, "open", "done", or an entity link.
function M.list_tasks(filter)
  if vim.fn.filereadable(M.config.tasks_file) == 0 then
    notify("No tasks file yet", vim.log.levels.WARN)
    return
  end
  local entries = {}
  for idx, line in ipairs(read_lines(M.config.tasks_file)) do
    if is_task(line) then
      local done = line:match("%[x%]") ~= nil
      local keep = true
      if filter == "open" then keep = not done end
      if filter == "done" then keep = done end
      if keep then
        table.insert(entries, { display = line, value = idx })
      end
    end
  end
  if #entries == 0 then
    notify("No matching tasks")
    return
  end
  pick("Tasks:", entries, function(lnum)
    M.open_tasks()
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  end)
end

-- ── Search and statistics ───────────────────────────────────────────────────

function M.search_notes_by_name()
  local ok_builtin, builtin = pcall(require, "telescope.builtin")
  if ok_builtin then
    builtin.find_files({ cwd = M.config.base_path, prompt_title = "PARA notes by name" })
    return
  end
  ask("Search note names for: ", nil, function(query)
    vim.cmd(string.format("noautocmd vimgrep /%s/j %s/**/*.md", vim.fn.escape(query, "/\\"), M.config.base_path))
    vim.cmd("copen")
  end)
end

function M.search_notes_by_content()
  local ok_builtin, builtin = pcall(require, "telescope.builtin")
  if ok_builtin then
    builtin.live_grep({ cwd = M.config.base_path, prompt_title = "PARA notes by content" })
    return
  end
  ask("Search note contents for: ", nil, function(query)
    vim.cmd(string.format("noautocmd vimgrep /%s/j %s/**/*.md", vim.fn.escape(query, "/\\"), M.config.base_path))
    vim.cmd("copen")
  end)
end

local function show_lines(title, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end
  width = math.min(math.max(width + 4, 40), vim.o.columns - 8)
  local height = math.min(#lines + 2, vim.o.lines - 8)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end, { buffer = buf, nowait = true, silent = true })
  end
end

function M.stats()
  local lines = { "# PARA statistics", "", M.config.base_path, "", "## Entities", "" }
  local total_notes = 0
  for _, category in ipairs(CATEGORY_ORDER) do
    local cat = category_of(category)
    local slugs = M.entities(category)
    local notes = 0
    for _, slug in ipairs(slugs) do
      notes = notes + count_notes(category, slug)
    end
    total_notes = total_notes + notes
    table.insert(lines, string.format("  %-12s %3d  (%d %s)", cat.plural, #slugs, notes, plural("note", notes)))
  end
  local archived = #vim.fn.glob(archive_root() .. "/*", false, true)
  table.insert(lines, string.format("  %-12s %3d", "Archive", archived))
  table.insert(lines, string.format("  %-12s %3d", "Notes", total_notes))

  local log_entries = 0
  for _, line in ipairs(read_lines(M.config.log_file)) do
    if line:match("^%d%d%d%d%-%d%d%-%d%d") then log_entries = log_entries + 1 end
  end
  vim.list_extend(lines, { "", "## Log", "", string.format("  %-12s %3d", "Global", log_entries) })

  local pending, done, critical, high = 0, 0, 0, 0
  for _, line in ipairs(read_lines(M.config.tasks_file)) do
    if is_task(line) then
      if line:match("%[x%]") then done = done + 1 else pending = pending + 1 end
      if line:match("^%[A%]") then critical = critical + 1 end
      if line:match("^%[B%]") then high = high + 1 end
    end
  end
  vim.list_extend(lines, {
    "", "## Tasks", "",
    string.format("  %-12s %3d", "Pending", pending),
    string.format("  %-12s %3d", "Completed", done),
    string.format("  %-12s %3d", "Critical", critical),
    string.format("  %-12s %3d", "High", high),
    "", "Press q to close",
  })
  show_lines("PARA", lines)
end

-- ── Menus ───────────────────────────────────────────────────────────────────

function M.category_menu(category)
  local cat = category_of(category)
  menu(cat.plural .. ":", {
    { "List " .. cat.plural:lower(),        function() M.list_entities(category) end },
    { "Open " .. cat.label:lower(),         function() M.open_entity(category) end },
    { "New " .. cat.label:lower(),          function() M.create_entity(category) end },
    { "New note in " .. cat.label:lower(),  function() M.create_note_in(category) end },
    { "Browse notes of " .. cat.label:lower(), function() M.browse_notes(category) end },
    { "Open log of " .. cat.label:lower(),  function() M.open_entity_log(category) end },
    { "Archive " .. cat.label:lower(),      function() M.archive_entity(category) end },
    { "Back",                                function() M.menu() end },
  })
end

function M.tasks_menu()
  menu("Tasks:", {
    { "List all tasks",      function() M.list_tasks(nil) end },
    { "List open tasks",     function() M.list_tasks("open") end },
    { "List done tasks",     function() M.list_tasks("done") end },
    { "Add task",            function() M.add_task(false) end },
    { "Add task linked to an entity", function() M.add_task(true) end },
    { "Archive done tasks",  function() M.archive_done_tasks() end },
    { "Open tasks file",     function() M.open_tasks() end },
    { "Back",                function() M.menu() end },
  })
end

function M.log_menu()
  menu("Log:", {
    { "Open global log",             function() M.open_log() end },
    { "Add global log entry",        function() M.add_log_entry() end },
    { "Archive global log entries",  function() M.archive_log() end },
    { "Add entry to an entity log",  function() M.add_entity_log_entry() end },
    { "Open an entity log",          function() M.pick_any_entity("Open log of:", function(c, s) M.open_entity_log(c, s) end) end },
    { "Archive an entity log",       function() M.archive_entity_log() end },
    { "Back",                        function() M.menu() end },
  })
end

function M.menu()
  menu("PARA:", {
    { "Find and open anything",  function() M.pick_any_entity("Open:", function(c, s) M.open_entity(c, s) end) end },
    { "New note",                function() M.create_note() end },
    { "New project, area or resource", function()
        pick_category("New what?", function(category) M.create_entity(category) end)
      end },
    { "Projects",                function() M.category_menu("project") end },
    { "Areas",                   function() M.category_menu("area") end },
    { "Resources",               function() M.category_menu("resource") end },
    { "Tasks",                   function() M.tasks_menu() end },
    { "Log",                     function() M.log_menu() end },
    { "Search by name",          function() M.search_notes_by_name() end },
    { "Search by content",       function() M.search_notes_by_content() end },
    { "Archive something",       function() M.archive_any_entity() end },
    { "Statistics",              function() M.stats() end },
  })
end

-- ── User commands ───────────────────────────────────────────────────────────

local SUBCOMMANDS = {
  menu = function() M.menu() end,
  find = function() M.pick_any_entity("Open:", function(c, s) M.open_entity(c, s) end) end,
  projects = function() M.category_menu("project") end,
  areas = function() M.category_menu("area") end,
  resources = function() M.category_menu("resource") end,
  note = function() M.create_note() end,
  tasks = function() M.tasks_menu() end,
  log = function() M.log_menu() end,
  stats = function() M.stats() end,
  search = function() M.search_notes_by_content() end,
}

local function register_commands()
  vim.api.nvim_create_user_command("Para", function(opts)
    local name = opts.args ~= "" and opts.args or "menu"
    local fn = SUBCOMMANDS[name]
    if fn then fn() else notify("Unknown subcommand: " .. name, vim.log.levels.ERROR) end
  end, {
    nargs = "?",
    desc = "PARA menu and subcommands",
    complete = function(lead)
      local out = {}
      for name in pairs(SUBCOMMANDS) do
        if name:find(lead, 1, true) == 1 then table.insert(out, name) end
      end
      table.sort(out)
      return out
    end,
  })
end

-- ── Setup ───────────────────────────────────────────────────────────────────

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.base_path = vim.fn.expand(M.config.base_path)
  M.config.log_file = M.config.log_file or (M.config.base_path .. "/log.md")
  M.config.log_archive_dir = M.config.log_archive_dir or (M.config.base_path .. "/logs/archive")
  M.config.tasks_file = M.config.tasks_file or (M.config.base_path .. "/tasks.md")
  M.config.tasks_archive_file = M.config.tasks_archive_file or (M.config.base_path .. "/tasks_archive.md")

  M.init_directories()
  register_commands()

  local keys = M.config.keymaps
  local bindings = {
    { keys.menu,                 M.menu,                    "PARA menu" },
    { keys.find_entity,          function() M.pick_any_entity("Open:", function(c, s) M.open_entity(c, s) end) end, "Find project, area or resource" },
    { keys.new_entity,           function() pick_category("New what?", function(c) M.create_entity(c) end) end, "New project, area or resource" },
    { keys.new_note,             M.create_note,             "New note in an entity" },
    { keys.projects,             function() M.category_menu("project") end,  "Projects menu" },
    { keys.areas,                function() M.category_menu("area") end,     "Areas menu" },
    { keys.resources,            function() M.category_menu("resource") end, "Resources menu" },
    { keys.entity_log,           M.add_entity_log_entry,    "Add log entry to an entity" },
    { keys.archive_entity,       M.archive_any_entity,      "Archive a project, area or resource" },
    { keys.open_log,             M.open_log,                "Open global log" },
    { keys.add_log,              M.add_log_entry,           "Add global log entry" },
    { keys.archive_log,          M.archive_log,             "Archive global log entries" },
    { keys.insert_log_template,  M.insert_log_template,     "Insert log entry template" },
    { keys.open_tasks,           M.open_tasks,              "Open tasks file" },
    { keys.add_task,             function() M.add_task(false) end, "Add task" },
    { keys.archive_done_tasks,   M.archive_done_tasks,      "Archive done tasks" },
    { keys.insert_task_template, M.insert_task_template,    "Insert task template" },
    { keys.toggle_task,          M.toggle_task,             "Toggle task done or undone" },
    { keys.search_by_name,       M.search_notes_by_name,    "Search notes by name" },
    { keys.search_by_content,    M.search_notes_by_content, "Search notes by content" },
    { keys.stats,                M.stats,                   "PARA statistics" },
  }
  for _, binding in ipairs(bindings) do
    if binding[1] then
      vim.keymap.set("n", binding[1], binding[2], { desc = binding[3], silent = true })
    end
  end

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { M.config.base_path .. "/**/*.md", M.config.base_path .. "/*.md" },
    callback = function()
      vim.fn.matchadd("Error", "\\[A\\]")
      vim.fn.matchadd("WarningMsg", "\\[B\\]")
      vim.fn.matchadd("Question", "\\[C\\]")
      vim.fn.matchadd("Comment", "\\[D\\]")
      vim.fn.matchadd("NonText", "\\[E\\]")
    end,
  })
end

return M
