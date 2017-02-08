#!/usr/bin/env ruby
# coding: utf-8

require_relative 'parser.tab'
require_relative 'parser'

require_relative 'consts'
require_relative 'util'
require_relative 'table'
require_relative 'std'
require_relative 'state'

require 'pp'

=begin
ARGV.each do |file|
  lua = Mlua::State.new
  lua.load_file(file)
  lua.run
end
=end

begin
  parser = Mlua::Parser.new(IO.binread(ARGV[0]), ARGV[0])
  chunk = parser.parse
  pp chunk
rescue Mlua::CompileError => err
  puts "#{err.filename}:#{err.line_no}:#{err}"
  raise
end
