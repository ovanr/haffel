(* This file is largely based on:
    https://github.com/ocaml-multicore/ocaml-effects-tutorial/blob/master/sources/solved/generator.ml
   with some adjustments made:
    ∙ this solution uses the handler's return branch instead of
      defining a recursive reference to avoid the last continuation from being called more than once
 *)
type ('elt,'container) iterator = ('elt -> unit) -> 'container -> unit

type 'elt generator = unit -> 'elt option

let generate (type elt) (i : (elt, 'container) iterator) (c : 'container) : elt generator =
    let open Effect in
    let open Effect.Shallow in
    let open struct
        type _ Effect.t +=
            Yield : elt -> unit Effect.t
    end in 
    let yield x = perform (Yield x) in
    let cont = ref (fiber (fun () -> i yield c; None)) in
    fun () ->
        continue_with !cont () {
            retc = (fun _ -> cont := (fiber (fun () -> None)); None);
            exnc = raise;
            effc = fun (type a) (eff : a Effect.t) ->
                match eff with
                    Yield(x) -> Some(fun (k: (a, _) continuation) -> 
                        cont := k;
                        Some(x)
                    )
                |   _ -> None
        }

let generate_deep (type elt) (i : (elt, 'container) iterator) (c : 'container) : elt generator =
    let open Effect in
    let open Effect.Deep in
    let open struct
        type _ Effect.t +=
            Yield : elt -> unit Effect.t
    end in 
    let yield x = perform (Yield x) in
    let cont = ref (fun () -> i yield c; None) in
    fun () ->
        match_with !cont () {
            retc = (
                function  Some(y) -> Some(y)
                        | None -> cont := (fun () -> None); None);
            exnc = raise;
            effc = fun (type a) (eff : a Effect.t) ->
                match eff with
                    Yield(x) -> Some(fun (k: (a, _) continuation) -> 
                        cont := continue k;
                        Some(x)
                    )
                |   _ -> None
        }

(***********************)
(* Traversal generator *)
(***********************)

let gen_list : 'a list -> 'a generator = generate List.iter
let gl : int generator = gen_list [1;2;3]
;;

assert (Some 1 = gl ());;
assert (Some 2 = gl ());;
assert (Some 3 = gl ());;
assert (None = gl ());;
assert (None = gl ());;

let gen_array : 'a array -> 'a generator = generate Array.iter
let ga : float generator = gen_array [| 1.0; 2.0; 3.0 |]
;;


assert (Some 1.0 = ga ());;
assert (Some 2.0 = ga ());;
assert (Some 3.0 = ga ());;
assert (None = ga ());;
assert (None = ga ());;

(***********)
(* Streams *)
(***********)

(* Iterator over nats. Dummy () container. *)
let rec nats : int (* init *) -> (int, unit) iterator =
    fun v f () ->
    f v; nats (v+1) f ()

(* Infinite stream *)
type 'a stream = unit -> 'a

(* Convert generator to an infinite stream *)
let inf : 'a generator -> 'a stream  =
    fun g () ->
    match g () with
    | Some n -> n
    | _ -> assert false

(* Nat stream *)
let gen_nats : int stream = inf (generate (nats 0) ())
;;

assert (0 = gen_nats ());;
assert (1 = gen_nats ());;
assert (2 = gen_nats ());;
assert (3 = gen_nats ());;

(* filter stream *)
let rec filter : 'a stream -> ('a -> bool) -> 'a stream =
    fun g p () ->
    let v = g () in
    if p v then v
    else filter g p ()

(* map stream *)
let rec map : 'a stream -> ('a -> 'b) -> 'b stream =
    fun g f () -> f (g ())

(* Even stream *)
let gen_even : int stream =
    let nat_stream = inf (generate (nats 0) ()) in
    filter nat_stream (fun n -> n mod 2 = 0)
;;

assert (0 = gen_even ());;
assert (2 = gen_even ());;
assert (4 = gen_even ());;
assert (6 = gen_even ());;

(* Odd stream *)
let gen_odd : int stream =
    let nat_stream = inf (generate (nats 1) ()) in
    filter nat_stream (fun n -> n mod 2 == 1)
;;


assert (1 = gen_odd ());;
assert (3 = gen_odd ());;
assert (5 = gen_odd ());;
assert (7 = gen_odd ());;

(* Primes using sieve of Eratosthenes *)
let gen_primes =
    let s = inf (generate (nats 2) ()) in
    let rs = ref s in
    fun () ->
    let s = !rs in
    let prime = s () in
    rs := filter s (fun n -> n mod prime != 0);
    prime
;;

assert ( 2 = gen_primes ());;
assert ( 3 = gen_primes ());;
assert ( 5 = gen_primes ());;
assert ( 7 = gen_primes ());;
assert (11 = gen_primes ());;
assert (13 = gen_primes ());;
assert (17 = gen_primes ());;
assert (19 = gen_primes ());;
assert (23 = gen_primes ());;
assert (29 = gen_primes ());;
assert (31 = gen_primes ());;