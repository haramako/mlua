require 'find'

task :yacc do
  sh 'racc -v parser.y'
end

task :lua_test do
  Find.find('C:\Program Files (x86)\Lua\5.1\examples') do |f|
    next unless f.match  /\.lua$/
    puts f
    sh 'ruby', 'mlua.rb', f
  end
end
