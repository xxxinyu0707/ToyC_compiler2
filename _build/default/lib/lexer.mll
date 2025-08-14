{
open Parser (* ocamlyacc-generated module *)

exception Lexical_error of string
}

let digit = ['0'-'9']
let ident_start = ['a'-'z' 'A'-'Z' '_']
let ident_char = ident_start | digit

rule tokenize = parse
  (* Skip UTF-8 BOM if present *)
  | "\239\187\191" { tokenize lexbuf }

  (* Whitespace *)
  | [' ' '\t' '\r' '\n']+ { tokenize lexbuf }

  (* Comments *)
  | "//" [^ '\n']* { tokenize lexbuf }
  | "/*" { handle_comment lexbuf; tokenize lexbuf }

  (* Keywords *)
  | "int"      { KW_INT }
  | "void"     { KW_VOID }
  | "if"       { KW_IF }
  | "else"     { KW_ELSE }
  | "while"    { KW_WHILE }
  | "break"    { KW_BREAK }
  | "continue" { KW_CONTINUE }
  | "return"   { KW_RETURN }

  (* Identifier *)
  | ident_start ident_char* as id { IDENT id }

  (* Integer Literal *)
  | '-'? ('0' | ['1'-'9'] digit*) as num_str {
      try INT_LITERAL (int_of_string num_str)
      with Failure _ -> raise (Lexical_error ("Invalid integer literal: " ^ num_str))
    }

  (* Operators and Delimiters *)
  | "||" { OP_OR }
  | "&&" { OP_AND }
  | "==" { OP_EQ }
  | "!=" { OP_NE }
  | "<=" { OP_LE }
  | ">=" { OP_GE }
  | '<'  { OP_LT }
  | '>'  { OP_GT }
  | '+'  { OP_PLUS }
  | '-'  { OP_MINUS }
  | '*'  { OP_MUL }
  | '/'  { OP_DIV }
  | '%'  { OP_MOD }
  | '!'  { OP_NOT }
  | '='  { OP_ASSIGN }
  | ';'  { SEMICOLON }
  | ','  { COMMA }
  | '{'  { L_BRACE }
  | '}'  { R_BRACE }
  | '('  { L_PAREN }
  | ')'  { R_PAREN }

  (* End of File *)
  | eof { EOF }

  (* Error for unexpected characters *)
  | _ as char { raise (Lexical_error ("Unexpected character: " ^ (String.make 1 char))) }

and handle_comment = parse
  | "*/" { () }
  | "/*" { handle_comment lexbuf; handle_comment lexbuf }
  | eof  { raise (Lexical_error "Unterminated block comment") }
  | _    { handle_comment lexbuf }