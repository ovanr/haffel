
From stdpp Require Import base list.
From iris.proofmode Require Import base tactics.
From iris.algebra Require Import excl_auth.


(* Hazel Reasoning *)
From hazel.program_logic Require Import weakest_precondition 
                                        tactics 
                                        shallow_handler_reasoning 
                                        deep_handler_reasoning 
                                        state_reasoning.

(* Local imports *)
From affect.lib Require Import base.
From affect.lang Require Import affect.
From affect.logic Require Import sem_def.
From affect.logic Require Import sem_env.
From affect.logic Require Import sem_sig.
From affect.logic Require Import sem_row.
From affect.logic Require Import sem_types.
From affect.logic Require Import sem_judgement.
From affect.logic Require Import copyable.
From affect.logic Require Import sem_operators.
From affect.logic Require Import compatibility.
From affect.logic Require Import tactics.

(* Make all the definitions opaque so that we do not rely on their definition in the model to show that the programs are well-typed terms. *)
Opaque sem_typed sem_typed_val ty_le row_le sig_le row_type_sub row_env_sub.
Opaque sem_ty_void sem_ty_unit sem_ty_bool sem_ty_int sem_ty_string sem_ty_top sem_ty_cpy sem_env_cpy sem_ty_ref_cpy sem_ty_ref sem_ty_prod sem_ty_sum sem_ty_arr sem_ty_aarr sem_ty_uarr sem_ty_forall sem_ty_row_forall sem_ty_exists sem_ty_rec sem_ty_option sem_ty_list.
Opaque sem_sig_eff sem_sig_os.
Opaque sem_row_nil sem_row_os sem_row_tun sem_row_cons sem_row_rec.

Definition reset : val := (Λ: λ: "e", 
  handle[OS]: "e" #() by
    "shift" => (λ: "x" "k", "x" "k")
  | ret     => (λ: "x", "x")
  end)%V.
            
Definition shift : val := (Λ: λ: "f", perform: "shift" (λ: "x", reset ("f" "x")))%V.

Section typing.

  Context `{!heapGS Σ}.

  Definition shift_eff (α : sem_ty Σ) : operation * sem_sig Σ := 
    ("shift", ∀S: (β : sem_ty Σ), (β ⊸ α) ⊸ α =[OS]=> β)%S.

  Definition shift_row (α : sem_ty Σ) : sem_row Σ := (shift_eff α · ⟨⟩)%R.

  Definition shift_ty : sem_ty Σ := ∀T: α β, ((() -{ shift_row α }-∘ α) -{ shift_row α }-∘ 
                                                -{ shift_row α }-> α. 

  Definition reset_ty : sem_ty Σ := ∀T: α, (() -{ shift_row α }-∘ α) → α.

  Lemma shift_typed k : ⊢ ⊨ᵥ shift k : shift_ty.
