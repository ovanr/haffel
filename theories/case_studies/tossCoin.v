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
From haffel.lib Require Import base.
From haffel.lang Require Import haffel.
From haffel.logic Require Import sem_def.
From haffel.logic Require Import sem_env.
From haffel.logic Require Import sem_sig.
From haffel.logic Require Import sem_row.
From haffel.logic Require Import sem_types.
From haffel.logic Require Import sem_judgement.
From haffel.logic Require Import copyable.
From haffel.logic Require Import sem_operators.
From haffel.logic Require Import compatibility.
From haffel.logic Require Import tactics.

(* Make all the definitions opaque so that we do not rely on their definition in the model to show that the programs are well-typed terms. *)
Opaque sem_typed sem_typed_val ty_le row_le sig_le row_type_sub row_env_sub.
Opaque sem_ty_void sem_ty_unit sem_ty_bool sem_ty_int sem_ty_string sem_ty_top sem_ty_cpy sem_env_cpy sem_ty_ref_cpy sem_ty_ref sem_ty_prod sem_ty_sum sem_ty_arr sem_ty_aarr sem_ty_uarr sem_ty_forall sem_ty_row_forall sem_ty_exists sem_ty_rec sem_ty_option sem_ty_list.
Opaque sem_sig_eff sem_sig_os.
Opaque sem_row_nil sem_row_os sem_row_tun sem_row_cons sem_row_rec.

(* The tossCoin example from paper Soundly Hanlding Linearity by Tang et al. *)

Definition tossCoin : val := 
  (Λ: λ: "g", let: "b" := "g" #() in 
              if: "b" then #(LitStr "heads") else #(LitStr "tails"))%V.

Section typing.

  Context `{!heapGS Σ}.

  Definition tossCoin_ty : sem_ty Σ := 
    (∀R: θ, (() -{ θ }-> 𝔹) -{ θ }-> Str)%T.

  Lemma tossCoin_typed : ⊢ ⊨ᵥ tossCoin : tossCoin_ty.
  Proof.
    iIntros. rewrite /tossCoin /tossCoin_ty.
    iApply sem_typed_Rclosure; solve_sidecond. iIntros (θ).
    rewrite - (app_nil_l []).
    iApply sem_typed_ufun; solve_sidecond. simpl.
    iApply (sem_typed_let 𝔹 θ Str _ []); solve_sidecond.
    - iApply (sem_typed_app_ms ()); solve_sidecond.
      { iApply sem_typed_sub_ty; first iApply ty_le_u2aarr.
        iApply sem_typed_var'. }
      iApply sem_typed_unit'.
    - iApply sem_typed_if; first iApply sem_typed_var';
      iApply sem_typed_string'.
  Qed.

End typing.
