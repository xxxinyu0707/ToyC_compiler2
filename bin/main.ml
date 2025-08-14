open Toyc_lib 

let read_all_from_channel ic =
  let buffer = Buffer.create 1024 in
  try
    while true do
      Buffer.add_string buffer (input_line ic);
      Buffer.add_char buffer '\n'
    done;
    "" (* This line is never reached *)
  with End_of_file ->
    Buffer.contents buffer

let () =
  try
    (* 1. Read source code from standard input *)
    let source_code = read_all_from_channel stdin in
    let lexbuf = Lexing.from_string source_code in

    (* 2. Parsing (Lexical and Syntax Analysis) *)
    (* Now Lexer and Parser are accessed through Toyc_lib *)
    let ast = Parser.compilation_unit Lexer.tokenize lexbuf in
    
    (* 3. Semantic Analysis *)
    Semantic.analyze ast;
    
    (* 4. Code Generation *)
    let assembly_code = Codegen.compile ast in

    (* 5. Output generated assembly to standard output *)
    print_endline assembly_code

  with
  (* Exceptions are also part of the library now *)
  | Lexer.Lexical_error msg ->
      Printf.eprintf "Lexical Error: %s\n" msg;
      exit 1
  | Parser.Error ->
      Printf.eprintf "Syntax Error: Parsing failed.\n";
      exit 1
  | Semantic.TypeError msg ->
      Printf.eprintf "Type Error: %s\n" msg;
      exit 1
  | Semantic.UndeclaredError msg ->
      Printf.eprintf "Semantic Error: %s\n" msg;
      exit 1
  | Semantic.ControlFlowError msg ->
      Printf.eprintf "Control Flow Error: %s\n" msg;
      exit 1
  | Failure msg ->
      Printf.eprintf "Compiler Failure: %s\n" msg;
      exit 1
  | ex ->
      Printf.eprintf "An unexpected error occurred: %s\n" (Printexc.to_string ex);
      exit 1