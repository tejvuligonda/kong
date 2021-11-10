local plugin = {
    PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
    VERSION = "0.1"
}

-- runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)
    kong.log.inspect.on()
    local country_header = kong.request.get_header("X-Country")
    if country_header == "Italy" then
        kong.log.debug("country_header is " .. country_header)
        local other_upstream = plugin_conf.other_upstream
        local ok, err = kong.service.set_upstream(other_upstream)
        if not ok then
            kong.log.notice("can't send to " .. other_upstream)
            kong.log.err(err)
            return
        end
    else
        local main_upstream = plugin_conf.main_upstream
        local ok, err = kong.service.set_upstream(main_upstream)
        if not ok then
            kong.log.notice("can't send to " .. main_upstream)
            kong.log.err(err)
            return
        end
    end
end

-- return our plugin object
return plugin
