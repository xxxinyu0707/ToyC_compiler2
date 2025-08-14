
(* The type of tokens. *)

type token = 
  | SEMICOLON
  | R_PAREN
  | R_BRACE
  | OP_PLUS
  | OP_OR
  | OP_NOT
  | OP_NE
  | OP_MUL
  | OP_MOD
  | OP_MINUS
  | OP_LT
  | OP_LE
  | OP_GT
  | OP_GE
  | OP_EQ
  | OP_DIV
  | OP_ASSIGN
  | OP_AND
  | L_PAREN
  | L_BRACE
  | KW_WHILE
  | KW_VOID
  | KW_RETURN
  | KW_INT
  | KW_IF
  | KW_ELSE
  | KW_CONTINUE
  | KW_BREAK
  | INT_LITERAL of (int)
  | IDENT of (string)
  | EOF
  | COMMA

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val compilation_unit: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Ast.program)
