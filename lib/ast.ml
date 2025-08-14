(* Binary operators *)
type binary_op =
  (* Arithmetic operators *)
  | AddOp | SubOp | MulOp | DivOp | ModOp
  (* Relational operators *)
  | LtOp | GtOp | LeOp | GeOp | EqOp | NeOp
  (* Logical operators *)
  | AndOp | OrOp

(* Unary operators *)
type unary_op =
  | LogicalNot | Negate | Positive

(* Expressions *)
type expr =
  | Identifier of string
  | IntLiteral of int
  | BinaryExpr of binary_op * expr * expr
  | UnaryExpr of unary_op * expr
  | FunctionCall of string * expr list
  | Assignment of string * expr

(* Statements *)
type stmt =
  | StmtBlock of stmt list
  | ExprStmt of expr
  | IfStmt of expr * stmt * stmt option
  | WhileStmt of expr * stmt
  | BreakStmt
  | ContinueStmt
  | ReturnStmt of expr option
  | VarDecl of string * expr

(* Function parameter *)
type param = {
  param_name: string;
}

(* Function definition *)
type function_def = {
  func_name: string;
  func_params: param list;
  (* true for int, false for void *)
  has_return_value: bool;
  func_body: stmt list;
}

(* Top-level program structure *)
type program = {
  functions: function_def list;
}