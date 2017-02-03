require 'find'

if /darwin/ =~ RUBY_PLATFORM
  LUA='lua5.3'
  LUAC='luac5.3'
else
  LUA='lua53'
  LUAC='luac53'
end

task :yacc do
  sh 'racc -v parser.y'
end

task :t1 do
  sh LUAC, '-l', 't1.lua'
  # sh LUAC, 't1.lua'
  sh 'ruby', 'mlua.rb', 'luac.out'
end

task :test do
  ['code.lua', 'constructs.lua', 'vararg.lua'].each do |f|
    sh 'ruby', 'mlua.rb', 'luatest/' + f
  end
end

task :lua_test do
  Find.find('C:\Program Files (x86)\Lua\5.1\examples') do |f|
    next unless f.match  /\.lua$/
    puts f
    sh 'ruby', 'mlua.rb', f
  end
end
