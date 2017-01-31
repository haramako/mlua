class Mlua::Parser
  prechigh
    nonassoc UMINUS
    left '*' '/' '%'
    left '+' '-' '..'
    left '<<' '>>'
    left '<' '>' '<=' '>='
    left '==' '!='
    left '&'
    left '^'
    left '|'
    left '&&' 'and'
    left '||' 'or'
    right '=' '+=' '-=' '~='
  preclow
  expect 1
rule

chunk: _chunk_sub laststat_opt
     | laststat_opt

_semi_opt: ';'
         |

_chunk_sub: stat { @need_semi = true } _semi_opt  { @need_semi = false }
          | _chunk_sub stat { @need_semi = true } _semi_opt { @need_semi = false }

block: chunk

/* for yuusendo */
prefixexp: var
         | functioncall
	     | '(' exp ')'

stat: varlist '=' explist
	| functioncall
	| lua52_label
	| 'do' block 'end'
	| 'while' exp 'do' block 'end'
	| 'repeat' block 'until' exp
	| 'if' exp 'then' block _elsif_list _else_opt 'end'
	| 'for' NAME '=' exp ',' exp _comma_exp_opt 'do' block 'end'
	| 'for' namelist 'in' explist 'do' block 'end'
	| 'function' funcname funcbody
	| 'local' 'function' NAME funcbody
	| 'local' namelist _eq_explist_opt

_comma_exp_opt: ',' exp
             |

_elsif_list: _elsif_list 'elseif' exp 'then' block
          |

_else_opt: 'else' block
        |
	
_eq_explist_opt: '=' explist
               |

laststat_opt: laststat _semi_opt
            |

laststat: 'return' _explist_opt
        | 'break'
        | lua52_goto

lua52_goto: 'goto' NAME

lua52_label: '::' NAME '::'

funcname: NAME _dot_name_list _colon_name_opt

_dot_name_list: _dot_name_list '.' NAME
              |
			  
_colon_name_opt: ':' NAME
               |

varlist: varlist ',' var
       | var

var: NAME
   | prefixexp '[' exp ']'
   | prefixexp '.' NAME 

namelist: namelist ',' NAME
        | NAME 

_explist_opt: explist
            |
		   
explist: explist ',' exp
       | exp


exp: 'nil'
   | 'false'
   | 'true'
   | numeric
   | STRING
   | '...'
   | function
   | prefixexp
   | tableconstructor
   | binexp
   | unop exp = UMINUS

numeric: FFI_INT64
       | FFI_UINT64
       | FFI_IMAGINARY
       | NUMBER

functioncall: prefixexp args
            | prefixexp ':' NAME args 

args: '(' _explist_opt ')'
    | tableconstructor
    | STRING

function: 'function' funcbody

funcbody: '(' parlist ')' block 'end'

parlist: _parlist_sub NAME ',' '...'
       | _parlist_sub NAME
       | NAME ',' '...'
       | NAME
       | '...'
       |

_parlist_sub: _parlist_sub NAME ','
            | NAME ','

tableconstructor: '{' fieldlist '}'

fieldlist: _fieldlist_sub field fieldsep
         | _fieldlist_sub field
         | field fieldsep
	     | field
         | 

_fieldlist_sub: _fieldlist_sub field fieldsep
              | field fieldsep

field: '[' exp ']' '=' exp
     | NAME '=' exp
     | exp

fieldsep: ',' | ';'

binexp: exp '+' exp
	  | exp '-' exp
	  | exp '*' exp
	  | exp '/' exp
	  | exp '^' exp
	  | exp '%' exp
	  | exp '..' exp
	  | exp '<' exp
	  | exp '<=' exp
	  | exp '>' exp
	  | exp '>=' exp
	  | exp '==' exp
	  | exp '~=' exp
	  | exp 'and' exp
	  | exp 'or' exp

unop: '-' | 'not' | '#'

end
