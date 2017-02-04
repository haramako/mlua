module Mlua
  module LuaModule
    
    module_function
    def to_table(mod)
      list = mod.instance_methods.map do |name|
        [name.to_s, mod.instance_method(name).bind(nil)]
      end
      Table.new(Hash[list])
    end
    
    module Global
      def print(*args)
        puts args.map(&:inspect).join(", ")
      end

      def assert(*conds)
        conds.each do |cond|
          if !cond
            raise "assert failed!"
          end
        end
        MultiValue.new(*conds)
      end
      
      def require(modname)
        $lua.env[modname]
      end
      
      def tonumber(e, base = 10)
        e.to_i(base)
      end

      def type(v)
        case v
        when Numeric
          'number'
        when String
          'string'
        when TrueClass, FalseClass
          'boolean'
        when Table
          'table'
        when Closure, Method
          'function'
        when nil
          'nil'
        else
          'userdata'
        end
      end

      def next(t, index = nil)
        index ||= 0
        case t
        when Table
          if t.size == 0
            nil
          elsif index-1 < t.size
            index += 1
            MultiValue.new(index, t[index])
          else
            nil
          end
        else
          raise
        end
      end
      
      def ipairs(t)
        # p [:ipairs0, t.array.size, t.__id__, t]
        if false and t.array.size == 100
          pp t
          raise
        end
        iter = proc do |t,idx|
          # p [:ipairs, idx, t.array.size, t.__id__, t]
          idx += 1
          if idx <= t.array.size
            MultiValue.new(idx, t[idx])
          else
            MultiValue.new(nil,nil)
          end
        end
        MultiValue.new(iter, t, 0)
      end

      def pairs(t)
        iter = t.each_pairs
        proc do
          begin
            MultiValue.new(*iter.next)
          rescue StopIteration
            MultiValue.new(nil,nil)
          end
        end
      end

      def select(index, *args)
        if index == '#'
          args.size
        else
          if index < 0
            index = args.size + index + 1
          end
          if args and index-1 < args.size
            MultiValue.new(*args[index-1..-1])
          else
            MultiValue.new()
          end
        end
      end
      
      def load(chunk, chunkname = nil, mode = nil, env = nil)
        chunk
      end
      
      def pcall(f, *args)
        # TODO: not implemented
        false
      end

      def trace()
        $lua.trace = true
      end

    end

    module Debug
      def getinfo(thread, f, what)
      end
    end
    
    module T
      def listk(func)
        if func.is_a? Closure
          Table.new(func.func.consts)
        else
          raise "arg is not function #{func}"
        end
      end
      
      def listcode(func)
        if func.is_a? Closure
          Table.new(func.func.insts)
        else
          raise "arg is not function #{func}"
        end
      end
    end

    module LuaMath
      def type(val)
        case val
        when Float
          'float'
        when Integer
          'integer'
        else
          nil
        end
      end

      def sin(x)
        Math.sin(x)
      end

      def floor(x)
        x.floor
      end

      def max(*args)
        args.max
      end
    end

    module OS
      def time()
        Time.now.to_i
      end

      def exit(code = 0, close = nil)
        exit(code)
      end
    end

    module StdString
      def find(s, pattern, init=nil, plain=nil)
        true
      end

      def gsub(s, pattern, repl, n=nil)
        ""
      end

      def rep(s, n, sep = nil)
        s * n
      end
    end

    module LuaTable
      def unpack(list, i = 1, j = nil)
        case list
        when Table
          MultiValue.new( *list.lua_slice(i,j) )
        else
          raise
        end
      end

      def pack(*args)
        Table.new(args)
      end
    end

  end

end
