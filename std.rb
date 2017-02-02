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

      def assert(cond)
        if !cond
          raise "assert failed!"
        end
        nil
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
    end

    module Debug
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

    module Math
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
    end

    module StdString
      def find(s, pattern, init, plain)
        true
      end

      def gsub(s, pattern, repl, n)
        ""
      end
    end

  end

end
