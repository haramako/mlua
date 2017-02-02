module Mlua

  class ZIO
    attr_reader :s
    
    def initialize(s)
      @s = s
    end
    
    def read(n)
      s.read(n)
    end

    def read_byte()
      @s.read(1).ord
    end
    
    def read_int()
      @s.read(4).unpack('l')[0]
    end
    
    def read_integer()
      @s.read(8).unpack('q')[0]
    end

    def read_number()
      @s.read(8).unpack('D')[0]
    end

    def read_double()
      @s.read(8).unpack('D')[0]
    end
    
    def read_string()
      size = @s.read(1).ord
      size = load_vector(s) if size == 0xff
      if size == 0
        ""
      else
        s.read(size-1)
      end
    end

    def read_vector
      raise
    end

  end

  class RubyFunction < Struct.new(:name, :proc, :arity)
    def inspect
      "#<RubyFunction #{name} #{arity}>"
    end
    alias to_s inspect
  end
  
  class Function
    attr_reader :filename, :insts, :debug_infos, :consts, :protos, :upvals,
                :param_num, :is_vararg, :max_stack_size, :line_start, :line_end
    
    def initialize(z, filename_ = nil)
      @filename = filename_
      @name = z.read_string
      @line_start = z.read_int
      @line_end = z.read_int
      @param_num = z.read_byte
      @is_vararg = z.read_byte
      @max_stack_size = z.read_byte
      
      size = z.read_int
      @insts = z.read(size*4).unpack('L*')
      
      size = z.read_int
      @consts = (0...size).map do |i|
        type = z.read_byte
        case type
        when LUA_TNIL
          nil
        when LUA_TBOOLEAN
          z.read_byte
        when LUA_TNUMFLT
          z.read_double
        when LUA_TNUMINT
          z.read_integer
        when LUA_TSHRSTR, LUA_TLNGSTR
          z.read_string
        else
          raise "unknown type #{type}"
        end
      end
      
      size = z.read_int
      @upvals = (0...size).map do
        z.read(2).unpack('CC')
      end
      
      size = z.read_int
      @protos = (0...size).map do
        @protos = Function.new(z, @filename)
      end

      size = z.read_int
      @debug_infos = (0...size).map do
        z.read_int
      end

      size = z.read_int
      @local_vars = (0...size).map do
        [z.read_string, z.read_int, z.read_int]
      end
      
      size = z.read_int
      @upval_names = (0...size).map do
        z.read_string
      end
    end

    def dump(recursive=true)
      puts "function <#{@name}:#{@line_start},#{@line_end}> (#{@insts.size} instructions at 0x#{self.__id__})"
      puts "#{@param_num} params, #{@max_stack_size} slots, #{@upval_names.size} upvalues, #{@local_vars.size} locals, #{@consts.size} contants, #{@protos.size} functions"
      @insts.each.with_index do |inst,i|
        puts "%5d [%3d] %-30s" % [i+1, @debug_infos[i], Inst.inst_to_str(inst)]
      end
      puts 'upvals ' + @upvals.inspect
      if recursive
        @protos.each do |f|
          puts
          f.dump
        end
      end
    end
  end

  class Chunk
    attr_reader :main
    
    def initialize(str, filename_ = nil)
      @filename = filename_
      z = ZIO.new(StringIO.new(str))
      (@magic, @magic_lua,
       @version_majar, @version_minor,
       *@luac_data,
       @int_size, @size_t_size, @inst_type_size, @lua_integer_size, @lua_number_size
      ) = z.s.read(17).unpack('ca3c2c6C5')
      @luac_int = z.read_integer
      @luac_num = z.read_number
      @inst_size = z.read_byte
      @main = Function.new(z, @filename)
    end

  end

  module Inst
    module_function

    def opcode(inst)
      inst & 0x3f
    end
    
    def a(inst)
      (inst >> 6) & 0xff
    end

    def ax(inst)
      -1 - (inst >> 6)
    end
    
    def b(inst)
      r = (inst >> 23) & 0x1ff
      if r >= 0x100 then 0x0ff - r else r end
    end

    def bx(inst)
      (inst >> 14)
    end

    def sbx(inst)
      (inst >> 14) - 0x1ffff
    end
    
    def c(inst)
      r = (inst >> 14) & 0x1ff
      if r >= 0x100 then 0x0ff - r else r end
    end
    
    def inst_to_a(inst)
      code = opcode(inst)
      optype = OPCODE_TYPES[code]
      opname = OPCODE_NAMES[code]
      case optype
      when :A
        [opname, a(inst)]
      when :AB
        [opname, a(inst), b(inst)]
      when :ABx
        [opname, a(inst), bx(inst)]
      when :AsBx
        [opname, a(inst), sbx(inst)]
      when :ABC
        [opname, a(inst), b(inst), c(inst)]
      when :AC
        [opname, a(inst), c(inst)]
      else
        raise "invalid optype #{optype}"
      end
    end

    def inst_to_str(inst)
      a = inst_to_a(inst)
      if a.size == 4
        '%-8s %d %d %d' % a
      elsif a.size == 3
        '%-8s %d %d' % a
      else
        '%-8s %d' % a
      end
    end
  end

end
