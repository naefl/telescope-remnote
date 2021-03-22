local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')


local file = os.getenv( "HOME" ).. "/.remnote/credentials"


local creds = {}
for i in io.lines(file) do
     creds[#creds+1]=i
end

local API_KEY = creds[2]
local USER_ID= creds[1]
local base = {}
local BASE = "https://api.remnote.io/api/v0"
base["apiKey"] = API_KEY
base["userId"] = USER_ID

local function curlEncode(url, payload)
    local cmd = 'curl -s -X POST -H "Content-Type: application/json" -d %s %s'
    return string.format(cmd, vim.fn.shellescape(vim.fn.json_encode(payload)) , url)
end

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

-- the comments are assumed to be the front side of the rem
local cmt_map = {vim='"', lua="--", python="#", bash="#", c="//", go="//"}
local syntax_available = {vim=false, lua=false, python=true, c=true, html=true, javascript=true, go=true,bash=true}

local function split(str, filetype)
    local rest = ""
    local ct = 0
    local front = ""
    local cmtstr = cmt_map[filetype]
    for s in str:gmatch("[^\r\n]+") do
        s  =  string.gsub(s, '^%s*(.-)%s*$', '%1')
        local cmt = string.find(s, cmtstr, 1, true)
        if cmt ==1 then
            -- we're assuming here that every comment
            -- has a space after the commend marker
            local subs = string.sub(s, cmt+#cmtstr+1)
            front = front .. subs
            if ct == 0 then
                front = front .. " "
            end
        else
            rest = rest .. s
        end
        ct = ct+1
    end
    return front, rest
end

local function parseRem(filetype, sel)
    local front, rest = split(sel, filetype)
    if not syntax_available[filetype] then
        filetype = ""
    end

    return string.format('%s::```%s \n %s```',front, filetype , rest)
end


local function search_and_apply(filetype, url, payload)
    local get_by_name = deepCopy(base)
    get_by_name["name"] = filetype
    local get_by_url = BASE .. "/get_by_name"
    local cmd  =  string.format('%s | jq  "._id" | xargs -I{} %s',curlEncode(get_by_url, get_by_name), curlEncode(url,payload))
    return vim.fn.json_decode(vim.fn.system(cmd))
end

local function post(sel, filetype)
    local  payload = deepCopy(base)
    payload["text"] = parseRem( filetype, sel)
    -- this is just the xargs wildcard
    payload["parentId"] = "{}"
    local url = BASE .. "/create"
    local r = search_and_apply(filetype, url, payload)
end

local function _get_children(json, children, count)
    local id = json["_id"]
    if children[id]==nil then
        children[id] = {}
        for k,v in pairs(json) do
            if k == "children" then
                if #v >0 then
                    for _, child in pairs(v) do
                        local payload = deepCopy(base)
                        local url = BASE .. "/get"
                        -- this is just the xargs wildcard
                        payload["remId"] = child
                        count =  count + 1
                        json = vim.fn.json_decode(vim.fn.system(curlEncode(url, payload)))
                        _get_children(json, children)
                    end
                end
            end
            if k == "nameAsMarkdown" then
                children[id] = v
            end
        end
    end
end

local function get(filetype)
    local payload = deepCopy(base)
    local url = BASE .. "/get"
    -- this is just the xargs wildcard
    payload["remId"] = "{}"
    local res = search_and_apply(filetype, url, payload)
    local children ={}
    local count = 1
    _get_children(res, children, count)
    print(count)
    return children
end

local return_picker = function(filetype)
  local res = get(filetype)
  local text= {}
  for k,v in pairs(res) do
      table.insert(text, v)
  end
  pickers.new {
    prompt_title = 'Remnote',
    finder = finders.new_table {
      results = text,
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
      end)

      return true
    end,
  }:find()
end


return {post=post, get=get, return_picker=return_picker}
