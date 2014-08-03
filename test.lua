local S = require "structure"

local s = S.new {
  a = S.NUMBER + S.NIL
}

assert(s:check { a = 1 })

s = S.BOOLEAN
assert(s:check(true))
assert(s:check(false) == false)
s = S.NIL
assert(s:check(nil) == nil)
s = S.NUMBER
assert(s:check(1))
s = S.FUNCTION
assert(s:check(function()end))
s = S.STRING
assert(s:check(""))
s = S.TABLE
assert(s:check({}))
s = S.new {}
assert(s:check({}))

local s = S.new {
  probes = {
    path = S.STRING,
    matcher = S.STRING + S.FUNCTION,
  },
  matches = {
    s = 1,
  }
}

assert(function() s:check { probes = { path = '', matcher = function() end }, matches = { s = 1 } } end)
assert(function() s:check { probes = { path = '', matcher = nil }, matches = { s = 1 } } end)

local s = S.new {
  ["probes" + S.BOOLEAN] = {
    { -- array
      path = S.STRING,
      matcher = S.STRING / string.lower + S.FUNCTION,
    },
  },
  matches = {
    s = 1,
  }
}

assert(s:check { probes = { {path = '', matcher = function() end}, }, matches = { s = 1 }, })
local a = assert(s:check { probes = { {path = '', matcher = "Hi"}, }, matches = { s = 1 }, })
assert(a.probes[1].matcher == "hi")
assert(not s:check { matches = { s = 1 }, })
