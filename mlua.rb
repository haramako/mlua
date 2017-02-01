#!/usr/bin/env ruby
# coding: utf-8

require_relative 'parser.tab'
require_relative 'parser'

require 'pp'

module Mlua
  
  LUAI_MAXSHORTLEN = 40
  
  LUA_TNIL = 0
  LUA_TBOOLEAN = 1
  LUA_TLIGHTUSERDATA = 2
  LUA_TNUMBER = 3
  LUA_TSTRING = 4
  LUA_TTABLE = 5
  LUA_TFUNCTION = 6
  LUA_TUSERDATA = 7
  LUA_TTHREAD = 8
  LUA_NUMTAGS = 9
  
  LUA_TSHRSTR = LUA_TSTRING | (0 << 4)
  LUA_TLNGSTR = LUA_TSTRING | (1 << 4)
  LUA_TNUMFLT = LUA_TNUMBER | (0 << 4)
  LUA_TNUMINT = LUA_TNUMBER | (1 << 4)
  
  OPCODE_DEFINE = <<EOT
    OP_MOVE     AB
    OP_LOADK    ABx
    OP_LOADKX   A
    OP_LOADBOOL ABC
    OP_LOADNIL  AB
    OP_GETUPVAL AB

    OP_GETTABUP ABC
    OP_GETTABLE ABC

    OP_SETTABUP ABC
    OP_SETUPVAL AB
    OP_SETTABLE ABC

    OP_NEWTABLE AB

    OP_SELF     ABC

    OP_ADD      ABC
    OP_SUB      ABC
    OP_MUL      ABC
    OP_MOD      ABC
    OP_POW      ABC
    OP_DIV      ABC
    OP_IDIV     ABC
    OP_BAND     ABC
    OP_BOR      ABC
    OP_BXOR     ABC
    OP_SHL      ABC
    OP_SHR      ABC
    OP_UNM      AB
    OP_BNOT     AB
    OP_NOT      AB
    OP_LEN      AB

    OP_CONCAT   ABC

    OP_JMP      AsBx
    OP_EQ       ABC
    OP_LT       ABC
    OP_LE       ABC

    OP_TEST     AC
    OP_TESTSET  ABC

    OP_CALL     ABC
    OP_TAILCALL ABC
    OP_RETURN   AB

    OP_FORLOOP  AsBx
    OP_FORPREP  AsBx

    OP_TFORCALL AC
    OP_TFORLOOP AsBx

    OP_SETLIST  ABx

    OP_CLOSURE  ABx

    OP_VARARG   AB
    
    OP_EXTRAARG Ax
EOT

  OPCODE_TYPES = []
  OPCODE_NAMES = []
  OPCODE_DEFINE.split(/\n/).reject{|x|x.strip==""}.each.with_index do |opstr,i|
    opname, optype = opstr.strip.split(/\s+/)
    const_set opname, i
    OPCODE_NAMES.push opname[3..-1]
    OPCODE_TYPES.push optype.to_sym
  end

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
      @s.read(8).unpack('L')[0]
    end

    def read_number()
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

  class Function
    attr_reader :insts, :debug_infos, :consts, :protos, :upvals
    
    def initialize(z)
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
        @protos = Function.new(z)
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

    def dump
      puts "function <#{@name}:#{@line_start},#{@line_end}> (#{@insts.size} instructions at 0x#{self.__id__})"
      puts "#{@param_num} params, #{@max_stack_size} slots, #{@upval_names.size} upvalues, #{@local_vars.size} locals, #{@consts.size} contants, #{@protos.size} functions"
      @insts.each.with_index do |inst,i|
        puts "%5d [%3d] %-30s" % [i+1, @debug_infos[i], Inst.inst_to_str(inst)]
      end
      @protos.each do |f|
        puts
        f.dump
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
      @main = Function.new(z)
    end

  end

  module Inst
    module_function

    def op_opcode(inst)
      inst & 0x3f
    end
    
    def op_a(inst)
      (inst >> 6) & 0xff
    end

    def op_ax(inst)
      -1 - (inst >> 6)
    end
    
    def op_b(inst)
      r = (inst >> 23) & 0x1ff
      if r >= 0x100 then 0x0ff - r else r end
    end

    def op_bx(inst)
      (inst >> 14)
    end

    def op_sbx(inst)
      -1 - (inst >> 14)
    end
    
    def op_c(inst)
      r = (inst >> 14) & 0x1ff
      if r >= 0x100 then 0x0ff - r else r end
    end
    
    def inst_to_a(inst)
      opcode = op_opcode(inst)
      optype = OPCODE_TYPES[opcode]
      opname = OPCODE_NAMES[opcode]
      case optype
      when :A
        [opname, op_a(inst)]
      when :AB
        [opname, op_a(inst), op_b(inst)]
      when :ABx
        [opname, op_a(inst), - op_bx(inst) - 1]
      when :AsBx
        [opname, op_a(inst), op_sbx(inst)]
      when :ABC
        [opname, op_a(inst), op_b(inst), op_c(inst)]
      else
        raise
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

  class CallInfo
  end

  class Closure
  end

  class State
    def initialize
      @pc = 0
      @stack = []
      @saved_pc = 0
    end

    def load_string(str, filename = nil)
      @chunk = Chunk.new(str, filename)
      @func = @chunk.main
      @chunk.main.dump
    end

    def run
      step(9999)
    end

    def setobj2s(pos, v)
      @stack[pos] = v
    end

    def step(c)
      base = 0
      kst = @func.consts
      upvals = @func.upvals
      pp kst
      pp @func.upvals
      pc = @saved_pc
      while c > 0
        i = @func.insts[pc]
        pc += 1
        opcode = Inst.op_opcode(i)
        ra = base + Inst.op_a(i)
        puts "%4d %s" % [@pc, Inst.inst_to_str(i)]
        pp @stack
        case opcode
        when OP_LOADK
          setobj2s(ra, kst[Inst.op_bx(i)])
        when OP_GETTABUP
          upval = upvals[Inst.op_b(i)]
          p upval
        else
          raise "unknown opcode #{OPCODE_NAMES[opcode]}"
        end
        c -= 1
      end
    end

  end
end


vm = Mlua::State.new
vm.load_string(IO.binread(ARGV[0]))
vm.run
#chunk = Mlua::Chunk.new(IO.binread(ARGV[0]))
# pp chunk

#chunk.main.dump


=begin
begin
  parser = Mlua::Parser.new(IO.binread(ARGV[0]), ARGV[0])
  parser.parse
rescue Mlua::CompileError => err
  puts "#{err.filename}:#{err.line_no}:#{err}"
  raise
end
=end
