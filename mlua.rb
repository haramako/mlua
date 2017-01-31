#!/usr/bin/env ruby

require_relative 'parser.tab'
require_relative 'parser'

require 'pp'

module Mlua
  
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

  class Chunk
    attr_reader :insts
    
    def initialize(data)
      s = StringIO.new(data)
      (@magic, @magic_lua,
       @version_majar, @version_minor,
       *@luac_data,
       @int_size, @size_t_size, @inst_type_size, @lua_integer_size, @lua_number_size
      ) = s.read(17).unpack('ca3c2c6C5')
      @luac_int = s.read(4).unpack('L')[0].to_s(16)
      @luac_num = s.read(8).unpack('L')[0]
      @inst_size = s.read(1).ord
      pp self
      # @line_start, @line_end, @param_num, @varg_flag, @register_num, @inst_size = s.read(15).unpack('llc3L')
      @insts = s.read(@inst_size*4).unpack('L*')
      @const_size = s.read(4).unpack('L')[0]
      @consts = (0...@const_size).map do |i|
        type = s.read(1).ord
        case type
        when LUA_TNIL
          nil
        when LUA_TNUMBER
          s.read(8).unpack('l')[0]
        when LUA_TSTRING
          # string
          size = s.read(8).unpack('L')[0]
          r = s.read(size-1)
          s.read(1)
          r
        else
          raise "unknown type #{type}"
        end
      end
      
      @proto_size = s.read(4).unpack('L')[0]
      @protos = (0...@proto_size).map do |t|
      end
      
      @upval_size = s.read(4).unpack('L')[0]
      @upvals = (0...@upval_size).map do |t|
        s.read(2).unpack('CC')
      end

      @src_size, @line_size = s.read(8).unpack('LL')
    end

  end

  class VM
    def initialize
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
      (inst >> 14) - 1
    end
    
    def op_sbx(inst)
      -1 - (inst >> 14)
    end
    
    def op_c(inst)
      r = (inst >> 14) & 0x1ff
      if r >= 0x100 then 0x0ff - r else r end
    end
    
    def inst_to_a(inst)
      opcode = inst & 0x3f
      optype = OPCODE_TYPES[opcode]
      opname = OPCODE_NAMES[opcode]
      case optype
      when :A
        [opname, op_a(inst)]
      when :AB
        [opname, op_a(inst), op_b(inst)]
      when :ABx
        [opname, op_a(inst), op_bx(inst)]
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
end


vm = Mlua::VM.new
chunk = Mlua::Chunk.new(IO.binread(ARGV[0]))
# pp chunk

chunk.insts.each.with_index do |inst,i|
  puts "%5d %-30s %08x" % [i+1, vm.inst_to_str(inst), inst]
end


=begin
begin
  parser = Mlua::Parser.new(IO.binread(ARGV[0]), ARGV[0])
  parser.parse
rescue Mlua::CompileError => err
  puts "#{err.filename}:#{err.line_no}:#{err}"
  raise
end
=end
