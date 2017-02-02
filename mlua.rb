#!/usr/bin/env ruby
# coding: utf-8

require_relative 'parser.tab'
require_relative 'parser'

require_relative 'consts'
require_relative 'util'
require_relative 'std'
require_relative 'state'

require 'pp'

lua = Mlua::State.new
lua.load_file(ARGV[0])
puts '='*80
lua.run

=begin
begin
  parser = Mlua::Parser.new(IO.binread(ARGV[0]), ARGV[0])
  parser.parse
rescue Mlua::CompileError => err
  puts "#{err.filename}:#{err.line_no}:#{err}"
  raise
end
=end
