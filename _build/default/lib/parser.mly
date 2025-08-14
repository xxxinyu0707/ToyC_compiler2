%{
open Ast
%}

/* Keyword Tokens (no changes) */
%token KW_INT KW_VOID
%token KW_IF KW_ELSE KW_WHILE KW_BREAK KW_CONTINUE KW_RETURN

/* Identifier and Literal Tokens (no changes) */
%token <string> IDENT
%token <int> INT_LITERAL

/* Operator and Delimiter Tokens (no changes) */
%token OP_ASSIGN SEMICOLON COMMA
%token L_BRACE R_BRACE L_PAREN R_PAREN
%token OP_OR OP_AND
%token OP_LT OP_GT OP_LE OP_GE OP_EQ OP_NE
%token OP_PLUS OP_MINUS
%token OP_MUL OP_DIV OP_MOD
%token OP_NOT
%token EOF

/* --- MODIFIED SECTION: Precedence and Associativity --- */

%right OP_ASSIGN
%left OP_OR
%left OP_AND
%left OP_EQ OP_NE
%left OP_LT OP_GT OP_LE OP_GE
%left OP_PLUS OP_MINUS
%left OP_MUL OP_DIV OP_MOD
%right OP_NOT UMINUS 

/* --- REMOVED SECTION --- */


%start <Ast.program> compilation_unit
%%

/* The following rules are unchanged */
compilation_unit:
  | funcs = list(func_decl) EOF { { functions = funcs } }

func_decl:
  | ret_type = return_type; name = IDENT;
    L_PAREN; params = separated_list(COMMA, func_param); R_PAREN;
    L_BRACE; body = list(statement); R_BRACE;
    { { func_name = name; func_params = params; has_return_value = ret_type; func_body = body } }

return_type:
  | KW_INT  { true }
  | KW_VOID { false }

func_param:
  | KW_INT; name = IDENT { { param_name = name } }

statement:
  | L_BRACE; stmts = list(statement); R_BRACE { StmtBlock stmts }
  | e = expression; SEMICOLON { ExprStmt e }
  | SEMICOLON { StmtBlock [] }
  | KW_IF; L_PAREN; cond = expression; R_PAREN;
    then_branch = statement;
    else_branch = option(preceded(KW_ELSE, statement))
    { IfStmt (cond, then_branch, else_branch) }
  | KW_WHILE; L_PAREN; cond = expression; R_PAREN; body = statement
    { WhileStmt (cond, body) }
  | KW_BREAK; SEMICOLON { BreakStmt }
  | KW_CONTINUE; SEMICOLON { ContinueStmt }
  | KW_RETURN; e = option(expression); SEMICOLON { ReturnStmt e }
  | KW_INT; name = IDENT; OP_ASSIGN; init = expression; SEMICOLON
    { VarDecl (name, init) }


expression:
  | id = IDENT { Identifier id }
  | n = INT_LITERAL { IntLiteral n }
  | L_PAREN; e = expression; R_PAREN { e }
  | name = IDENT; L_PAREN; args = separated_list(COMMA, expression); R_PAREN { FunctionCall(name, args) }

  /* 一元运算 (inlined from `unary_op`) */
  | OP_NOT; e = expression { UnaryExpr(LogicalNot, e) }
  | OP_MINUS; e = expression %prec UMINUS { UnaryExpr(Negate, e) }
  | OP_PLUS; e = expression %prec UMINUS { UnaryExpr(Positive, e) }

  /* 二元运算 (inlined from `binary_op`) */
  | e1 = expression; OP_PLUS;  e2 = expression { BinaryExpr(AddOp, e1, e2) }
  | e1 = expression; OP_MINUS; e2 = expression { BinaryExpr(SubOp, e1, e2) }
  | e1 = expression; OP_MUL;   e2 = expression { BinaryExpr(MulOp, e1, e2) }
  | e1 = expression; OP_DIV;   e2 = expression { BinaryExpr(DivOp, e1, e2) }
  | e1 = expression; OP_MOD;   e2 = expression { BinaryExpr(ModOp, e1, e2) }
  | e1 = expression; OP_LT;    e2 = expression { BinaryExpr(LtOp, e1, e2)  }
  | e1 = expression; OP_GT;    e2 = expression { BinaryExpr(GtOp, e1, e2)  }
  | e1 = expression; OP_LE;    e2 = expression { BinaryExpr(LeOp, e1, e2)  }
  | e1 = expression; OP_GE;    e2 = expression { BinaryExpr(GeOp, e1, e2)  }
  | e1 = expression; OP_EQ;    e2 = expression { BinaryExpr(EqOp, e1, e2)  }
  | e1 = expression; OP_NE;    e2 = expression { BinaryExpr(NeOp, e1, e2)  }
  | e1 = expression; OP_AND;   e2 = expression { BinaryExpr(AndOp, e1, e2) }
  | e1 = expression; OP_OR;    e2 = expression { BinaryExpr(OrOp, e1, e2)  }

  /* 赋值运算 (unchanged from your original) */
  | id = IDENT; OP_ASSIGN; e = expression { Assignment (id, e) }