-- This is a utility to import all chests on the network into a file for Milo.
-- Just run the program with Milo installed, and it should work.

local storage = fs.open("/usr/config/storage", "w")
local types = {"minecraft:ironchest_diamond"}
local output = {}

local peripherals = peripheral.getNames()

function table.contains(tbl, value)
  for i, v in pairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

print("Searching", #peripherals, "peripherals")
local number = 1
for i, v in pairs(peripherals) do
  if table.contains(types, peripheral.getType(v)) then
    output[v] = {
      name = v,
      category = "storage",
      mtype = "storage",
      displayName = "Chest " .. number
    }
    number = number + 1
  end

end

storage.write(textutils.serialise(output))
storage.close()
