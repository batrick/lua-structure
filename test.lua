local S = require "structure"

local s = S.new {
  a = S.NUMBER + S.NIL
}

assert(s:check { a = 1 })

s = S.BOOLEAN
assert(s:check(true))
s = S.NIL
assert(s:check(nil))
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

assert(s:check { probes = { path = '', matcher = function() end }, matches = { s = 1 } } )

local s = S.new {
  [S.new "probes" + S.BOOLEAN] = {
    {
      path = S.STRING,
      matcher = S.STRING / function(...) print("MATCHERSTRING", ...) return true end + S.FUNCTION,
    },
  },
  matches = {
    s = 1,
  }
}

assert(s:check { probes = { {path = '', matcher = function() end}, }, matches = { s = 1 }, } )
--assert(s:check { probes = 1 })
--assert(s:check { prosbes = { {path = '', matcher = function() end}, }, matches = { s = 1 }, } )
assert(s:check { matches = { s = 1 }, } )
