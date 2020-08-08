local api = {}
local domainMatch = "^([%l%d-_]*)@?([%l%d-]+).kst$"
local commonMetaMatch = "^(.+)=(.+)$"

local function formPostString(data)
  local out = ""
  for i, v in pairs(data) do
    if i == 1 then
      out = textutils.urlEncode(i) .. "=" .. textutils.urlEncode(v)
    else
      out = out .. "&" .. textutils.urlEncode(i) .. "=" .. textutils.urlEncode(v)
    end
  end

  return out
end

local function parseMeta(meta)
  local tbl = {meta={}}

  for m in meta:gmatch("[^;]+") do
    if m:match(domainMatch) then
      -- print("Matched domain")

      local p1, p2 = m:match("([%l%d-_]*)@"), m:match("@?([%l%d-]+).kst")
      tbl.name = p1
      tbl.domain = p2

    elseif m:match(commonMetaMatch) then
      -- print("Matched common meta")

      local p1, p2 = m:match(commonMetaMatch)

      tbl.meta[p1] = p2

    else
      -- print("Unmatched standard meta")

      table.insert(tbl.meta, m)
    end
    -- print(m)
  end
  -- print(textutils.serialize(tbl))
  return tbl
end

function api.getTimestamp(timestamp)
  local date = timestamp:sub(1, timestamp:find("T") - 1)
  local time = timestamp:sub(timestamp:find("T") + 1, timestamp:find("Z") - 1)

  local y, mo, d = string.match(date, "(%d+)-(%d+)-(%d+)")
  local h, m, s, ms = string.match(time, "(%d+):(%d+):(%d+).(%d+)")

  return y, mo, d, h, m, s, ms
end

function api:new(address, key)
  local o = {
    address = address,
    key = key
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function api:makeTransaction(to, amount, metadata)
  if not self.key then
    error("No key was provided, transactions cannot be made")
  else
    local out = http.post("http://krist.ceriat.net/transactions/", formPostString({
      privatekey = self.key,
      to = to,
      amount = amount,
      metadata = metadata
    }))
    local data = json.decode(out.readAll())
    out.close()

    return data
  end
end

function api:getLastTransaction()
  local out = http.get("https://krist.ceriat.net/transactions/latest?limit=1&excludeMined=true")
  local data = json.decode(out.readAll())
  out.close()
  local tx = data.transactions[1]
  return {
    id = tx.id,
    from = tx.from,
    to = tx.to,
    value = tx.value,
    time = tx.time,
    name = tx.name,
    metadata = parseMeta(tx.metadata)
  }
end

function api:initWesocket()
  local out = http.post("http://krist.ceriat.net/ws/start", formPostString({privatekey = self.key}))
  local data = json.decode(out.readAll())
  out.close()

  local ws, err = http.websocket(data.url)
  self.ws = ws
  while true do
    local e = {os.pullEvent()}
    if e[1] == "websocket_message" then
      local url, contents = e[2], e[3]
      local jsonData = json.decode(contents)
      if jsonData.type == "hello" then
        os.queueEvent("krist", "hello", {
          serverTime = jsonData["server_time"],
          motd = jsonData.motd,
          motdSet = jsonData["motd_set"],
          lastBlock = {
            height = jsonData["last_block"].height,
            address = jsonData["last_block"].address,
            hash = jsonData["last_block"].hash,
            shortHash = jsonData["last_block"]["short_hash"],
            value = jsonData["last_block"].value,
            time = jsonData["last_block"].time,
            difficulty = jsonData["last_block"] .difficulty
          },
          work = jsonData.work
        })
      elseif e[1] == "event" then
        local jsonData = json.decode(contents)
        if jsonData.event == "block" then
          local b = jsonData.block
          os.queueEvent("krist", "block", {
            height = b.height,
            address = b.address,
            hash = b.hash,
            shortHash = b["short_hash"],
            value = b.value,
            time = b.time,
            difficulty = b.difficulty,
            newWork = jaonData["new_work"]
          })
        elseif jsonData.event == "transaction" then
          local t = jsonData.transaction
          os.queueEvent("krist", "transaction", {
            id = t.id,
            from = t.from,
            to = t.to,
            value = t.value,
            time = t.time,
            metadata = parseMeta(t.metadata)
          })
        end

        print(contents)
      end
    end
  end
end

return api
