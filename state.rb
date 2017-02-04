# coding: utf-8

module Mlua
  class CallInfo < Struct.new(:func, :result_idx, :base, :prev, :nresults, :saved_pc)
    def inspect
      "#<CallInfo #{@func} #{@result_idx} #{@base}>"
    end
    alias to_s inspect
  end

  class Closure < Struct.new(:func, :up_callinfo)
    def inspect
      "#<Closure #{func and func.line_start} #{up_callinfo}>"
    end
    alias to_s inspect
  end

  class MultiValue
    attr_reader :values
    def initialize(*args)
      @values = args
    end
  end

  class State
    attr_reader :env
    attr_accessor :trace
    
    def initialize
      $lua = self
      
      @pc = 0
      @stack = []
      
      @env = Table.new
      @env['_ENV'] = @env
      @env['_G'] = @env
      @env.merge LuaModule.to_table(LuaModule::Global)
      [
        ['T', LuaModule::T],
        ['math', LuaModule::LuaMath],
        ['string', LuaModule::StdString],
        ['debug', LuaModule::Debug],
        ['os', LuaModule::OS],
        ['table', LuaModule::LuaTable],
      ].each do |k,v|
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
      # system(LUAC, '-l', filename)
      system(LUAC, filename)
      load_chunk(IO.binread('luac.out'), filename)
    end
    
    def load_chunk(str, filename = nil)
      chunk = Chunk.new(str, filename)
      @stack[0] = Closure.new(chunk.main, nil)
      @ci = CallInfo.new(0, 0, 1, nil, 1)
    end

    def dump
      puts "**STACK**"
      @stack.each.with_index do |v,i|
        if i == @ci.base
          mark = 'base->'
        elsif i == @ci.func
          mark = 'func->'
        elsif i == @top
          mark = 'top->'
        elsif i == @ci.result_idx
          mark = 'res->'
        else
          mark = ''
        end
        puts "%8s %4d %s" % [mark, i, v]
        break if i > @top + 20
      end
      if false
      puts "**_ENV**"
      @env.each do |k,v|
        puts "%8s = %s" % [k, v]
      end
      end
    end

    def setobj2s(pos, v)
      @stack[pos] = v
    end

    def get_upval(upval_idx)
      # MEMO: クロージャは未対応
      instack, idx = @func.upvals[upval_idx]
      if instack == 1
        if @ci.prev == nil
          @env
        else
          @stack[@ci.prev.base + idx]
        end
      else
        @env
      end
    end

    def set_upval(upval_idx, val)
      # MEMO: クロージャは未対応
      instack, idx = @func.upvals[upval_idx]
      if instack == 1
        if @ci.prev == nil
          raise
        else
          @stack[@ci.prev.base + idx] = val
        end
      else
        raise
      end
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

    def validate_value!(v)
      case v
      when nil, TrueClass, FalseClass, Numeric, Table, String, Closure, Method, Proc
        # DO NOTHING
      else
        raise "#{v} is not valid lua value"
      end
    end

    def copy_and_fill(from, from_size, to, to_size)
      from_size = to_size if from_size > to_size
      if to != from
        @stack[to, to_size] = @stack[from, to_size]
      end
      while from_size < to_size
        @stack[to + from_size] = nil
        from_size += 1
      end
    end
    
    # nativeコールならtrueを返す
    def precall(is_tailcall, func_idx, nargs, result_idx, nresults)
      func = @stack[func_idx]
      if is_tailcall
        p func
      end
      case func
      when Method, Proc
        args = @stack[func_idx+1,nargs]
        result = func.call(*args)
        if result.is_a? MultiValue
          if result.values.size == 0
            @stack[result_idx] = nil
            @top = result_idx
          else
            result.values.each {|v| validate_value! v }
            @stack[result_idx, result.values.size] = result.values
            @top = result_idx + result.values.size
          end
        else
          validate_value! result
          @stack[result_idx] = result
          @top = result_idx + 1
        end
        if is_tailcall
          @pc = @ci.saved_pc
        end
      when Function
        raise
      when Closure
        fixed_num = func.func.param_num
        if func.func.is_vararg != 0
          # with varargs
          vararg_num = nargs - fixed_num
          fixed_args = @stack[func_idx+1, fixed_num]
          while nargs < fixed_num
            @stack[func_idx+1+nargs] = nil
            nargs += 1
          end
          if vararg_num > 0
            @stack[func_idx+1, vararg_num] = @stack[func_idx+1+fixed_num, vararg_num]
            @stack[func_idx+1+vararg_num, fixed_num] = fixed_args
            base = func_idx + 1 + vararg_num
          else
            base = func_idx + 1
          end
        else
          # no varargs
          base = func_idx + 1
          copy_and_fill(func_idx+1, nargs, func_idx+1, fixed_num)
        end
        @ci = CallInfo.new(func_idx, result_idx, base, @ci, nresults)
        @pc = 0
      when nil
        raise "function is nil"
      else
        raise "invalid func type #{func.class} at #{func_idx}"
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
      raise "invalid tbl #{tbl.class}" unless tbl.is_a? Table
      tbl[idx]
    end

    def set_tbl(tbl, idx, val)
      raise "invalid tbl #{tbl.class}" unless tbl.is_a? Table
      tbl[idx] = val
    end

    def as_bool(v)
      !!v
    end
    
    def run
      step(-1)
    end

    # topを使うもの
    #
    # top -> CALL/TAILCALL-> top
    #     -> RETURN       -> top
    #     -> SETLIST
    #
    #        VARARG       -> top
    #
    # CALL/TAILCALL -> ci.vararg -> VARARG -> top
    #  (if C==0)
    #
    def step(count)
      @log = []
      while count != 0
        @func = @stack[@ci.func].func
        i = @func.insts[@pc]
        opcode = Inst.opcode(i)
        if i == nil
          raise "nil instruction in #{@pc}"
        end
        a = Inst.a(i)
        ra = @ci.base + a
        if @log.size > 100
          @log = @log[-50..-1]
        end
        @log << ("%4d [%3d] %s" % [@pc, @func.debug_infos[@pc], Inst.inst_to_str(i)])
        if @trace
          puts ("%4d [%3d] %s" % [@pc, @func.debug_infos[@pc], Inst.inst_to_str(i)])
        end
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
        when OP_GETUPVAL
          setobj2s(ra, get_upval(Inst.b(i)))
        when OP_GETTABUP
          upval = get_upval(Inst.b(i))
          setobj2s(ra, get_tbl(upval, rkc(i)))
        when OP_GETTABLE
          setobj2s(ra, get_tbl(rb(i), rkc(i)))
        when OP_SETTABUP
          upval = get_upval(Inst.a(i))
          set_tbl(upval, rkb(i), rkc(i))
        when OP_SETUPVAL
          set_upval(Inst.b(i), r(a))
        when OP_SETTABLE
          set_tbl(r(a), rkb(i), rkc(i))
        when OP_NEWTABLE
          setobj2s( ra, Table.new )
        when OP_SELF
          tbl = rb(i)
          setobj2s(ra+1, tbl)
          setobj2s(ra, get_tbl(tbl, rkc(i)))
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
          setobj2s(ra, !rb(i))
        when OP_LEN
          setobj2s(ra, rb(i).size)
        when OP_CONCAT
          str = @stack[(@ci.base+Inst.b(i))..(@ci.base+Inst.c(i))].join
          setobj2s(ra, str)
        when OP_JMP
          @pc += Inst.sbx(i)
        when OP_EQ
          b = rkb(i)
          c = rkc(i)
          if b == true or b == false
            b = b ? 1 : 0
          end
          if c == true or c == false
            c = c ? 1 : 0
          end
          @pc+=1 if (b == c) != (Inst.a(i) != 0)
        when OP_LT
          @pc+=1 if (rkb(i) < rkc(i)) != (Inst.a(i) != 0)
        when OP_LE
          @pc+=1 if (rkb(i) <= rkc(i)) != (Inst.a(i) != 0)
        when OP_TEST
          @pc += 1 unless as_bool(r(a)) == (Inst.c(i) != 0)
        when OP_TESTSET
          if as_bool(rb(i)) == (Inst.c(i) != 0)
            setobj2s(ra, rb(i))
          else
            @pc += 1
          end
        when OP_CALL
          b = Inst.b(i)
          nresults = Inst.c(i) - 1
          if b == 0
            nargs = @top - ra - 1
          else
            nargs = b - 1
          end
          @ci.saved_pc = @pc
          precall(false, ra, nargs, ra, nresults)
        when OP_TAILCALL
          b = Inst.b(i)
          if b == 0
            nargs = @top - ra - 1
          else
            nargs = b - 1
          end
          old_ci = @ci
          @ci = @ci.prev
          @stack[old_ci.func, nargs+1] = @stack[ra, nargs+1]
          precall(true, old_ci.func, nargs, old_ci.result_idx, old_ci.nresults)
        when OP_RETURN
          b = Inst.b(i)
          if @ci.prev.nil?
            break
          else
            nresults = b - 1
            if nresults == -1
              nresults = @top - ra
            end

            @stack[@ci.result_idx, nresults] = @stack[@ci.base+a, nresults]
            if nresults < @ci.nresults
              (nresults...@ci.nresults).each {|i| @stack[@ci.result_idx+i] = nil } # 残りの帰り値をnilで埋める
            end

            @top = @ci.result_idx + nresults
            @ci = @ci.prev
            @pc = @ci.saved_pc
          end
        when OP_FORLOOP
          stp = r(a+2)
          v = r(a) + stp
          setobj2s(ra, v)
          if (stp > 0 and v <= r(a+1)) or (stp < 0 and v >= r(a+1))
            @pc += Inst.sbx(i)
            setobj2s(ra+3, v)
          end
        when OP_FORPREP
          setobj2s(ra, r(a) - r(a+2))
          @pc += Inst.sbx(i)
        when OP_TFORCALL
          nresult = Inst.c(i)
          precall(false, ra, 2, ra + 3, nresult)
        when OP_TFORLOOP
          if r(ra+1) != nil
            setobj2s(ra, r(ra+1))
            @pc += Inst.sbx(i)
          end
        when OP_SETLIST
          tbl = r(a)
          c = Inst.c(i)
          b = Inst.b(i)
          if b == 0 # vararg
            b = @top - ra - 1
          end
          (1..b).each do |i|
            set_tbl(tbl, (c-1)+i, r(a+i))
          end
        when OP_CLOSURE
          proto = @func.protos[Inst.bx(i)]
          setobj2s(ra, Closure.new(proto, @ci))
        when OP_VARARG
          b = Inst.b(i)
          n = @ci.base - @ci.func - 1
          if b == 0
            f = @stack[@ci.func]
            n = @ci.base - @ci.func - 1
            # n = 0 if n < 0
            @stack[ra, n] = @stack[@ci.func+1,n]
            @top = ra + n
          else
            @stack[ra, b-1] = @stack[@ci.func+1,b-1]
            if n < b-1
              (n...b-1).each{|i| @stack[ra+i] = nil }
            end
            @top = ra + b - 1
          end
        else
          raise "unknown opcode #{OPCODE_NAMES[opcode]}"
        end
        count -= 1
      end
    rescue
      dump
      puts @log.last(20)
      puts "#{@func.filename}:#{@func.debug_infos[@pc-1]}: error"
      cur_ci = @ci.prev
      while cur_ci
        f = @stack[cur_ci.func]
        if f
          puts "#{f.func.filename}:#{f.func.debug_infos[cur_ci.saved_pc-1]}: error"
        else
          puts "broken stack at #{cur_ci.func}"
        end
        cur_ci = cur_ci.prev
      end
      STDOUT.flush
      raise
    end

  end
end
