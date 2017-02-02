# coding: utf-8

module Mlua
  class CallInfo < Struct.new(:func, :top, :base, :prev, :saved_pc)
    def inspect
      "#<CallInfo #{@func} #{@top} #{@base}>"
    end
    alias to_s inspect
  end

  class Closure < Struct.new(:func, :up_callinfo)
    def inspect
      "#<Closure #{func and func.line_start} #{up_callinfo}>"
    end
    alias to_s inspect
  end

  class MultiValue < Struct.new(:results)
  end

  class State
    attr_reader :env
    
    def initialize
      $lua = self
      
      @pc = 0
      @stack = []
      
      @env = {}
      @env.merge! LuaModule.to_table(LuaModule::Global)
      mods = [
        ['T', LuaModule::T],
        ['math', LuaModule::Math],
        ['string', LuaModule::StdString],
        ['debug', LuaModule::Debug],
      ]
      mods.each do |k,v|
        @env[k] = LuaModule.to_table(v)
      end
    end

    if /darwin/ =~ RUBY_PLATFORM
      LUA='lua5.3'
      LUAC='luac5.3'
    else
      LUA='lua53'
      LUAC='luac53'
    end
    
    def load_file(filename)
      system(LUAC, '-l', filename)
      load_chunk(IO.binread('luac.out'), filename)
    end
    
    def load_chunk(str, filename = nil)
      chunk = Chunk.new(str, filename)
      @stack[0] = Closure.new(chunk.main, nil)
      @ci = CallInfo.new(0, 1, 1, nil)
    end

    def dump
      puts "**STACK**"
      @stack.each.with_index do |v,i|
        if i == @ci.base
          mark = 'base->'
        elsif i == @ci.top
          mark = 'top->'
        else
          mark = ''
        end
        puts "%8s %4d %s" % [mark, i, v]
      end
      puts "**_ENV**"
      @env.each do |k,v|
        puts "%8s = %s" % [k, v]
      end
    end

    def run
      step(9999)
    end

    def setobj2s(pos, v)
      @stack[pos] = v
    end

    def get_upval(upval_idx)
      # MEMO: クロージャは未対応
      @env
    end

    def r(idx)
      if idx >= 0
        @stack[@ci.base+idx]
      else
        raise
      end
    end
    
    def rk(idx)
      if idx >= 0
        @stack[@ci.base+idx]
      else
        @func.consts[-1-idx]
      end
    end

    def precall(func_idx, nresults)
      func = @stack[func_idx]
      case func
      when Method
        if func.arity > 0
          args = @stack[func_idx+1,func.arity]
        else
          args = @stack[func_idx+1...@top]
        end
        result = func.call(*args)
        if result.is_a? MultiValue
          raise "multi value result not implement"
        else
          @stack[func_idx] = result
        end
      when Function
        raise
      when Closure
        # base = func_idx + 1
        if func.func.is_vararg != 0
          # with varargs
          fixed_num = func.func.param_num
          vararg_num = @top - func_idx - fixed_num - 1
          fixed_args = @stack[func_idx+1, fixed_num]
          @stack[func_idx+1, vararg_num] = @stack[func_idx+1+fixed_num, vararg_num]
          @stack[func_idx+1+vararg_num, fixed_num] = fixed_args
          base = @top - fixed_num
        else
          # no varargs
          base = func_idx + 1
        end
        @top = base + func.func.max_stack_size
        @ci = CallInfo.new(func_idx, @top, base, @ci, @pc)
        @pc = 0
      when nil
        raise "function is nil"
      else
        raise "invalid func type #{func.class}"
      end
    end

    def kst(idx)
      @func.consts[idx]
    end

    #def ra(inst)
    #  r(Inst.op_a(inst))
    #end

    def rb(inst)
      r(Inst.b(inst))
    end
    
    def rc(inst)
      r(Inst.c(inst))
    end
    
    def rkb(inst)
      rk(Inst.b(inst))
    end

    def rkc(inst)
      rk(Inst.c(inst))
    end

    BINOP_METHOD = {
      OP_ADD => :+,
      OP_SUB => :-,
      OP_MUL => :*,
      OP_MOD => :%,
      OP_POW => :**,
      OP_DIV => :/,
      OP_IDIV => :/,
      OP_BAND => :&,
      OP_BOR => :|,
      OP_BXOR => :^,
      OP_SHL => :<<,
      OP_SHR => :>>,
    }

    def get_tbl(tbl, idx)
      case tbl
      when Array
        tbl[idx-1]
      when Hash
        tbl[idx]
      when nil
        raise "table is nil"
      else
        raise "invalid tbl #{tbl.class}"
      end
    end

    def set_tbl(tbl, idx, val)
      case tbl
      when Array
        tbl[idx-1] = val
      when Hash
        tbl[idx] = val
      else
        raise "invalid tbl #{tbl.class}"
      end
    end

    def as_bool(v)
      !!v
    end
    
    def step(count)
      while count > 0
        @func = @stack[@ci.func].func
        i = @func.insts[@pc]
        opcode = Inst.opcode(i)
        if i == nil
          raise "nil instruction in #{@pc}"
        end
        a = Inst.a(i)
        ra = @ci.base + a
        puts "%4d [%3d] %s" % [@pc, @func.debug_infos[@pc], Inst.inst_to_str(i)]
        @pc += 1
        # pp @stack
        case opcode
        when OP_MOVE
          setobj2s(ra, rb(i))
        when OP_LOADK
          setobj2s(ra, kst(Inst.bx(i)))
        when OP_LOADKX
          raise
        when OP_LOADBOOL
          setobj2s(ra, Inst.b(i) != 0)
          @pc += 1 if Inst.c(i) != 0
        when OP_LOADNIL
          (0..Inst.b(i)).each do |i|
            setobj2s(ra+i, nil)
          end
        when OP_GETTABUP
          upval = get_upval(Inst.b(i))
          setobj2s(ra, get_tbl(upval, rkc(i)))
        when OP_GETTABLE
          setobj2s(ra, get_tbl(rb(i), rkc(i)))
        when OP_SETTABUP
          upval = get_upval(Inst.a(i))
          set_tbl(upval, rkb(i), rkc(i))
        when OP_SETUPVAL
          raise
        when OP_SETTABLE
          set_tbl(r(a), rkb(i), rkc(i))
        when OP_NEWTABLE
          setobj2s( ra, {} )
        when OP_ADD, OP_SUB, OP_MUL, OP_MOD, OP_POW, OP_DIV, OP_IDIV,
             OP_BAND, OP_BOR, OP_BXOR, OP_SHL, OP_SHR
          binop = BINOP_METHOD[opcode]
          b = rkb(i)
          b = b.to_f if b.is_a? String
          c = rkc(i)
          c = c.to_f if c.is_a? String
          case opcode
          when OP_BAND, OP_BOR, OP_BXOR, OP_SHL, OP_SHR
            b = b.to_i
            c = c.to_i
          end
          setobj2s(ra, b.__send__(binop, c))
        when OP_UNM
          setobj2s(ra, -rb(i))
        when OP_BNOT
          raise
        when OP_NOT
          raise
        when OP_LEN
          setobj2s(ra, rb(i).size)
        when OP_CONCAT
          str = @stack[(@ci.base+Inst.b(i))..(@ci.base+Inst.c(i))].join
          setobj2s(ra, str)
        when OP_JMP
          @pc += Inst.sbx(i)
        when OP_EQ
          b = rkb(i)
          if b == true or b == false
            b = b ? 1 : 0
          end
          @pc+=1 if (b == rkc(i)) != (Inst.a(i) != 0)
        when OP_LT
          @pc+=1 if (rkb(i) < rkc(i)) != (Inst.a(i) != 0)
        when OP_LE
          @pc+=1 if (rkb(i) <= rkc(i)) != (Inst.a(i) != 0)
        when OP_TEST
          @pc += 1 unless as_bool(r(a)) == (Inst.c(i) != 0)
        when OP_TESTSET
          if rb(i) == Inst.c(i)
            setobj2s(ra, rb(i))
          else
            @pc += 1
          end
        when OP_CALL
          b = Inst.b(i)
          nresult = Inst.c(i) - 1
          if b != 0
            @top = ra + b
            @ci.top = ra
          end
          precall(ra, nresult)
        when OP_RETURN
          # TODO
          b = Inst.b(i)
          if @ci.prev.nil?
            break
          else
            if b == 0
              p [:return, ra, @ci.prev.top, @ci.top, @top]
              b = @ci.top - ra
            end
            @stack[@ci.prev.top, b-1] = @stack[@ci.base+a, b-1]
            @ci.prev.top = @ci.prev.top + b - 1
            @pc = @ci.saved_pc
            @ci = @ci.prev
          end
        when OP_FORLOOP
          v = r(a) + r(a+2)
          setobj2s(ra, v)
          if v < r(a+1)
            @pc += Inst.sbx(i)
            setobj2s(ra+3, v)
          end
        when OP_FORPREP
          setobj2s(ra, r(a) - r(a+2))
          @pc += Inst.sbx(i)
        when OP_TFORCALL
          nresult = Inst.c(i)
          if b != 0
            @top = ra + 1
            @ci.top = ra
          end
          precall(ra, nresult)
        when OP_TFORLOOP
          raise
        when OP_SETLIST
          tbl = r(a)
          c = Inst.c(i)
          b = Inst.b(i)
          if b == 0 # vararg
            b = @ci.top - ra - 1
          end
          (1..b).each do |i|
            set_tbl(tbl, (c-1)+i, r(a+i))
          end
        when OP_CLOSURE
          proto = @func.protos[Inst.bx(i)]
          setobj2s(ra, Closure.new(proto, @ci))
        when OP_VARARG
          b = Inst.b(i)
          if b == 0
            n = @ci.base - @ci.func - 1
            @stack[ra, n] = @stack[@ci.func+1,n]
            @ci.top = ra + n
          else
            @stack[ra, b-1] = @stack[@ci.func+1,b-1]
          end
        else
          raise "unknown opcode #{OPCODE_NAMES[opcode]}"
        end
        count -= 1
      end
    rescue
      dump
      puts "#{@func.filename}:#{@func.debug_infos[@pc-1]}: error"
      STDOUT.flush
      raise
    end

  end
end
