-- PARA Method Task & Note Management Plugin
-- Place this in your nixvim configuration or as a separate Lua module

local M = {}

-- Configuration defaults (will be overridden by setup())
M.config = {
  base_path = vim.fn.expand("~/Documents/PARA"),
  log_file = nil, -- Will be set based on base_path
  log_archive_dir = nil, -- Will be set based on base_path
  tasks_file = nil, -- Will be set based on base_path
  tasks_archive_file = nil, -- Will be set based on base_path
  date_format = "%Y-%m-%d",
  time_format = "%H:%M",
  datetime_format = "%Y-%m-%d %H:%M:%S",
  keymaps = {
    -- Log management
    open_log = "<leader>pl",
    add_log = "<leader>pla",
    archive_log = "<leader>plx",
    insert_log_template = "<leader>pli",
    -- Task management
    open_tasks = "<leader>pt",
    add_task = "<leader>pta",
    archive_done_tasks = "<leader>ptx",
    toggle_task = "<leader>tt",
    insert_task_template = "<leader>pti",
    -- Search and archive
    search_by_name = "<leader>pn",
    search_by_content = "<leader>ps",
    archive_project = "<leader>px",
  },
  templates = {
    task = "- [ ] %s",
    task_with_priority = "[%s] - [ ] %s",
    note_header = "# %s\n\nCreated: %s\nCategory: %s\n\n---\n\n",
  },
  -- Priority order for sorting (alphabetically sortable)
  priority_order = {
    A = "Critical",
    B = "High",
    C = "Normal",
    D = "Low",
    E = "Someday"
  }
}

-- Utilities
local function ensure_directory(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

local function ensure_file(path, initial_content)
  if vim.fn.filereadable(path) == 0 then
    local file = io.open(path, "w")
    if file then
      file:write(initial_content or "")
      file:close()
    end
  end
end

local function get_current_date()
  return os.date(M.config.date_format)
end

local function get_current_time()
  return os.date(M.config.time_format)
end

local function get_current_datetime()
  return os.date(M.config.datetime_format)
end

-- Initialize PARA directory structure
function M.init_directories()
  ensure_directory(M.config.base_path)
  ensure_directory(M.config.log_archive_dir)
  
  local categories = {"1_projects", "2_areas", "3_resources", "4_archive"}
  for _, category in ipairs(categories) do
    ensure_directory(M.config.base_path .. "/" .. category)
  end
  
  -- Initialize log file
  ensure_file(M.config.log_file, "# Log\nCreated: " .. get_current_datetime() .. "\n\n")
  
  -- Initialize tasks file with sortable structure
  ensure_file(M.config.tasks_file, "# Tasks\nCreated: " .. get_current_datetime() .. "\n\n")
end

-- Open log file
function M.open_log()
  ensure_file(M.config.log_file, "# Log\nCreated: " .. get_current_datetime() .. "\n\n")
  vim.cmd("edit " .. M.config.log_file)
  -- Move to end of file
  vim.cmd("normal G")
end

-- Add log entry
function M.add_log_entry()
  vim.ui.input({
    prompt = "Log entry: ",
  }, function(input)
    if input and input ~= "" then
      local timestamp = get_current_datetime()
      local entry = string.format("%s - %s\n", timestamp, input)
      
      -- Append to log file
      local file = io.open(M.config.log_file, "a")
      if file then
        file:write(entry)
        file:close()
        
        -- Check if log file is open in any buffer
        local log_bufnr = vim.fn.bufnr(M.config.log_file)
        
        if log_bufnr ~= -1 then
          -- Buffer exists, reload it
          vim.api.nvim_buf_call(log_bufnr, function()
            vim.cmd("edit!")
            vim.cmd("normal G")  -- Go to end of file
          end)
        else
          -- File not open, open it
          vim.cmd("edit " .. M.config.log_file)
          vim.cmd("normal G")  -- Go to end of file
        end
        
        vim.notify("Log entry added", vim.log.levels.INFO)
      end
    end
  end)
end

-- Archive log entries before a given date
function M.archive_log()
  vim.ui.input({
    prompt = "Archive entries before date (YYYY-MM-DD): ",
    default = get_current_date(),
  }, function(cutoff_date)
    if not cutoff_date or cutoff_date == "" then return end
    
    -- Read log file
    local log_content = {}
    local archive_content = {}
    local file = io.open(M.config.log_file, "r")
    if not file then
      vim.notify("Log file not found", vim.log.levels.ERROR)
      return
    end
    
    for line in file:lines() do
      -- Check if line starts with a timestamp
      local date_match = line:match("^(%d%d%d%d%-%d%d%-%d%d)")
      if date_match and date_match < cutoff_date then
        table.insert(archive_content, line)
      else
        table.insert(log_content, line)
      end
    end
    file:close()
    
    if #archive_content == 0 then
      vim.notify("No entries to archive", vim.log.levels.INFO)
      return
    end
    
    -- Write archive file
    local archive_file = string.format("%s/log_archive_%s.md", M.config.log_archive_dir, os.date("%Y%m%d_%H%M%S"))
    ensure_directory(M.config.log_archive_dir)
    file = io.open(archive_file, "w")
    if file then
      file:write("# Archived Log Entries\n")
      file:write("Archived: " .. get_current_datetime() .. "\n")
      file:write("Entries before: " .. cutoff_date .. "\n\n")
      file:write(table.concat(archive_content, "\n"))
      file:close()
    end
    
    -- Update log file
    file = io.open(M.config.log_file, "w")
    if file then
      if #log_content > 0 then
        file:write(table.concat(log_content, "\n"))
      else
        file:write("# Log\nCreated: " .. get_current_datetime() .. "\n\n")
      end
      file:close()
    end
    
    vim.notify(string.format("Archived %d entries to %s", #archive_content, archive_file), vim.log.levels.INFO)
  end)
end

-- Open tasks file
function M.open_tasks()
  ensure_file(M.config.tasks_file, "# Tasks\nCreated: " .. get_current_datetime() .. "\n\n")
  vim.cmd("edit " .. M.config.tasks_file)
end

-- Add new task with priority
function M.add_task()
  vim.ui.input({
    prompt = "Task description: ",
  }, function(description)
    if not description or description == "" then return end
    
    -- Get priority keys sorted alphabetically
    local priority_keys = {}
    for k, _ in pairs(M.config.priority_order) do
      table.insert(priority_keys, k)
    end
    table.sort(priority_keys)
    
    -- Create display options
    local options = {}
    for _, k in ipairs(priority_keys) do
      table.insert(options, k .. " - " .. M.config.priority_order[k])
    end
    
    vim.ui.select(
      options,
      { prompt = "Priority: " },
      function(choice)
        if not choice then return end
        local priority = choice:sub(1, 1) -- Get first character (A, B, C, etc.)
        
        local task_line
        if priority == "C" then -- Normal priority, no prefix
          task_line = "- [ ] " .. description
        else
          task_line = string.format("[%s] - [ ] %s", priority, description)
        end
        
        -- Add to tasks file
        M.add_task_to_file(task_line)
      end
    )
  end)
end

-- Sort tasks in file by priority
local function sort_tasks_in_file()
  local file = io.open(M.config.tasks_file, "r")
  if not file then return end
  
  local header_lines = {}
  local tasks = {}
  local in_header = true
  
  -- Read and categorize lines
  for line in file:lines() do
    if in_header and (line:match("^%[%w%] %- %[[ x]%]") or line:match("^%- %[[ x]%]")) then
      in_header = false
    end
    
    if in_header then
      table.insert(header_lines, line)
    else
      if line:match("^%[%w%] %- %[[ x]%]") or line:match("^%- %[[ x]%]") then
        table.insert(tasks, line)
      elseif line ~= "" then
        table.insert(tasks, line)
      end
    end
  end
  file:close()
  
  -- Sort tasks alphabetically (which sorts by priority prefix)
  table.sort(tasks)
  
  -- Write back
  file = io.open(M.config.tasks_file, "w")
  if file then
    for _, line in ipairs(header_lines) do
      file:write(line .. "\n")
    end
    for _, task in ipairs(tasks) do
      file:write(task .. "\n")
    end
    file:close()
  end
end

-- Add task to tasks file (sorted)
function M.add_task_to_file(task_line)
  ensure_file(M.config.tasks_file, "# Tasks\nCreated: " .. get_current_datetime() .. "\n\n")
  
  -- Append task
  local file = io.open(M.config.tasks_file, "a")
  if file then
    file:write(task_line .. "\n")
    file:close()
  end
  
  -- Sort the file
  sort_tasks_in_file()
  
  -- Check if tasks file is open in any buffer
  local tasks_bufnr = vim.fn.bufnr(M.config.tasks_file)
  
  if tasks_bufnr ~= -1 then
    -- Buffer exists, reload it
    vim.api.nvim_buf_call(tasks_bufnr, function()
      vim.cmd("edit!")
    end)
  else
    -- File not open, open it
    vim.cmd("edit " .. M.config.tasks_file)
  end
  
  vim.notify("Task added to tasks.md", vim.log.levels.INFO)
end

-- Archive completed tasks
function M.archive_done_tasks()
  local file = io.open(M.config.tasks_file, "r")
  if not file then
    vim.notify("Tasks file not found", vim.log.levels.ERROR)
    return
  end
  
  local active_tasks = {}
  local done_tasks = {}
  
  for line in file:lines() do
    if line:match("%[x%]") then
      table.insert(done_tasks, line)
    else
      table.insert(active_tasks, line)
    end
  end
  file:close()
  
  if #done_tasks == 0 then
    vim.notify("No completed tasks to archive", vim.log.levels.INFO)
    return
  end
  
  -- Append to archive file
  ensure_file(M.config.tasks_archive_file, "# Archived Tasks\n\n")
  file = io.open(M.config.tasks_archive_file, "a")
  if file then
    file:write("\n## Archived on " .. get_current_datetime() .. "\n")
    for _, task in ipairs(done_tasks) do
      file:write(task .. "\n")
    end
    file:close()
  end
  
  -- Write back active tasks
  file = io.open(M.config.tasks_file, "w")
  if file then
    for _, line in ipairs(active_tasks) do
      file:write(line .. "\n")
    end
    file:close()
  end
  
  vim.notify(string.format("Archived %d completed tasks", #done_tasks), vim.log.levels.INFO)
end

-- Task summary (removed, tasks are now in a single sortable file)
function M.show_task_summary_deprecated()
  M.init_tasks_file()
  
  local tasks = M.parse_tasks_file()
  local summary_lines = {
    "# Task Summary - " .. os.date("%Y-%m-%d"),
    "",
    "## Statistics",
    string.format("- Total pending: %d", tasks.stats.pending),
    string.format("- High priority: %d", tasks.stats.high_priority),
    string.format("- Completed today: %d", tasks.stats.completed_today),
    "",
    "## Pending Tasks by Priority",
    ""
  }
  
  -- Group by priority
  local priorities = {"high", "1", "2", "3", "low", "normal"}
  for _, priority in ipairs(priorities) do
    local priority_tasks = tasks.by_priority[priority] or {}
    if #priority_tasks > 0 then
      table.insert(summary_lines, "### " .. (priority == "normal" and "Normal Priority" or priority:upper()))
      for _, task in ipairs(priority_tasks) do
        table.insert(summary_lines, task.line)
      end
      table.insert(summary_lines, "")
    end
  end
  
  -- Create temporary buffer for summary
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, summary_lines)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_name(buf, 'Task Summary')
  
  -- Open in split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
end

-- Parse tasks file and return structured data (deprecated)
function M.parse_tasks_file_deprecated()
  local tasks = {
    pending = {},
    completed = {},
    by_priority = {},
    stats = {
      pending = 0,
      completed = 0,
      high_priority = 0,
      completed_today = 0
    }
  }
  
  if vim.fn.filereadable(M.config.tasks_file) == 0 then
    return tasks
  end
  
  local file = io.open(M.config.tasks_file, "r")
  if not file then return tasks end
  
  local today = os.date("%Y-%m-%d")
  
  for line in file:lines() do
    if line:match("^%s*%- %[[ ]%]") then
      -- Pending task
      local priority = line:match("%(([^)]+)%)")
      priority = priority or "normal"
      
      local task = {
        line = line,
        priority = priority,
        text = line:gsub("^%s*%- %[ %] ?(%([^)]+%))?%s*", ""),
        project = line:match("%(project: ([^)]+)%)"),
        area = line:match("%(area: ([^)]+)%)")
      }
      
      table.insert(tasks.pending, task)
      
      if not tasks.by_priority[priority] then
        tasks.by_priority[priority] = {}
      end
      table.insert(tasks.by_priority[priority], task)
      
      tasks.stats.pending = tasks.stats.pending + 1
      
      if priority == "high" or priority == "1" then
        tasks.stats.high_priority = tasks.stats.high_priority + 1
      end
    elseif line:match("^%s*%- %[x%]") then
      -- Completed task
      table.insert(tasks.completed, line)
      tasks.stats.completed = tasks.stats.completed + 1
      
      -- Check if completed today (simple heuristic - could be improved)
      if line:match(today) then
        tasks.stats.completed_today = tasks.stats.completed_today + 1
      end
    end
  end
  
  file:close()
  return tasks
end

-- Insert log entry template at current position
function M.insert_log_template()
  local timestamp = get_current_datetime()
  local template = string.format("%s - ", timestamp)
  
  -- Insert at current cursor position
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local new_line = line:sub(1, col) .. template .. line:sub(col + 1)
  vim.api.nvim_set_current_line(new_line)
  
  -- Move cursor to end of template
  vim.api.nvim_win_set_cursor(0, {row, col + #template})
  
  -- Enter insert mode
  vim.cmd("startinsert!")
end

-- Insert task template at current position
function M.insert_task_template()
  -- Ask for priority
  local priority_keys = {}
  for k, _ in pairs(M.config.priority_order) do
    table.insert(priority_keys, k)
  end
  table.sort(priority_keys)
  
  local options = {}
  for _, k in ipairs(priority_keys) do
    table.insert(options, k .. " - " .. M.config.priority_order[k])
  end
  
  vim.ui.select(
    options,
    { prompt = "Priority: " },
    function(choice)
      if not choice then return end
      local priority = choice:sub(1, 1)
      
      local template
      if priority == "C" then -- Normal priority, no prefix
        template = "- [ ] "
      else
        template = string.format("[%s] - [ ] ", priority)
      end
      
      -- Insert at current cursor position
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col) .. template .. line:sub(col + 1)
      vim.api.nvim_set_current_line(new_line)
      
      -- Move cursor to end of template
      vim.api.nvim_win_set_cursor(0, {row, col + #template})
      
      -- Enter insert mode
      vim.cmd("startinsert!")
    end
  )
end

-- Toggle task completion in current line
function M.toggle_task()
  local line = vim.api.nvim_get_current_line()
  local new_line
  
  -- Handle priority-prefixed tasks
  if line:match("%[%w%] %- %[ %]") then
    new_line = line:gsub("%- %[ %]", "- [x]")
  elseif line:match("%[%w%] %- %[x%]") then
    new_line = line:gsub("%- %[x%]", "- [ ]")
  -- Handle regular tasks
  elseif line:match("%- %[ %]") then
    new_line = line:gsub("%- %[ %]", "- [x]")
  elseif line:match("%- %[x%]") then
    new_line = line:gsub("%- %[x%]", "- [ ]")
  else
    return
  end
  
  vim.api.nvim_set_current_line(new_line)
  
  -- If in tasks file, re-sort
  if vim.fn.expand("%:t") == "tasks.md" then
    sort_tasks_in_file()
    vim.notify("Task toggled", vim.log.levels.INFO)
  end
end

-- Note creation
function M.create_note()
  vim.ui.select(
    {"Projects", "Areas", "Resources"},
    { prompt = "Note category: " },
    function(category)
      if not category then return end
      
      vim.ui.input({
        prompt = "Note title: ",
      }, function(title)
        if not title or title == "" then return end
        
        local filename = title:lower():gsub("%s+", "-") .. ".md"
        local category_num = ({Projects = "1", Areas = "2", Resources = "3"})[category]
        local filepath = string.format("%s/%s_%s/%s", 
          M.config.base_path, 
          category_num, 
          category:lower(),
          filename
        )
        
        -- Create note with header
        local header = string.format(
          M.config.templates.note_header,
          title,
          os.date("%Y-%m-%d %H:%M"),
          category
        )
        
        local file = io.open(filepath, "w")
        if file then
          file:write(header)
          file:close()
        end
        
        vim.cmd("edit " .. filepath)
      end)
    end
  )
end

-- Navigate to or create a specific area (removed - not in requirements)
function M.goto_area_deprecated()
  local areas = M.get_areas()
  local area_names = {"[Create New Area]"}
  
  -- Add existing areas to the list
  for _, area in ipairs(areas) do
    table.insert(area_names, area.display_name)
  end
  
  vim.ui.select(area_names, {
    prompt = "Select area (or create new):",
  }, function(choice, idx)
    if not choice then return end
    
    if idx == 1 then
      -- Create new area
      vim.ui.input({
        prompt = "New area name: ",
      }, function(name)
        if name and name ~= "" then
          local filename = name:lower():gsub("%s+", "-") .. ".md"
          local filepath = M.config.base_path .. "/2_areas/" .. filename
          
          -- Create area file with template
          local content = string.format([[
# Area: %s

Created: %s

## Overview


## Responsibilities


## Standards & Maintenance


## Regular Tasks
- [ ] 

## Resources


## Notes

]], name, os.date("%Y-%m-%d %H:%M"))
          
          local file = io.open(filepath, "w")
          if file then
            file:write(content)
            file:close()
            vim.cmd("edit " .. filepath)
            vim.notify("Area created: " .. name, vim.log.levels.INFO)
          end
        end
      end)
    else
      -- Open existing area
      local area = areas[idx - 1]
      if area.is_directory then
        vim.cmd("Explore " .. area.path)
      else
        vim.cmd("edit " .. area.path)
      end
    end
  end)
end

-- Navigate to or create a specific project (removed - not in requirements)
function M.goto_project_deprecated()
  local projects = M.get_projects()
  local project_names = {"[Create New Project]"}
  
  -- Add existing projects to the list
  for _, project in ipairs(projects) do
    table.insert(project_names, project.display_name)
  end
  
  vim.ui.select(project_names, {
    prompt = "Select project (or create new):",
  }, function(choice, idx)
    if not choice then return end
    
    if idx == 1 then
      -- Create new project
      vim.ui.input({
        prompt = "New project name: ",
      }, function(name)
        if name and name ~= "" then
          local filename = name:lower():gsub("%s+", "-") .. ".md"
          local filepath = M.config.base_path .. "/1_projects/" .. filename
          
          -- Create project file with template
          local content = string.format([[
# Project: %s

Created: %s
Status: Active
Due Date: 
Priority: Normal

## Objective


## Success Criteria


## Tasks
- [ ] 

## Resources


## Notes


## Retrospective

]], name, os.date("%Y-%m-%d %H:%M"))
          
          local file = io.open(filepath, "w")
          if file then
            file:write(content)
            file:close()
            vim.cmd("edit " .. filepath)
            vim.notify("Project created: " .. name, vim.log.levels.INFO)
          end
        end
      end)
    else
      -- Open existing project
      local project = projects[idx - 1]
      if project.is_directory then
        vim.cmd("Explore " .. project.path)
      else
        vim.cmd("edit " .. project.path)
      end
    end
  end)
end

-- Search notes by name
function M.search_notes_by_name()
  vim.ui.input({
    prompt = "Search note names for: ",
  }, function(query)
    if query and query ~= "" then
      if pcall(require, "telescope") then
        require("telescope.builtin").find_files({
          cwd = M.config.base_path,
          prompt_title = "Search Notes by Name",
          search_file = query,
        })
      else
        -- Fallback: use vim's built-in file search
        vim.cmd(string.format("find %s -name '*%s*' -type f | copen", M.config.base_path, query))
      end
    end
  end)
end

-- Search notes by content
function M.search_notes_by_content()
  vim.ui.input({
    prompt = "Search note contents for: ",
  }, function(query)
    if query and query ~= "" then
      if pcall(require, "telescope") then
        require("telescope.builtin").grep_string({
          search = query,
          cwd = M.config.base_path,
          prompt_title = "Search Notes by Content",
        })
      else
        vim.cmd(string.format("vimgrep /%s/j %s/**/*.md | copen", query, M.config.base_path))
      end
    end
  end)
end

-- Archive a project (move from Projects to Archive)
function M.archive_project()
  local projects = M.get_projects()
  if #projects == 0 then
    vim.notify("No projects found to archive", vim.log.levels.WARN)
    return
  end
  
  local project_names = {}
  for _, project in ipairs(projects) do
    table.insert(project_names, project.display_name)
  end
  
  vim.ui.select(project_names, {
    prompt = "Select project to archive: ",
  }, function(choice, idx)
    if not choice or not idx then return end
    
    local project = projects[idx]
    local archive_path = M.config.base_path .. "/4_archive/" .. vim.fn.fnamemodify(project.path, ":t")
    
    -- Check if file already exists in archive
    if vim.fn.filereadable(archive_path) == 1 then
      vim.ui.select({"Yes", "No"}, {
        prompt = "File already exists in archive. Overwrite?",
      }, function(confirm)
        if confirm == "Yes" then
          vim.fn.rename(project.path, archive_path)
          vim.notify("Project archived: " .. project.display_name, vim.log.levels.INFO)
        end
      end)
    else
      vim.fn.rename(project.path, archive_path)
      vim.notify("Project archived: " .. project.display_name, vim.log.levels.INFO)
    end
  end)
end


-- Recent files (removed - duplication)
function M.recent_files_deprecated()
  -- Use telescope if available for better UI
  if pcall(require, "telescope") then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    -- Get recent files using find command
    local handle = io.popen(string.format(
      "find %s -name '*.md' -type f -printf '%%T@ %%p\\n' 2>/dev/null | sort -rn | head -20 | cut -d' ' -f2-",
      M.config.base_path
    ))
    
    if not handle then
      vim.notify("Failed to get recent files", vim.log.levels.ERROR)
      return
    end
    
    local files = {}
    for file in handle:lines() do
      -- Get relative path and modification time
      local relative = file:gsub(M.config.base_path .. "/", "")
      local stat = vim.loop.fs_stat(file)
      local modified = stat and os.date("%Y-%m-%d %H:%M", stat.mtime.sec) or ""
      table.insert(files, {
        path = file,
        display = string.format("%-50s %s", relative, modified)
      })
    end
    handle:close()
    
    pickers.new({}, {
      prompt_title = "Recent PARA Files",
      finder = finders.new_table {
        results = files,
        entry_maker = function(entry)
          return {
            value = entry.path,
            display = entry.display,
            ordinal = entry.display,
          }
        end,
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.value)
        end)
        return true
      end,
    }):find()
  else
    -- Fallback without telescope
    local handle = io.popen(string.format(
      "find %s -name '*.md' -type f -printf '%%T@ %%p\\n' 2>/dev/null | sort -rn | head -10 | cut -d' ' -f2-",
      M.config.base_path
    ))
    
    if not handle then
      vim.notify("Failed to get recent files", vim.log.levels.ERROR)
      return
    end
    
    local files = {}
    for file in handle:lines() do
      local relative = file:gsub(M.config.base_path .. "/", "")
      table.insert(files, relative)
    end
    handle:close()
    
    vim.ui.select(files, {
      prompt = "Recent files:",
    }, function(choice)
      if choice then
        vim.cmd("edit " .. M.config.base_path .. "/" .. choice)
      end
    end)
  end
end

-- Quick switcher (removed - duplication)
function M.quick_switch_deprecated()
  if pcall(require, "telescope") then
    require("telescope.builtin").find_files({
      cwd = M.config.base_path,
      prompt_title = "PARA Quick Switch",
      find_command = {"find", ".", "-name", "*.md", "-type", "f"},
    })
  else
    -- Fallback: use vim.ui.select with all files
    local handle = io.popen(string.format(
      "find %s -name '*.md' -type f | head -30",
      M.config.base_path
    ))
    
    if not handle then
      vim.notify("Failed to list files", vim.log.levels.ERROR)
      return
    end
    
    local files = {}
    for file in handle:lines() do
      local relative = file:gsub(M.config.base_path .. "/", "")
      table.insert(files, relative)
    end
    handle:close()
    
    vim.ui.select(files, {
      prompt = "Switch to file:",
    }, function(choice)
      if choice then
        vim.cmd("edit " .. M.config.base_path .. "/" .. choice)
      end
    end)
  end
end

-- Task migration (removed - using single log file now)
function M.migrate_tasks_deprecated()
  local yesterday = os.date(M.config.date_format, os.time() - 86400)
  local yesterday_log = string.format("%s/%s.md", M.config.log_path, yesterday)
  local today_log = get_daily_log_path()
  
  if vim.fn.filereadable(yesterday_log) == 0 then
    vim.notify("No log found for yesterday", vim.log.levels.WARN)
    return
  end
  
  -- Read yesterday's tasks
  local yesterday_tasks = {}
  local file = io.open(yesterday_log, "r")
  if file then
    local in_tasks = false
    for line in file:lines() do
      if line:match("^## Tasks") then
        in_tasks = true
      elseif line:match("^##%s") then
        in_tasks = false
      elseif in_tasks and line:match("^%- %[ %]") then
        table.insert(yesterday_tasks, line)
      end
    end
    file:close()
  end
  
  if #yesterday_tasks == 0 then
    vim.notify("No pending tasks from yesterday", vim.log.levels.INFO)
    return
  end
  
  -- Show tasks and ask which to migrate
  vim.ui.select(
    yesterday_tasks,
    { prompt = "Select tasks to migrate (ESC to migrate all):" },
    function(choice)
      local tasks_to_migrate = choice and {choice} or yesterday_tasks
      
      -- Ensure today's log exists
      if vim.fn.filereadable(today_log) == 0 then
        M.open_daily_log()
        vim.cmd("bdelete")
      end
      
      -- Add tasks to today's log
      for _, task in ipairs(tasks_to_migrate) do
        M.append_to_section(today_log, "## Tasks", task)
      end
      
      vim.notify(string.format("Migrated %d task(s) to today", #tasks_to_migrate), vim.log.levels.INFO)
    end
  )
end

-- Get dynamic list of areas from filesystem
function M.get_areas()
  local areas_dir = M.config.base_path .. "/2_areas"
  local areas = {}
  
  -- Get all .md files in areas directory
  local area_files = vim.fn.glob(areas_dir .. "/*.md", false, true)
  for _, file in ipairs(area_files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    -- Capitalize first letter and replace dashes with spaces
    local display_name = name:gsub("-", " "):gsub("^%l", string.upper)
    table.insert(areas, {
      name = name,
      display_name = display_name,
      path = file
    })
  end
  
  -- Also check for subdirectories as areas
  local subdirs = vim.fn.glob(areas_dir .. "/*/", false, true)
  for _, dir in ipairs(subdirs) do
    local name = vim.fn.fnamemodify(dir:sub(1, -2), ":t")
    local display_name = name:gsub("-", " "):gsub("^%l", string.upper)
    table.insert(areas, {
      name = name,
      display_name = display_name,
      path = dir,
      is_directory = true
    })
  end
  
  return areas
end

-- Get dynamic list of projects from filesystem
function M.get_projects()
  local projects_dir = M.config.base_path .. "/1_projects"
  local projects = {}
  
  -- Get all .md files in projects directory
  local project_files = vim.fn.glob(projects_dir .. "/*.md", false, true)
  for _, file in ipairs(project_files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    -- Capitalize first letter and replace dashes with spaces
    local display_name = name:gsub("-", " "):gsub("^%l", string.upper)
    table.insert(projects, {
      name = name,
      display_name = display_name,
      path = file
    })
  end
  
  -- Also check for subdirectories as projects
  local subdirs = vim.fn.glob(projects_dir .. "/*/", false, true)
  for _, dir in ipairs(subdirs) do
    local name = vim.fn.fnamemodify(dir:sub(1, -2), ":t")
    local display_name = name:gsub("-", " "):gsub("^%l", string.upper)
    table.insert(projects, {
      name = name,
      display_name = display_name,
      path = dir,
      is_directory = true
    })
  end
  
  return projects
end

-- Weekly review (removed - duplication)
function M.weekly_review_deprecated()
  local review_items = {}
  
  -- Check projects for activity
  local projects_dir = M.config.base_path .. "/1_projects"
  local project_files = vim.fn.glob(projects_dir .. "/*.md", false, true)
  
  for _, file in ipairs(project_files) do
    local stat = vim.loop.fs_stat(file)
    if stat then
      local days_old = (os.time() - stat.mtime.sec) / 86400
      if days_old > 7 then
        local name = vim.fn.fnamemodify(file, ":t:r")
        table.insert(review_items, string.format("[Project] %s - inactive for %d days", name, math.floor(days_old)))
      end
    end
  end
  
  -- Count tasks
  local total_tasks = 0
  local completed_tasks = 0
  local high_priority = 0
  
  -- Scan all files for tasks
  local all_files = vim.fn.glob(M.config.base_path .. "/**/*.md", false, true)
  for _, file in ipairs(all_files) do
    local content = io.open(file, "r")
    if content then
      for line in content:lines() do
        if line:match("^%- %[ %]") then
          total_tasks = total_tasks + 1
          if line:match("%[High%]") then
            high_priority = high_priority + 1
          end
        elseif line:match("^%- %[x%]") then
          completed_tasks = completed_tasks + 1
        end
      end
      content:close()
    end
  end
  
  -- Get dynamic areas for review checklist
  local areas = M.get_areas()
  local area_checklist = {}
  for _, area in ipairs(areas) do
    table.insert(area_checklist, string.format("- [ ] %s", area.display_name))
  end
  local areas_section = #area_checklist > 0 and table.concat(area_checklist, "\n") or "- [ ] No areas found"
  
  -- Create review report
  local review_date = os.date("%Y-%m-%d")
  local review_file = string.format("%s/weekly-review-%s.md", M.config.log_path, review_date)
  
  local report = string.format([[
# Weekly Review - %s

## Statistics
- Total pending tasks: %d
- Completed tasks: %d  
- High priority tasks: %d
- Completion rate: %.1f%%

## Projects Status
%s

## Areas to Review
%s

## Action Items
- [ ] Archive completed projects
- [ ] Review and update project priorities
- [ ] Clean up resources folder
- [ ] Plan next week's focus areas

## Notes

]], 
    review_date,
    total_tasks,
    completed_tasks,
    high_priority,
    completed_tasks > 0 and (completed_tasks / (completed_tasks + total_tasks) * 100) or 0,
    #review_items > 0 and table.concat(review_items, "\n") or "All projects active",
    areas_section
  )
  
  -- Write review file
  local file = io.open(review_file, "w")
  if file then
    file:write(report)
    file:close()
  end
  
  -- Open the review
  vim.cmd("edit " .. review_file)
  vim.notify("Weekly review created", vim.log.levels.INFO)
end

-- Helper function to append to a specific section
function M.append_to_section(filepath, section_header, content)
  local lines = {}
  local file = io.open(filepath, "r")
  
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
  end
  
  -- Find section and append
  local section_found = false
  local insert_index = #lines + 1
  
  for i, line in ipairs(lines) do
    if line:match("^" .. vim.pesc(section_header)) then
      section_found = true
      -- Find next section or end of file
      for j = i + 1, #lines do
        if lines[j]:match("^##%s") then
          insert_index = j
          break
        end
      end
      if insert_index == #lines + 1 then
        insert_index = #lines + 1
      end
      break
    end
  end
  
  -- Insert content
  table.insert(lines, insert_index, content)
  
  -- Write back
  file = io.open(filepath, "w")
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()
    vim.notify("Content added", vim.log.levels.INFO)
  end
end

-- Select file and append task
function M.select_and_append_task(category, task_line)
  local category_num = ({project = "1", area = "2"})[category]
  local path = string.format("%s/%s_%ss", M.config.base_path, category_num, category)
  
  -- Get list of files
  local files = vim.fn.glob(path .. "/*.md", false, true)
  
  if #files == 0 then
    vim.notify("No " .. category .. "s found", vim.log.levels.WARN)
    return
  end
  
  -- Extract just filenames for display
  local filenames = {}
  for _, file in ipairs(files) do
    table.insert(filenames, vim.fn.fnamemodify(file, ":t:r"))
  end
  
  vim.ui.select(filenames, {
    prompt = "Select " .. category .. ": ",
  }, function(choice, idx)
    if choice and idx then
      local filepath = files[idx]
      
      -- Append task to file
      local file = io.open(filepath, "a")
      if file then
        file:write("\n" .. task_line .. "\n")
        file:close()
        vim.notify("Task added to " .. choice, vim.log.levels.INFO)
      end
    end
  end)
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Set derived paths if not explicitly provided
  if not M.config.log_file then
    M.config.log_file = M.config.base_path .. "/log.md"
  end
  if not M.config.log_archive_dir then
    M.config.log_archive_dir = M.config.base_path .. "/logs/archive"
  end
  if not M.config.tasks_file then
    M.config.tasks_file = M.config.base_path .. "/tasks.md"
  end
  if not M.config.tasks_archive_file then
    M.config.tasks_archive_file = M.config.base_path .. "/tasks_archive.md"
  end
  
  -- Initialize directories
  M.init_directories()
  
  -- Set up keymaps
  local keymaps = M.config.keymaps
  
  -- Log management
  vim.keymap.set("n", keymaps.open_log, M.open_log, { desc = "Open log file" })
  vim.keymap.set("n", keymaps.add_log, M.add_log_entry, { desc = "Add log entry" })
  vim.keymap.set("n", keymaps.archive_log, M.archive_log, { desc = "Archive log entries" })
  vim.keymap.set("n", keymaps.insert_log_template, M.insert_log_template, { desc = "Insert log entry template" })
  
  -- Task management
  vim.keymap.set("n", keymaps.open_tasks, M.open_tasks, { desc = "Open tasks file" })
  vim.keymap.set("n", keymaps.add_task, M.add_task, { desc = "Add task" })
  vim.keymap.set("n", keymaps.archive_done_tasks, M.archive_done_tasks, { desc = "Archive done tasks" })
  vim.keymap.set("n", keymaps.toggle_task, M.toggle_task, { desc = "Toggle task done/undone" })
  vim.keymap.set("n", keymaps.insert_task_template, M.insert_task_template, { desc = "Insert task template" })
  
  -- Search and archive
  vim.keymap.set("n", keymaps.search_by_name, M.search_notes_by_name, { desc = "Search notes by name" })
  vim.keymap.set("n", keymaps.search_by_content, M.search_notes_by_content, { desc = "Search notes by content" })
  vim.keymap.set("n", keymaps.archive_project, M.archive_project, { desc = "Archive project" })
  
  -- Set up autocmds for task priority coloring
  vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    pattern = {"*.md"},
    callback = function()
      -- Color priority prefixes
      vim.fn.matchadd("Error", "\\[A\\]")
      vim.fn.matchadd("WarningMsg", "\\[B\\]")
      vim.fn.matchadd("Question", "\\[C\\]")
      vim.fn.matchadd("Comment", "\\[D\\]")
      vim.fn.matchadd("NonText", "\\[E\\]")
    end,
  })
end

return M