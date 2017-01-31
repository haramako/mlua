#!/usr/bin/env ruby

require_relative 'parser.tab'
require_relative 'parser'

module Mlua
end

begin
  parser = Mlua::Parser.new(IO.binread(ARGV[0]), ARGV[0])
  parser.parse
rescue Mlua::CompileError => err
  puts "#{err.filename}:#{err.line_no}:#{err}"
  raise
end
