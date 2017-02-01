local hoge = 1
print(hoge)

local function fuga(a)
   local x
   function piyo()
	  print(hoge,x)
   end
end

fuga(3)
