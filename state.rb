
module Mlua
  class CallInfo < Struct.new(:func, :top, :base, :prev)
    def inspect
      "#<CallInfo #{@func.__id__} #{@top} #{@base}>"
    end
  end

  class Closure < Struct.new(:func, :up_callinfo)
    def inspect
      "#<Closure #{@func.__id__} #{@up_callinfo}>"
    end
  end

  class State
    def initialize
      @pc = 0
      @stack = []
    end

    def load_string(str, filename = nil)
      @chunk = Chunk.new(str, filename)
      @ci = CallInfo.new(@chunk.main,0,0,nil)
      @chunk.main.dump
      @env = {}
      @env['print'] = RubyFunction.new(proc{|a| puts a },1)
    end

    def run
      step(9999)
    end

    def setobj2s(pos, v)
      @stack[pos] = v
    end

    def get_upval(upval_idx)
      instack, idx = @ci.func.upvals[upval_idx]
      
      if instack == 0
        instack, idx = @ci.prev.func.upvals[idx]
      end
      
      up_ci = @ci
      while instack > 0
        up_ci = up_ci.prev
        instack -= 1
      end
      if up_ci.nil?
        if idx == 0
          @env
        else
          raise
        end
      else
        @stack[up_ci.base+idx]
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
        @ci.func.consts[-1-idx]
      end
    end

    def precall(func_idx, nresults)
      func = r(func_idx)
      case func
      when RubyFunction
        args = @stack[@top-func.arity,func.arity]
        func.proc.call args
      when Function
        raise
      when Closure
        @ci = CallInfo.new(func.func, @top, @top, @ci)
        @pc = 0
      else
        raise
      end
    end

    def kst(idx)
      @ci.func.consts[idx]
    end

    #def ra(inst)
    #  r(Inst.op_a(inst))
    #end

    def rb(inst)
      r(Inst.op_b(inst))
    end
    
    def rc(inst)
      r(Inst.op_c(inst))
    end
    
    def rkb(inst)
      rk(Inst.op_b(inst))
    end

    def rkc(inst)
      rk(Inst.op_c(inst))
    end
    
    def step(c)
      while c > 0
        i = @ci.func.insts[@pc]
        @pc += 1
        opcode = Inst.op_opcode(i)
        ra = @ci.base + Inst.op_a(i)
        puts "%4d %s" % [@pc, Inst.inst_to_str(i)]
        # pp @stack
        case opcode
        when OP_MOVE
          setobj2s(ra, rb(i))
        when OP_LOADK
          setobj2s(ra, kst(Inst.op_bx(i)))
        when OP_GETTABUP
          upval = get_upval(Inst.op_b(i))
          setobj2s(ra, upval[rk(Inst.op_c(i))])
        when OP_SETTABUP
          upval = get_upval(Inst.op_a(i))
          upval[rkb(i)] = rkc(i)
        when OP_CALL
          b = Inst.op_b(i)
          nresult = Inst.op_c(i) - 1
          if b != 0
            @top = ra + b
          end
          precall(ra, nresult)
        when OP_RETURN
          # TODO
          break
        when OP_CLOSURE
          proto = @ci.func.protos[Inst.op_b(i)]
          setobj2s(ra, Closure.new(proto, @ci))
        else
          raise "unknown opcode #{OPCODE_NAMES[opcode]}"
        end
        c -= 1
      end
    rescue
      p @stack
      p @env
      raise
    end

  end
end
