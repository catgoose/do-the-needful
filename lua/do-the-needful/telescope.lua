local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local tm = require("do-the-needful.window")
local tsk = require("do-the-needful.tasks")
local e = require("do-the-needful.edit")

local M = {}

local function get_tasks()
	return tsk.collect_tasks()
end

local function entry_ordinal(task)
	local tags = vim.tbl_map(function(tag)
		return "#" .. tag
	end, task.tags)
	return table.concat(tags, " ") .. " " .. task.name
end

local function entry_display(entry)
	local items = { entry.value.name, " " }
	local highlights = {}
	local start = #table.concat(items, "")
	for _, tag in pairs(entry.value.tags) do
		vim.list_extend(items, { "#", tag, " " })
		vim.list_extend(highlights, {
			{ { start, start + 1 }, "TelescopeResultsOperator" },
			{ { start + 1, start + 1 + #tag }, "TelescopeResultsIdentifier" },
		})
		start = start + 1 + #tag + 1
	end
	return table.concat(items), highlights
end

local function entry_maker(task)
	return {
		value = task,
		display = entry_display,
		ordinal = entry_ordinal(task),
	}
end

---@diagnostic disable-next-line: unused-local
local function task_previewer(opts)
	return previewers.new_buffer_previewer({
		title = "please",
		define_preview = function(self, entry, _)
			vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "lua")
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, tsk.task_preview(entry.value))
		end,
	})
end

local function task_picker(opts)
	local tasks = get_tasks()
	pickers
		.new(opts, {
			prompt_title = "Do the needful",
			finder = finders.new_table({
				results = tasks,
				entry_maker = entry_maker,
			}),
			sorter = conf.generic_sorter(),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					tm.run_task(selection.value)
				end)
				return true
			end,
			previewer = task_previewer(opts),
		})
		:find()
end

function M.action_picker(opts)
	local selections = {
		{ "Do the needful", task_picker, opts },
		{ "Edit project config", e.edit_config, "project" },
		{ "Edit global config", e.edit_config, "global" },
	}
	pickers
		.new(opts, {
			prompt_title = "do-the-needful actions",
			finder = finders.new_table({
				results = selections,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry[1],
						ordinal = entry[1],
					}
				end,
			}),
			sorter = conf.generic_sorter(),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					local s = selection.value
					s[2](s[3])
				end)
				return true
			end,
		})
		:find()
end

function M.tasks(opts)
	opts = opts or {}
	task_picker(opts)
end

return M
