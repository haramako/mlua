module Mlua
  module LuaModule
    
    module_function
    def to_table(mod)
      list = mod.instance_methods.map do |name|
        [name.to_s, mod.instance_method(name).bind(nil)]
      end
      Hash[list]
    end
    
    module Global
      def print(*args)
        puts args.join(" ")
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
        when Hash, Array
          'table'
        when Closure, Method, Function
          'function'
        else
          'userdata'
        end
      end

      def next(t, index = nil)
        index ||= 0
        case t
        when Array
          if t.size == 0
            nil
          elsif index-1 < t.size
            index += 1
            MultiValue.new(index, t[index-1])
          else
            nil
          end
        when Hash
          if t.size == 0
            nil
          elsif index-1 < t.size
            index += 1
            MultiValue.new(index, t.values[index-1])
          else
            nil
          end
        else
          raise
        end
      end
      
      def ipairs(t)
        max = t.keys.max
        i = 0
        return proc do
          i += 1
          puts(i)
          if max.nil? or i > max
            nil
          else
            i
          end
        end
      end

      def pairs(t)
        keys = t.keys.select{|x| x.is_a? String}
        i = 0
        MultiValue.new(
          proc do
            if i >= keys.size
              MultiValue.new(nil,nil)
            else
              i += 1
              MultiValue.new([keys[i-1], t[keys[i-1]]])
            end
          end,
          t,
          nil
        )
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
    end

    module Debug
      def getinfo(thread, f, what)
      end
    end
    
    module T
      def listk(func)
        if func.is_a? Closure
          func.func.consts
        else
          raise "arg is not function #{func}"
        end
      end
      
      def listcode(func)
        if func.is_a? Closure
          func.func.insts
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

    module Table
      def unpack(list, i = 1, j = nil)
        case list
        when Array
          j = list.size unless j
          MultiValue.new( *list[i-1..j-1] )
        when Hash
          j = list.keys.select{|n| n.is_a? Numeric}.max unless j
          if j
            MultiValue.new( *(i..j).map{|n| list[n]} )
          else
            MultiValue.new()
          end
        else
          raise
        end
      end
    end

  end

end
