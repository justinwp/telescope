#!/usr/bin/env lua
local telescope = require 'telescope'

pcall(require, "luarocks.require")
pcall(require, "shake")

package.path = "./?.lua;" .. package.path

local function luacov_report()
  local luacov = require("luacov.stats")
  local data = luacov.load_stats()
  if not data then
     print("Could not load stats file "..luacov.statsfile..".")
     print("Run your Lua program with -lluacov and then rerun luacov.")
     os.exit(1)
  end
  local report = io.open("coverage.html", "w")
  report:write('<!DOCTYPE html>', "\n")
  report:write([[
  <html>
  <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <title>Luacov Coverage Report
  </title>
  <style type="text/css">
    body { text-align: center; }
    #wrapper { width: 800px; margin: auto; text-align: left; }
    pre, ul, li { margin: 0; padding: 0 }
    li { list-style-type: none; font-size: 11px}
    .covered { background-color: #98FB98 }
    .uncovered { background-color: #FFC0CB }
    .file { width: 800px;
      background-color: #c0c0c0;
      padding: 3px;
      overflow: hidden;
      -webkit-border-radius: 5px;
      -moz-border-radius: 5px;
      border-radius: 5px; }
  </style>
  </head>
  <body>
  <div id="wrapper">
  <h1>Luacov Code Coverage Report</h1>
  ]])
  report:write("<p>Generated on ", os.date(), "</p>\n")

  local names = {}
  for filename, _ in pairs(data) do
     table.insert(names, filename)
  end

  local escapes = {
    [">"] = "&gt;",
    ["<"] = "&lt;"
  }
  local function escape_html(str)
    return str:gsub("[<>]", function(a) return escapes[a] end)
  end

  table.sort(names)

  for _, filename in ipairs(names) do
     if string.match(filename, "/luacov/") or
        string.match(filename, "/luarocks/") or
        string.match(filename, "/tsc$")
     then
       break
     end
     local filedata = data[filename]
     filename = string.gsub(filename, "^%./", "")
     local file = io.open(filename, "r")
     if file then
        report:write("<h2>", filename, "</h2>", "\n")
        report:write("<div class='file'>")
        report:write("<ul>", "\n")
        local line_nr = 1
        while true do
           local line = file:read("*l")
           if not line then break end
           if line:match("^%s*%-%-") then -- Comment line

           elseif line:match("^%s*$")    -- Empty line
             or line:match("^%s*end,?%s*$") -- Single "end"
             or line:match("^%s*else%s*$") -- Single "else"
             or line:match("^%s*{%s*$") -- Single opening brace
             or line:match("^%s*}%s*$") -- Single closing brace
             or line:match("^#!") -- Unix hash-bang magic line
           then
              report:write("<li><pre>", string.format("%-4d", line_nr), "      ", escape_html(line), "</pre></li>", "\n")
           else
              local hits = filedata[line_nr]
              local class = "uncovered"
              if not hits then hits = 0 end
              if hits > 0 then class = "covered" end
              report:write("<li>", " <pre ", "class='", class, "'>", string.format("%-4d", line_nr), string.format("%-4d", hits), "&nbsp;", escape_html(line), "</pre></li>", "\n")
           end
           line_nr = line_nr + 1
        end
     end
     report:write("</ul>", "\n")
     report:write("</div>", "\n")
  end
  report:write([[
</div>
</body>
</html>
  ]])
end

local function getopt(arg, options)
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub(v, 1, 2) == "--" then
      local x = string.find(v, "=", 1, true)
      if x then tab[string.sub(v, 3, x - 1)] = string.sub(v, x + 1)
      else tab[string.sub(v, 3)] = true
      end
    elseif string.sub(v, 1, 1) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while (y <= l) do
        jopt = string.sub(v, y, y)
        if string.find(options, jopt, 1, true) then
          if y < l then
            tab[jopt] = string.sub(v, y + 1)
            y = l
          else
            tab[jopt] = arg[k + 1]
          end
        else
          tab[jopt] = true
        end
        y = y + 1
      end
    end
  end
  return tab
end

local callbacks = {}

local function progress_meter(t)
  io.stdout:write(t.status_label)
end

local function show_usage()
  local text = [[
Telescope

Usage: tsc [options] [files]

Description:
  Telescope is a test framework for Lua that allows you to write tests
  and specs in a TDD or BDD style.

Options:

  -f,     --full            Show full report
  -q,     --quiet           Show don't show any stack traces
  -s      --silent          Don't show any output
  -h,-?   --help            Show this text
  -v      --version         Show version
  -c      --luacov          Output a coverage file using Luacov (http://luacov.luaforge.net/)
          --load=<file>     Load a Lua file before executing command
          --name=<pattern>  Only run tests whose name matches a Lua string pattern
          --shake           Use shake as the front-end for tests

  Callback options:
    --after=<function>        Run function given after each test
    --before=<function>       Run function before each test
    --err=<function>          Run function after each test that produces an error
    --fail<function>          Run function after each failing test
    --pass=<function>         Run function after each passing test
    --pending=<function>      Run function after each pending test
    --unassertive=<function>  Run function after each unassertive test

  An example callback:

    tsc --after="function(t) print(t.status_label, t.name, t.context) end" example.lua

An example test:

context("A context", function()
  before(function() end)
  after(function() end)
  context("A nested context", function()
    test("A test", function()
      assert_not_equal("ham", "cheese")
    end)
    context("Another nested context", function()
      test("Another test", function()
        assert_greater_than(2, 1)
      end)
    end)
  end)
  test("A test in the top-level context", function()
    assert_equal(1, 1)
  end)
end)

Project home:
  http://telescope.luaforge.net/

License:
  MIT/X11 (Same as Lua)

Author:
  Norman Clarke <norman@njclarke.com>. Please feel free to email bug
  reports, feedback and feature requests.
]]
  print(text)
end

local function add_callback(callback, func)
  if callbacks[callback] then
    if type(callbacks[callback]) ~= "table" then
      callbacks[callback] = {callbacks[callback]}
    end
    table.insert(callbacks[callback], func)
  else
    callbacks[callback] = func
  end
end

local function process_args(arg)
  local files = {}
  local opts = getopt(arg, "")
  local i = 1
  for _, _ in pairs(opts) do i = i+1 end
  while i <= #arg do table.insert(files, arg[i]) ; i = i + 1 end
  return opts, files
end

return function(arg)
   local opts, files = process_args(arg)
   if opts["h"] or opts["?"] or opts["help"] or not (next(opts) or next(files)) then
     show_usage()
     os.exit()
   end

   if opts.v or opts.version then
     print(telescope.version)
     os.exit(0)
   end

   if opts.c or opts.luacov then
     require "luacov.tick"
   end

   -- load a file with custom functionality if desired
   if opts["load"] then dofile(opts["load"]) end

   local test_pattern
   if opts["name"] then
     test_pattern = function(t) return t.name:match(opts["name"]) end
   end

   -- set callbacks passed on command line
   local callback_args = { "after", "before", "err", "fail", "pass",
     "pending", "unassertive" }
   for _, callback in ipairs(callback_args) do
     if opts[callback] then
       add_callback(callback, loadstring(opts[callback])())
     end
   end

   local contexts = {}
   if opts["shake"] then
     for _, file in ipairs(files) do shake.load_contexts(file, contexts) end
   else
     for _, file in ipairs(files) do telescope.load_contexts(file, contexts) end
   end

   local buffer = {}
   local results = telescope.run(contexts, callbacks, test_pattern)
   local summary, data = telescope.summary_report(contexts, results)

   if opts.f or opts.full then
     table.insert(buffer, telescope.test_report(contexts, results))
   end

   if not opts.s and not opts.silent then
     table.insert(buffer, summary)
     if not opts.q and not opts.quiet then
       local report = telescope.error_report(contexts, results)
       if report then
         table.insert(buffer, "")
         table.insert(buffer, report)
       end
     end
   end

   if #buffer > 0 then print(table.concat(buffer, "\n")) end

   if opts.c or opts.coverage then
     luacov_report()
     os.remove("luacov.stats.out")
   end

   for _, v in pairs(results) do
     if v.status_code == telescope.status_codes.err or
       v.status_code == telescope.status_codes.fail then
       os.exit(1)
     end
   end
end
