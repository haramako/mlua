function vararg (...) return {n = select('#', ...), ...} end

local call = function (f, args) return f(table.unpack(args, 1, args.n)) end

local G={'a', 'b', 'c'}

print('X', next(G,nil))
print('X', call(next, {G,nil;n=2}))
local a = vararg(call(next, {G,nil;n=2}))
local b,c = next(G)
print('A',a,b,c)

--[[
function fib(n)
   if n <= 1 then
	  return 1
   else
	  return fib(n-1) + fib(n-2)
   end
end

-- 1 1 2 3 5 8 13 21 34 55 89
-- print(fib(5))
print('hoge'..'fuga')
--]]
