local math = require "math"
local floor = math.floor

local string = require "string"
local format = string.format

local table = require "table"

local assert = assert
local error = error
local getmetatable = getmetatable
local next = next
local rawlen = rawlen
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local tostring = tostring
local type = type

_ENV = {}

--[[
structure.new {
  probes = structure.table {
    {
      path = structure.STRING,
      matcher = structure.STRING + structure.FUNCTION,
    }, /* array! */
    [S.STRING] = S.STRING + S.NIL, -- simple <string, string> pairs allowed
  } / function (v, s, c) return #v >= 1 and v or nil end,
  foo = structure.table {
    n = structure.NUMBER / function (a, structure, container) if a >= 0 and a <= 5 then return a else return nil end end,
    cacheable = structure.BOOLEAN + structure.NIL / function (a, s, c) return false end,
    host = structure.STRING / function (hostname, structure, container) return ishostname(hostname) end,
  } + structure.NIL,
  file = S.NOTNIL / function (v, s, c) if io.type(v) then return v else return nil end,
}
--]]

local S = {}

local M = {
  __add = function (a, b)
    a = S.tostructure(a)
    b = S.tostructure(b)
    return S.new(function (self, ...)
        local asuccess, anewvalue = a:check(...)
        if asuccess then return asuccess, anewvalue end
        local bsuccess, bnewvalue = b:check(...)
        if bsuccess then return bsuccess, bnewvalue end
        return nil, nil
      end,
      a.error.." or "..b.error
    )
  end,
  __div = function (a, test)
    a = S.tostructure(a)
    if type(test) == "function" then
      return S.new(function (self, ...)
          local asuccess, anewvalue = a:check(...)
          if not asuccess then return nil, anewvalue end
          local tsuccess, tnewvalue = test(...)
          if not tsuccess then return nil, tnewvalue end
          return true, tnewvalue
        end,
        a.error
      )
    else
      error "structure divider must be function"
    end
  end,
  __sub = function (a, b)
    a = S.tostructure(a)
    b = S.tostructure(b)
    return S.new(function (self, ...)
        local bsuccess, bnewvalue = b:check(...)
        if bsuccess then return nil, bnewvalue end -- should return bnewvalue?
        local asuccess, anewvalue = a:check(...)
        if not asuccess then return nil, anewvalue end
        return true, anewvalue
      end,
      "not "..b.error.." and "..a.error
    )
  end,
  __index = S,
}

local function primitive (t)
  return S.new(function (self, o) return type(o) == t end, "istype("..t..")")
end

local function stringify (value)
  if type(value) == "string" then
    return string.format("%q", value)
  else
    return tostring(value)
  end
end

function S.tostructure (value)
  if getmetatable(value) == M then return value end
  local t = type(value)
  if t == "boolean" or t == "nil" or t == "number" or t == "string" then
    return S.new(function (self, o) return o == value end, stringify(value))
  elseif t == "table" then
    if not (#value == 1 or #value == 0) then
      error "structure can only have one array entry to represent values for entire array"
    end
    local structure = primitive "table"
    local contents = {}
    for key, value in next, value do
      if key ~= 1 then -- omit array sugar
        contents[S.tostructure(key)] = S.tostructure(value)
      end
    end
    if rawget(value, 1) then -- array sugar
      local key = primitive "number" / function (n, container)
        return n >= 1 and n <= rawlen(container) and floor(n) == n
      end
      local value = S.tostructure(rawget(value, 1))
      contents[key] = value
    end
    structure = structure / function (t, container, key, chain)
      if type(chain) == "nil" then
        chain = {stringify(t)}
      end
      local found = {}
      for sk in next, contents do found[sk] = false end
      local n = rawlen(t)
      for k, v in next, t do
        chain[#chain+1] = "["..stringify(k).."]"
        local foundkey = false
        for sk, sv in next, contents do
          local success, newkey = sk:check(k, t, k, chain)
          if success then
            local success, newvalue = sv:check(v, t, k, chain)
            if success then
              if newkey ~= nil and newvalue ~= nil then
                rawset(t, newkey, newvalue)
              elseif newkey ~= nil then
                rawset(t, newkey, v)
              elseif newvalue ~= nil then
                rawset(t, k, newvalue)
              end
              found[sk] = true
              foundkey = true
            else
              error("key "..stringify(k).." did not have expected value ("..sv.error..") in structure `"..table.concat(chain).."'")
            end
          end
        end
        chain[#chain] = nil
        if not foundkey then
          error("key "..stringify(k).." is not a valid member of structure `"..table.concat(chain).."'")
        end
      end
      for sk in next, contents do
        if not found[sk] and not contents[sk]:check(nil, t) then
          error("container `"..table.concat(chain).."' is missing required key ("..sk.error..")")
        end
      end
      return true
    end
    return structure
  else
    return assert(S.T[t:upper()])
  end
end

function S.new (checker, error)
  assert(type(checker) == "function")
  local o = {
    checker = checker,
    error = error,
  }
  return setmetatable(o, M)
end

function S:check (...)
  return not not self:checker(...)
end


S.T = {}
S.T.BOOLEAN = primitive "boolean"
S.T.FUNCTION = primitive "function"
S.T.NIL = primitive "nil"
S.T.NUMBER = primitive "number"
S.T.STRING = primitive "string"
S.T.TABLE = primitive "table"
S.T.THREAD = primitive "thread"
S.T.USERDATA = primitive "userdata"

S.T.NOTNIL = S.new(function (self, o) return o ~= nil end, "isnot(nil)")

function new (structure)
  return S.tostructure(structure)
end

for k, v in next, S.T do _ENV[k] = v end

return _ENV
