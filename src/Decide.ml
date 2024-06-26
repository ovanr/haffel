(* compile: ocamlopt -I $(opam var lib)/multicont multicont.cmxa Decide.ml 
   Notice that running this in the interpreter gives a different result
   because the stack-to-heap conversion does not happen.
 *)
open Effect
open Effect.Deep

type 'a Effect.t += Decide : unit -> bool Effect.t

let decide () : bool = Effect.perform (Decide ())

let mymain () = let x = ref true in x := decide () && !x; !x 

let handleDecide (e : unit -> bool) : bool =
    match_with e () {
          retc = (fun x -> x)
        ; exnc = (fun e -> raise e)
        ; effc = (fun (type b) (eff : b Effect.t) ->
          match eff with
          | Decide () ->
             Some
               (fun (k : (b, _) continuation) ->
                 let open Multicont.Deep in
                 let r = promote k in
                 (resume r) false || (resume r) true)
          | _ -> None)
    }

let _ = Printf.printf "%b\n" (handleDecide mymain)
