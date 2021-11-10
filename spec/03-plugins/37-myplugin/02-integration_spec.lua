local helpers = require "spec.helpers"
local cjson   = require "cjson"


local PLUGIN_NAME = "myplugin"


for _, strategy in helpers.all_strategies() do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    local client

    lazy_setup(function()

      --local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })
      local bp = helpers.get_db_utils(strategy, {
        "routes",
        "services",
        "plugins",
        "upstreams",
        "targets",
      })

      local service1 = bp.services:insert{
        host     = "europe_cluster",
        name     = "europe-service",
        path     = "/anything",
      }

      local upstream1 = bp.upstreams:insert{
        name = "europe_cluster"
      }

      local upstream2 = bp.upstreams:insert{
        name = "italy_cluster"
      }

      local target1 = bp.targets:insert{
        target = "httpbin.org:80",
        upstream = upstream1 
      }

      local target2 = bp.targets:insert{
        target = "54.156.165.4:80",
        upstream = upstream1 
      }

      local route1 = bp.routes:insert({
        name = "local-route",
        paths = { "/local" },
        service = service1

      })

      local target3 = bp.targets:insert{
        target = "18.232.227.86:80",
        upstream = upstream2
      }

      -- add the plugin to test to the route we created
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = {},
      }

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
        -- write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2 
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "   
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end


    describe("response", function()
      it("verifies that the request proxies to the correct upstream with 'Italy' as 'X-Country' header", function()
        local r = client:get("/local", {
          headers = {
            ["X-Country"] = "Italy"
          }
        })
        -- validate that the request succeeded, response status 200
        assert.response(r).has.status(200)

        -- validate that the correct host IP address was called i.e. the right upstream
        local body = assert.res_status(200, r)
        local json_response = cjson.decode(body)
        local expected_host_header_value = "18.232.227.86" -- same host as italy_cluster upstream
        assert.equal(json_response.headers["Host"], expected_host_header_value)
        
      end)
    end)

    function table_contains(tbl, x)
      for _, v in pairs(tbl) do
        if v == x then 
          return true
        end
      end
      return false
    end

    describe("response", function()
      it("verifies that the request proxies to the correct upstream with no 'X-Country' header", function()
        local r = client:get("/local", {
          headers = {
          }
        })
        -- validate that the request succeeded, response status 200
        assert.response(r).has.status(200)

        -- validate that the correct host IP address was called i.e. the right upstream
        local body = assert.res_status(200, r)
        local json_response = cjson.decode(body)
        local expected_host_header_values = {"httpbin.org", "54.156.165.4"} -- same hosts as europe_cluster upstream

        assert(table_contains(expected_host_header_values, json_response.headers["Host"]))
        
      end)
    end)

    describe("response", function()
      it("verifies that the request proxies to the correct upstream with not 'Italy' as 'X-Country' header", function()
        local r = client:get("/local", {
          headers = {
            ["X-Country"] = "any other country"
          }
        })
        -- validate that the request succeeded, response status 200
        assert.response(r).has.status(200)

        -- validate that the correct host IP address was called i.e. the right upstream
        local body = assert.res_status(200, r)
        local json_response = cjson.decode(body)
        local expected_host_header_values = {"httpbin.org", "54.156.165.4"} -- same hosts as europe_cluster upstream

        assert(table_contains(expected_host_header_values, json_response.headers["Host"]))
        
      end)
    end)

  end)
end
