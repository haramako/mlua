-- testing reuse in constant table

local x = {1,2,3,4}

local y = 0

for _,v in ipairs(x) do
   for _2,v2 in ipairs(x) do
	  print(_,v,_2,v2)
   end
end


-- print(nil>0)

--[=[

fact = false
do
  res = 1
  -- local res = 1
  -- local function fact (n)
  function fact (n)
    if n==0 then return res
    else return n*fact(n-1)
    end
  end
  assert(fact(5) == 120)
end

function hoge()
   local a = 1
   local function fuga()
	  return a
   end
   return fuga()
end

-- print(hoge())
print(fact(5))

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

]=]
