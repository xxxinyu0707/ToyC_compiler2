open Ast

(* --- RISC-V Definitions --- *)

type register =
  | Zero | RA | SP
  | T0 | T1 | T2 | T3 | T4 | T5 | T6 (* Temporary registers *)
  | A0 | A1 (* Argument/Return registers *)

type instruction =
  (* Pseudo-instructions *)
  | Li of register * int
  | J of string
  | Jr of register
  | Jal of string
  (* Real instructions *)
  | Add of register * register * register
  | Sub of register * register * register
  | Mul of register * register * register
  | Div of register * register * register
  | Rem of register * register * register
  | Sw of register * register * int (* store word *)
  | Lw of register * register * int (* load word *)
  | Beq of register * register * string
  | Bne of register * register * string
  | Blt of register * register * string
  | Bge of register * register * string
  | Ble of register * register * string
  | Bgt of register * register * string
  | Slt of register * register * register
  | Seqz of register * register
  | Snez of register * register
  | And of register * register * register
  | Or of register * register * register
  (* Assembler directives *)
  | Label of string
  | Comment of string

(* --- Code Generation Context --- *)

type var_location = { offset: int }

type codegen_env = {
  instructions: instruction list;
  var_map: (string * var_location) list;
  stack_offset: int; (* Next available offset from SP, always negative *)
  label_count: int;
  break_target: string option;
  continue_target: string option;
  return_target: string option;
}

(* --- Helper Functions --- *)

let reg_to_string = function
  | Zero -> "zero" | RA -> "ra" | SP -> "sp"
  | T0 -> "t0" | T1 -> "t1" | T2 -> "t2" | T3 -> "t3"
  | T4 -> "t4" | T5 -> "t5" | T6 -> "t6"
  | A0 -> "a0" | A1 -> "a1"

let instr_to_string = function
  | Li (rd, imm) -> Printf.sprintf "\tli %s, %d" (reg_to_string rd) imm
  | Add (rd, r1, r2) -> Printf.sprintf "\tadd %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Sub (rd, r1, r2) -> Printf.sprintf "\tsub %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Mul (rd, r1, r2) -> Printf.sprintf "\tmul %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Div (rd, r1, r2) -> Printf.sprintf "\tdiv %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Rem (rd, r1, r2) -> Printf.sprintf "\trem %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Sw (rs, base, off) -> Printf.sprintf "\tsw %s, %d(%s)" (reg_to_string rs) off (reg_to_string base)
  | Lw (rd, base, off) -> Printf.sprintf "\tlw %s, %d(%s)" (reg_to_string rd) off (reg_to_string base)
  | J label -> "\tj " ^ label
  | Jr reg -> "\tjr " ^ (reg_to_string reg)
  | Jal label -> "\tjal " ^ label
  | Beq (r1, r2, l) -> Printf.sprintf "\tbeq %s, %s, %s" (reg_to_string r1) (reg_to_string r2) l
  | Bne (r1, r2, l) -> Printf.sprintf "\tbne %s, %s, %s" (reg_to_string r1) (reg_to_string r2) l
  | Blt (r1, r2, l) -> Printf.sprintf "\tblt %s, %s, %s" (reg_to_string r1) (reg_to_string r2) l
  | Bge (r1, r2, l) -> Printf.sprintf "\tbge %s, %s, %s" (reg_to_string r1) (reg_to_string r2) l
  | Ble (r1, r2, l) -> Printf.sprintf "\tble %s, %s, %s" (reg_to_string r1) (reg_to_string r2) l
  | Bgt (r1, r2, l) -> Printf.sprintf "\tbgt %s, %s, %s" (reg_to_string r1) (reg_to_string r2) l
  | Slt (rd, r1, r2) -> Printf.sprintf "\tslt %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Seqz (rd, rs) -> Printf.sprintf "\tseqz %s, %s" (reg_to_string rd) (reg_to_string rs)
  | Snez (rd, rs) -> Printf.sprintf "\tsnez %s, %s" (reg_to_string rd) (reg_to_string rs)
  | And (rd, r1, r2) -> Printf.sprintf "\tand %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Or (rd, r1, r2) -> Printf.sprintf "\tor %s, %s, %s" (reg_to_string rd) (reg_to_string r1) (reg_to_string r2)
  | Label s -> s ^ ":"
  | Comment s -> "\t# " ^ s

(* --- Environment Management --- *)

let create_env () = {
  instructions = []; var_map = []; stack_offset = -8; label_count = 0;
  break_target = None; continue_target = None; return_target = None;
}

let add_instr instr env = { env with instructions = env.instructions @ [instr] }

let new_label env prefix =
  let count = env.label_count in
  let label = Printf.sprintf ".L_%s_%d" prefix count in
  ({ env with label_count = count + 1 }, label)

let add_variable name env =
  let new_offset = env.stack_offset in
  let new_env = {
    env with
    var_map = (name, {offset = new_offset}) :: env.var_map;
    stack_offset = env.stack_offset - 4;
  } in
  (new_env, new_offset)

let find_var_location name env =
  try List.assoc name env.var_map
  with Not_found -> failwith ("Codegen Error: Variable '" ^ name ^ "' not found in this scope.")

let is_valid_immediate_offset offset = offset >= -2048 && offset <= 2047

(* Emits a load instruction, handling large offsets *)
let emit_safe_load dest_reg base_reg offset env =
  if is_valid_immediate_offset offset then
    add_instr (Lw (dest_reg, base_reg, offset)) env
  else
    env
    |> add_instr (Li (T3, offset))
    |> add_instr (Add (T3, base_reg, T3))
    |> add_instr (Lw (dest_reg, T3, 0))

(* Emits a store instruction, handling large offsets *)
let emit_safe_store src_reg base_reg offset env =
  if is_valid_immediate_offset offset then
    add_instr (Sw (src_reg, base_reg, offset)) env
  else
    env
    |> add_instr (Li (T3, offset))
    |> add_instr (Add (T3, base_reg, T3))
    |> add_instr (Sw (src_reg, T3, 0))

(* --- Core Compilation Logic --- *)

let rec compile_expr env expr =
  match expr with
  | IntLiteral n ->
      (add_instr (Li (T0, n)) env, T0)

  | Identifier name ->
      let loc = find_var_location name env in
      (emit_safe_load T0 SP loc.offset env, T0)

  | Assignment (name, e) ->
      let env, reg = compile_expr env e in
      let loc = find_var_location name env in
      let env = emit_safe_store reg SP loc.offset env in
      (env, reg)

  | UnaryExpr (op, e) ->
      let env, reg = compile_expr env e in
      let env' = match op with
        | LogicalNot -> add_instr (Seqz (T0, reg)) env
        | Negate     -> add_instr (Sub (T0, Zero, reg)) env
        | Positive   -> add_instr (Add (T0, reg, Zero)) env
      in (env', T0)

  | BinaryExpr (op, e1, e2) ->
      (match op with
      | AndOp ->
          let env, false_label = new_label env "and_false" in
          let env, end_label = new_label env "and_end" in
          let env, r1 = compile_expr env e1 in
          let env = add_instr (Beq (r1, Zero, false_label)) env in
          let env, r2 = compile_expr env e2 in
          let env = add_instr (Snez (T0, r2)) env in
          let env = add_instr (J end_label) env in
          let env = add_instr (Label false_label) env in
          let env = add_instr (Li (T0, 0)) env in
          (add_instr (Label end_label) env, T0)
      | OrOp ->
          let env, true_label = new_label env "or_true" in
          let env, end_label = new_label env "or_end" in
          let env, r1 = compile_expr env e1 in
          let env = add_instr (Bne (r1, Zero, true_label)) env in
          let env, r2 = compile_expr env e2 in
          let env = add_instr (Snez (T0, r2)) env in
          let env = add_instr (J end_label) env in
          let env = add_instr (Label true_label) env in
          let env = add_instr (Li (T0, 1)) env in
          (add_instr (Label end_label) env, T0)
      | _ ->
          let env, r1 = compile_expr env e1 in
          let temp_offset = env.stack_offset in
          let env = { env with stack_offset = env.stack_offset - 4 } in
          let env = emit_safe_store r1 SP temp_offset env in
          let env, r2 = compile_expr env e2 in
          let env = emit_safe_load T1 SP temp_offset env in
          let op_instr = match op with
            | AddOp -> Add (T0, T1, r2) | SubOp -> Sub (T0, T1, r2)
            | MulOp -> Mul (T0, T1, r2) | DivOp -> Div (T0, T1, r2)
            | ModOp -> Rem (T0, T1, r2) | LtOp  -> Slt (T0, T1, r2)
            | GtOp  -> Slt (T0, r2, T1)
            | EqOp  -> Sub (T0, T1, r2) | NeOp  -> Sub (T0, T1, r2)
            | LeOp  -> Slt (T0, r2, T1) | GeOp  -> Slt (T0, T1, r2)
            | _ -> failwith "Internal error: And/Or handled separately"
          in
          let env = add_instr op_instr env in
          let final_env = match op with
            | EqOp -> add_instr (Seqz (T0, T0)) env
            | NeOp -> add_instr (Snez (T0, T0)) env
            | LeOp -> add_instr (Seqz (T0, T0)) env
            | GeOp -> add_instr (Seqz (T0, T0)) env
            | _ -> env
          in (final_env, T0)
      )

  | FunctionCall (name, args) ->
      (* This follows the calling convention from the provided PDF *)
      let arg_regs = [A0; T1; T2; T3; T4; T5; T6; A1] in
      if List.length args > List.length arg_regs then
        failwith (Printf.sprintf "Too many arguments for function '%s': max %d supported" name (List.length arg_regs));
      
      let env, _ = List.fold_left (fun (env_acc, regs) arg_expr ->
        let env', arg_reg = compile_expr env_acc arg_expr in
        match regs with
        | [] -> (env', []) (* Should not happen due to check above *)
        | dest_reg :: rest_regs ->
            (add_instr (Add (dest_reg, arg_reg, Zero)) env', rest_regs)
      ) (env, arg_regs) args in

      let env = add_instr (Jal name) env in
      (env, A0)

and compile_stmt env stmt =
  match stmt with
  | ExprStmt e ->
      let env, _ = compile_expr env e in
      env

  | VarDecl (name, init_expr) ->
      let env, reg = compile_expr env init_expr in
      let env, new_offset = add_variable name env in
      emit_safe_store reg SP new_offset env

  | IfStmt (cond, then_s, else_opt) ->
      let env, cond_reg = compile_expr env cond in
      let env, else_label = new_label env "if_else" in
      let env, end_if_label = new_label env "if_end" in
      let env = add_instr (Beq (cond_reg, Zero, else_label)) env in
      let env = compile_stmt env then_s in
      let env = add_instr (J end_if_label) env in
      let env = add_instr (Label else_label) env in
      let env = match else_opt with
                | Some s -> compile_stmt env s
                | None -> env
      in
      add_instr (Label end_if_label) env

  | WhileStmt (cond, body) ->
      let env, start_label = new_label env "while_start" in
      let env, end_label = new_label env "while_end" in
      let env = add_instr (Label start_label) env in
      let env, cond_reg = compile_expr env cond in
      let env = add_instr (Beq (cond_reg, Zero, end_label)) env in
      let env_for_body = { env with break_target = Some end_label; continue_target = Some start_label } in
      let env = compile_stmt env_for_body body in
      let env = add_instr (J start_label) env in
      add_instr (Label end_label) env

  | ReturnStmt e_opt ->
      let env = match e_opt, env.return_target with
        | Some e, Some target ->
            let env, reg = compile_expr env e in
            let env = add_instr (Add (A0, reg, Zero)) env in
            add_instr (J target) env
        | None, Some target -> add_instr (J target) env
        | _, None -> failwith "Codegen Error: Return statement found outside a function."
      in env

  | BreakStmt ->
      (match env.break_target with
      | Some target -> add_instr (J target) env
      | None -> failwith "Codegen Error: 'break' is not inside a loop.")

  | ContinueStmt ->
      (match env.continue_target with
      | Some target -> add_instr (J target) env
      | None -> failwith "Codegen Error: 'continue' is not inside a loop.")

  | StmtBlock stmts ->
      (* Save current scope context *)
      let saved_var_map = env.var_map in
      let saved_stack_offset = env.stack_offset in
      (* Process block *)
      let final_env = List.fold_left compile_stmt env stmts in
      (* Restore outer scope context, but keep generated instructions *)
      { final_env with var_map = saved_var_map; stack_offset = saved_stack_offset }

(* Heuristic to estimate stack size. This avoids complex recursive analysis. *)
let compute_stack_frame_size (fdef: Ast.function_def) =
  let param_count = List.length fdef.func_params in
  let estimated_local_vars = 10 (* A safe upper bound for simple functions *) in
  let temp_storage_space = 20 (* Space for intermediate expression results *) in
  let ra_storage = 4 in
  ra_storage + (param_count * 4) + (estimated_local_vars * 4) + temp_storage_space

let compile_function_def env (fdef: Ast.function_def) =
  let stack_size = compute_stack_frame_size fdef in
  let env, return_label = new_label env ("return_" ^ fdef.func_name) in
  let func_env = { (create_env()) with
    instructions = env.instructions;
    label_count = env.label_count;
    return_target = Some return_label;
  } in

  (* Function Prologue *)
  let func_env =
    func_env
    |> add_instr (Label fdef.func_name)
    |> add_instr (Comment "Function Prologue")
    |> add_instr (Sw (RA, SP, -4))
    |> add_instr (Li (T0, -stack_size))
    |> add_instr (Add (SP, SP, T0))
  in

  (* Handle parameters: add to var_map and store from registers *)
  let arg_regs = [A0; T1; T2; T3; T4; T5; T6; A1] in
  let func_env, _ = List.fold_left (fun (env_acc, regs_acc) param ->
    let env', new_offset = add_variable param.param_name env_acc in
    match regs_acc with
    | [] ->
        (env', [])
    | r :: rs ->
        let final_env = emit_safe_store r SP new_offset env' in
        (final_env, rs)
  ) (func_env, arg_regs) fdef.func_params in

  (* Compile function body *)
  let body_env = List.fold_left compile_stmt func_env fdef.func_body in

  (* Function Epilogue *)
  let final_env =
    body_env
    |> add_instr (Label return_label)
    |> add_instr (Comment "Function Epilogue")
    |> add_instr (Lw (RA, SP, stack_size - 4))
    |> add_instr (Li (T0, stack_size))
    |> add_instr (Add (SP, SP, T0))
    |> add_instr (Jr RA)
  in
  { env with instructions = final_env.instructions; label_count = final_env.label_count }

(* Main entry point for code generation *)
let compile (program: Ast.program) =
  let env = create_env () in
  let final_env = List.fold_left compile_function_def env program.functions in

  let has_main = List.exists (fun f -> f.func_name = "main") program.functions in
  let header = if has_main then ".globl main\n" else "" in
  let code_lines = List.map instr_to_string final_env.instructions in
  let assembly_code = String.concat "\n" code_lines in
  header ^ assembly_code