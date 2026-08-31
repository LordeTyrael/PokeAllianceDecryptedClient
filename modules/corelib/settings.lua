g_settings = makesingleton(g_configs.getSettings())

-- Reserved for future functionality

g_settings.getConfig = function(path)
	local path = '/' .. path
	local config = g_configs.load(path)
	if not config then
		config = g_configs.create(path)
	end
	
	return config
end