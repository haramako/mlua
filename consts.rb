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

    OP_SETLIST  ABC

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

end
