open Ast

(* Type definitions used in the semantic analyzer *)
type type_def = IntType | VoidType

type variable_info = {
  var_name: string;
  var_type: type_def;
}

type function_info = {
  func_name: string;
  return_type: type_def;
  param_types: variable_info list;
}

(* Symbol table representing a scope *)
type scope = {
  variables: variable_info list;
  functions: function_info list;
  parent_scope: scope option;
  is_in_loop: bool;
}

(* Custom exceptions for semantic errors *)
exception TypeError of string
exception UndeclaredError of string
exception ControlFlowError of string

(* --- Scope and Symbol Management --- *)

let create_scope parent_scope in_loop = {
  variables = [];
  functions = [];
  parent_scope = parent_scope;
  is_in_loop = in_loop;
}

let rec lookup_variable name (current_scope: scope) =
  match List.find_opt (fun v -> v.var_name = name) current_scope.variables with
  | Some var -> var
  | None ->
      match current_scope.parent_scope with
      | Some parent -> lookup_variable name parent
      | None -> raise (UndeclaredError ("Variable '" ^ name ^ "' not defined."))

let rec lookup_function name (current_scope: scope) =
  match List.find_opt (fun f -> f.func_name = name) current_scope.functions with
  | Some func -> func
  | None ->
      match current_scope.parent_scope with
      | Some parent -> lookup_function name parent
      | None -> raise (UndeclaredError ("Function '" ^ name ^ "' not defined."))

let add_variable info (s: scope) =
  { s with variables = info :: s.variables }

let add_function info (s: scope) =
  { s with functions = info :: s.functions }

(* --- Type Checking Expressions and Statements --- *)

let rec typecheck_expr scope = function
  | Ast.IntLiteral _ -> IntType
  | Ast.Identifier name -> (lookup_variable name scope).var_type
  | Ast.Assignment (name, expr) ->
      let var = lookup_variable name scope in
      let expr_type = typecheck_expr scope expr in
      if var.var_type <> expr_type then
        raise (TypeError "Type mismatch in assignment.");
      var.var_type
  | Ast.UnaryExpr (op, expr) ->
      let t = typecheck_expr scope expr in
      (match op, t with
      | (LogicalNot | Negate | Positive), IntType -> IntType
      | _ -> raise (TypeError "Unary operator requires an integer operand."))
  | Ast.BinaryExpr (_, e1, e2) ->
      let t1 = typecheck_expr scope e1 in
      let t2 = typecheck_expr scope e2 in
      (match t1, t2 with
      | IntType, IntType -> IntType
      | _ -> raise (TypeError "Binary operator requires integer operands."))
  | Ast.FunctionCall (name, args) ->
      let func = lookup_function name scope in
      if List.length args <> List.length func.param_types then
        raise (TypeError (Printf.sprintf "Function '%s' expects %d arguments, but got %d."
          name (List.length func.param_types) (List.length args)));
      List.iter2 (fun param arg_expr ->
        let arg_type = typecheck_expr scope arg_expr in
        if arg_type <> param.var_type then
          raise (TypeError (Printf.sprintf "Type mismatch for argument in call to '%s'." name))
      ) func.param_types args;
      func.return_type

let rec typecheck_stmt_list scope stmts =
  List.fold_left typecheck_stmt scope stmts

and typecheck_stmt scope = function
  | Ast.StmtBlock stmts ->
      let block_scope = create_scope (Some scope) scope.is_in_loop in
      ignore (typecheck_stmt_list block_scope stmts);
      scope
  | Ast.ExprStmt expr ->
      ignore (typecheck_expr scope expr);
      scope
  | Ast.VarDecl (name, init_expr) ->
      let init_type = typecheck_expr scope init_expr in
      let var_info = { var_name = name; var_type = init_type } in
      add_variable var_info scope
  | Ast.IfStmt (cond, then_stmt, else_opt) ->
      if typecheck_expr scope cond <> IntType then
        raise (TypeError "If condition must be an integer.");
      ignore (typecheck_stmt scope then_stmt);
      Option.iter (fun else_s -> ignore (typecheck_stmt scope else_s)) else_opt;
      scope
  | Ast.WhileStmt (cond, body) ->
      if typecheck_expr scope cond <> IntType then
        raise (TypeError "While condition must be an integer.");
      let loop_scope = create_scope (Some scope) true in
      ignore (typecheck_stmt loop_scope body);
      scope
  | Ast.ReturnStmt _ -> scope
  | Ast.BreakStmt ->
      if not scope.is_in_loop then raise (ControlFlowError "'break' is not inside a loop.");
      scope
  | Ast.ContinueStmt ->
      if not scope.is_in_loop then raise (ControlFlowError "'continue' is not inside a loop.");
      scope

(* --- Main Analysis Function --- *)

let analyze (program: Ast.program) =
  let global_scope = create_scope None false in
  
  (* 1. First pass: Collect all function signatures *)
  let scope_with_funcs =
    List.fold_left (fun current_scope (func_def: Ast.function_def) ->
      let params = List.map (fun p -> { var_name = p.param_name; var_type = IntType }) func_def.func_params in
      let ret_type = if func_def.has_return_value then IntType else VoidType in
      let func_info = { func_name = func_def.func_name; return_type = ret_type; param_types = params } in
      add_function func_info current_scope
    ) global_scope program.functions in
  
  (* 2. Second pass: Check each function body *)
  List.iter (fun (func_def: Ast.function_def) ->
    let func_scope = create_scope (Some scope_with_funcs) false in
    let param_vars = List.map (fun p -> { var_name = p.param_name; var_type = IntType }) func_def.func_params in
    let scope_with_params = List.fold_left (fun acc p -> add_variable p acc) func_scope param_vars in
    ignore (typecheck_stmt_list scope_with_params func_def.func_body)
  ) program.functions