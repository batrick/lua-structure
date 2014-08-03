local math = require "math"
local floor = math.floor

local string = require "string"
local format = string.format

local table = require "table"

local _G = _G
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

local FAILURE = {} -- distinct from nil
local function failed(r) return r == FAILURE end

local S = {}

local M = {
  __add = function (a, b)
    a = S.tostructure(a)
    b = S.tostructure(b)
    return S.new(function (self, ...)
        local result, error1 = a:checker(...)
        if not failed(result) then return result end
        local result, error2 = b:checker(...)
        if not failed(result) then return result end
        return FAILURE
      end,
      a.error.." or "..b.error
    )
  end,
  __div = function (a, test)
    a = S.tostructure(a)
    assert(type(test) == "function", "structure divider must be function");
    return S.new(function (self, value, ...)
        local result, error = a:checker(value, ...)
        if failed(result) then return FAILURE, error end
        local result, error = test(result, ...) -- cascade
        if failed(result) then return FAILURE, error end
        return result
      end,
      a.error
    )
  end,
  __mul = function (a, b)
    a = S.tostructure(a)
    b = S.tostructure(b)
    return S.new(function (self, value, ...)
        local result, error = a:checker(value, ...)
        if failed(result) then return FAILURE, error end
        local result, error = b:checker(result, ...) -- cascade
        if failed(result) then return FAILURE, error end
        return result
      end,
      b.error.." and "..a.error
    )
  end,
  __sub = function (a, b)
    return -b.tostructure(b) * a
  end,
  __unm = function (a)
    a = S.tostructure(a)
    return S.new(function (self, ...)
        local result, error = a:checker(value, ...)
        if not failed(result) then return FAILURE, a.error end
        return ...
      end,
      b.error.." and "..a.error
    )
  end,
  __index = S,
}

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
    return S.new(function (self, o) if o == value then return o else return FAILURE end end, stringify(value))
  elseif t == "table" then
    if not (#value == 1 or #value == 0) then
      error "structure can only have one array entry to represent values for entire array"
    end
    local contents = {}
    for k, v in next, value do
      if k == 1 then -- array
        local sk = S.T.NUMBER / function (n, container)
          assert(type(n) == "number")
          if n >= 1 and n <= rawlen(container) and floor(n) == n then
            return n
          else
            return FAILURE
          end
        end
        local sv = S.tostructure(v)
        contents[sk] = sv
      else -- everything else
        contents[S.tostructure(k)] = S.tostructure(v)
      end
    end
    local structure = S.T.TABLE / function (t, container, key, chain)
      chain = chain or {stringify(t)}
      local found = {}
      for sk in next, contents do found[sk] = false end
      local n = rawlen(t)
      for k, v in next, t do
        chain[#chain+1] = "["..stringify(k).."]"
        local foundkey = false
        for sk, sv in next, contents do
          local kresult = sk:checker(k, t, k, chain)
          if not failed(kresult) then
            local vresult = sv:checker(v, t, k, chain)
            if not failed(vresult) then
              if kresult ~= k and vresult ~= v then
                rawset(t, kresult, vresult)
              elseif kresult ~= k then
                rawset(t, kresult, v)
              elseif vresult ~= v then
                rawset(t, k, vresult)
              end
              found[sk] = true
              foundkey = true
            else
              return FAILURE, stringify(v).." did not have expected value ("..sv.error..") in structure `"..table.concat(chain).."'"
            end
          end
        end
        chain[#chain] = nil
        if not foundkey then
          return FAILURE, "key "..stringify(k).." is not a valid member of structure `"..table.concat(chain).."'"
        end
      end
      for sk in next, contents do
        if not found[sk] and failed(contents[sk]:checker(nil, t)) then
          return FAILURE, "container `"..table.concat(chain).."' is missing required key ("..sk.error..")"
        end
      end
      return t
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
  local result, error = self:checker(...)
  if failed(result) then
    return nil, error
  else
    return result
  end
end

function new (structure)
  return S.tostructure(structure)
end

local function primitive (t)
  return S.new(function (self, o) if type(o) == t then return o else return FAILURE end end, "istype("..t..")")
end

S.T = {}
S.T.BOOLEAN = primitive "boolean"
S.T.FUNCTION = primitive "function"
S.T.NIL = primitive "nil"
S.T.NOTNIL = S.new(function (self, o) if o ~= nil then return o else return FAILURE end end, "isnot(nil)")
S.T.NUMBER = primitive "number"
S.T.STRING = primitive "string"
S.T.TABLE = primitive "table"
S.T.THREAD = primitive "thread"
S.T.USERDATA = primitive "userdata"
for k, v in next, S.T do _ENV[k] = v end

return _ENV
