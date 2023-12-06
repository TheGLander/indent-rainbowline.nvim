local ibl_hooks = require("ibl.hooks")

local function mix_colors(a, b, mult)
	return {
		a[1] * mult + b[1] * (1 - mult),
		a[2] * mult + b[2] * (1 - mult),
		a[3] * mult + b[3] * (1 - mult),
	}
end

local function decompose_color(color)
	if color == nil then
		color = 0
	end
	local blue = color % 256
	local green = (color - blue) / 256 % 256
	local red = (color - green * 256 - blue) / 256 / 256
	return { red, green, blue }
end

local function compose_color(color)
	return math.floor(math.floor(color[3]) + math.floor(color[2]) * 256 + math.floor(color[1]) * 256 * 256)
end

local function fill_missing_hl_parts(hl, base)
	if hl.bg == nil then
		hl.bg = base.bg
	end
	if hl.fg == nil then
		hl.fg = base.fg
	end
end

-- A slightly more terse way of getting a highlight from the Nvim API
local function get_hl(name)
	return vim.api.nvim_get_hl(0, { name = name, link = false })
end

-- Resolves the name by looking up the hightlight and defaulting to the normal fg/bg colors if they aren't set
local function resolve_hl(names)
	local hl = {}
	for _, hl_name in ipairs(names) do
		fill_missing_hl_parts(hl, get_hl(hl_name))
	end
	return hl
end

-- Generates a list of highlight groups based on the base highlight, but with some colors mixed in
local function make_hl_groups(opts)
	local color_transparency = opts.color_transparency or 0.07
	local rainbow_colors = opts.colors or { 0xffff40, 0x79ff79, 0xff79ff, 0x4fecec }
	local base_hl = resolve_hl(opts.hl)
	local groups_name_prefix = opts.prefix
	local color_groups = {}
	local base_bg = decompose_color(base_hl.bg)

	for i, rainbow_color_composed in ipairs(rainbow_colors) do
		local rainbow_color = decompose_color(rainbow_color_composed)
		local mixed_color = mix_colors(rainbow_color, base_bg, color_transparency)
		local group_name = groups_name_prefix .. i
		vim.api.nvim_set_hl(0, group_name, { bg = compose_color(mixed_color), fg = base_hl.fg })
		table.insert(color_groups, group_name)
	end

	if opts.auto_setup then
		opts.auto_setup = false
		ibl_hooks.register(ibl_hooks.type.HIGHLIGHT_SETUP, function()
			make_hl_groups(opts)
		end)
	end

	return color_groups
end

-- Mutate the given indent_blankline options to have rainbow space characters
local function make_opts(blank_opts, rainbow_opts)
	blank_opts = blank_opts or {}
	if not blank_opts.indent then
		blank_opts.indent = {}
	end
	if not blank_opts.whitespace then
		blank_opts.whitespace = {}
	end
	if not blank_opts.scope then
		blank_opts.scope = {}
	end
	rainbow_opts = rainbow_opts or {}

	-- Force blankline to setup Ibl* highlight groups incase we
	-- use them and blankline doesn't bother to set them up later (in its `setup`)
	-- since we specified RainbowColor* hightlights
	require("ibl.highlights").setup()

	local hl_colors = make_hl_groups({
		colors = rainbow_opts.colors,
		color_transparency = rainbow_opts.color_transparency,
		hl = { blank_opts.indent.highlight or "IblIndent", "Normal" },
		prefix = "RainbowColor",
		auto_setup = true,
	})
	local hl_context_colors = make_hl_groups({
		colors = rainbow_opts.colors,
		color_transparency = rainbow_opts.color_transparency,
		hl = { blank_opts.scope.highlight or "IblScope", "Whitespace", "Normal" },
		prefix = "RainbowColorScope",
		auto_setup = true,
	})

	blank_opts.indent.highlight = hl_colors
	blank_opts.whitespace.highlight = hl_colors
	blank_opts.scope.highlight = hl_context_colors

	return blank_opts
end

return {
	make_opts = make_opts,
	make_hl_groups = make_hl_groups,
}
