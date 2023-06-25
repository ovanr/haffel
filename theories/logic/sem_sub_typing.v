
(* sem_sub_typing.v *)

(* This file contains the definition sub-typing relations and 
   Copyable (persistent) types
*)


From iris.proofmode Require Import base tactics.
From iris.base_logic.lib Require Import iprop invariants.

(* Hazel Reasoning *)
From program_logic Require Import weakest_precondition 
                                  tactics 
                                  state_reasoning.

(* Local imports *)
From affine_tes.logic Require Import sem_types.
From affine_tes.logic Require Import sem_typed.


(* Copyable types *)
Definition copy_ty `{!heapGS Σ} (τ : sem_ty Σ) := ∀ v, Persistent (τ v).

(* Copyable environment *)
Definition copy_env `{!heapGS Σ} Γ :=
  ∀ vs, Persistent (env_sem_typed Γ vs).

(* Sub-typing and relations *)

Definition ty_le {Σ} (A B : sem_ty Σ) := ∀ v, A v ⊢ B v.
Definition row_le {Σ} (ρ ρ' : sem_row Σ) := ⊢ iEff_le ρ ρ'.
Definition env_le `{!heapGS Σ} Γ₁ Γ₂ :=
  ∀ vs, env_sem_typed Γ₁ vs ⊢ env_sem_typed Γ₂ vs.

Notation "Γ₁ '≤E' Γ₂" := (env_le Γ₁ Γ₂) (at level 98).
Notation "τ '≤T' κ" := (ty_le τ%T κ%T) (at level 98).

Notation "ρ '≤R' ρ'" := (row_le ρ%R ρ'%R) (at level 98).

Section sub_typing.

  Context `{!heapGS Σ}.

  Lemma row_le_refl (ρ : sem_row Σ) : ρ ≤R ρ.
  Proof. iApply iEff_le_refl. Qed.
  
  Lemma row_le_trans (ρ₁ ρ₂ ρ₃: sem_row Σ) : 
      ρ₁ ≤R ρ₂ →
      ρ₂ ≤R ρ₃ →
      ρ₁ ≤R ρ₃. 
  Proof. 
    intros Hρ₁₂ Hρ₂₃. 
    iApply iEff_le_trans; [iApply Hρ₁₂|iApply Hρ₂₃]. 
  Qed.
  
  Lemma row_le_bot (ρ : sem_row Σ) :
    ⟨⟩ ≤R ρ.
  Proof. iApply iEff_le_bottom. Qed.
  
  Lemma row_le_eff (ι₁ ι₂ κ₁ κ₂ : sem_ty Σ) :
    ι₁ ≤T ι₂ →
    κ₂ ≤T κ₁ →
    ((ι₁ ⇒ κ₁) ≤R (ι₂ ⇒ κ₂)).
  Proof.
    iIntros (Hι₁₂ Hκ₂₁ v) "%Φ !#".
    rewrite !sem_row_eff_eq.
    iIntros "(%a & -> & Hι₁ & HκΦ₁)".
    iExists v. iSplit; first done. iSplitL "Hι₁".
    { by iApply Hι₁₂. }
    iIntros (b) "Hκ₂". iApply "HκΦ₁".
    by iApply Hκ₂₁.
  Qed.
  
  Lemma ty_le_refl (τ : sem_ty Σ) : τ ≤T τ.
  Proof. done. Qed.
  
  Lemma ty_le_trans (τ₁ τ₂ τ₃ : sem_ty Σ) :
    τ₁ ≤T τ₂ →
    τ₂ ≤T τ₃ →
    τ₁ ≤T τ₃.
  Proof. 
    iIntros (Hτ₁₂ Hτ₂₃ v) "Hτ₁". 
    iApply Hτ₂₃. by iApply Hτ₁₂.
  Qed.
  
  Lemma ty_le_arr (τ κ : sem_ty Σ) (ρ : sem_row Σ) :
    (τ -{ ρ }-> κ) ≤T (τ -{ ρ }-∘ κ).
  Proof.
    iIntros (v) "#Hτκ %w Hw".
    iApply (ewp_mono with "[Hw]").
    { by iApply "Hτκ". }
    iIntros (u) "Hu". by iModIntro.
  Qed.
  
  Lemma ty_le_larr (τ₁ κ₁ τ₂ κ₂ : sem_ty Σ) (ρ ρ' : sem_row Σ) :
    ρ ≤R ρ' →
    τ₂ ≤T τ₁ →
    κ₁ ≤T κ₂ →
    (τ₁ -{ ρ }-∘ κ₁) ≤T (τ₂ -{ ρ' }-∘ κ₂).
  Proof.
    iIntros (Hρ Hτ₂₁ Hκ₁₂ v) "Hτκ₁ %w Hw".
    iApply ewp_os_prot_mono.
    { iApply Hρ. }
    iApply (ewp_mono with "[Hw Hτκ₁]").
    { iApply "Hτκ₁". by iApply Hτ₂₁. }
    iIntros (u) "Hu". iModIntro. by iApply Hκ₁₂.
  Qed.
  
  Lemma ty_le_uarr (τ₁ κ₁ τ₂ κ₂ : sem_ty Σ) (ρ ρ' : sem_row Σ) :
    ρ ≤R ρ' →
    τ₂ ≤T τ₁ →
    κ₁ ≤T κ₂ →
    (τ₁ -{ ρ }-> κ₁) ≤T (τ₂ -{ ρ' }-> κ₂).
  Proof.
    iIntros (Hρ Hτ₂₁ Hκ₁₂ v) "#Hτκ₁ %w !# Hw".
    iApply ewp_os_prot_mono.
    { iApply Hρ. }
    iApply (ewp_mono with "[Hw]").
    { iApply "Hτκ₁". by iApply Hτ₂₁. }
    iIntros (u) "Hu". iModIntro. by iApply Hκ₁₂.
  Qed.
  
  Lemma ty_le_prod (τ₁ τ₂ κ₁ κ₂ : sem_ty Σ) :
    τ₁ ≤T τ₂ →
    κ₁ ≤T κ₂ →
    (τ₁ × κ₁) ≤T (τ₂ × κ₂).
  Proof.
    iIntros (Hτ₁₂ Hκ₁₂ v) "(%w₁ & %w₂ & -> &Hw₁ & Hw₂)".
    iExists w₁, w₂. iSplit; first done. iSplitL "Hw₁".
    { by iApply Hτ₁₂. }
    by iApply Hκ₁₂.
  Qed.
  
  Lemma ty_le_list (τ₁ τ₂ : sem_ty Σ) :
    τ₁ ≤T τ₂ →
    List τ₁ ≤T List τ₂.
  Proof.
    iIntros (Hτ₁₂ v) "(%xs & Hxs)". iExists xs.
    iInduction xs as [|x xxs] "IH" forall (v); simpl.
    { by iDestruct "Hxs" as "->". }
    iDestruct "Hxs" as "(%tl & -> & Hτ₁ & Hxxs)".
    iExists tl. iSplitR; first done.
    iSplitL "Hτ₁"; [by iApply Hτ₁₂|]. 
    by iApply "IH".
  Qed.
  
  Lemma env_le_refl Γ : Γ ≤E Γ.
  Proof. done. Qed.
  
  Lemma env_le_trans Γ₁ Γ₂ Γ₃ : 
    Γ₁ ≤E Γ₂ →
    Γ₂ ≤E Γ₃ →
    Γ₁ ≤E Γ₃.
  Proof.
    iIntros (HΓ₁₂ HΓ₂₃ vs) "HΓ₁ //=".  
    iApply HΓ₂₃. by iApply HΓ₁₂.
  Qed.
  
  Lemma env_le_cons Γ₁ Γ₂ τ₁ τ₂ x :
    Γ₁ ≤E Γ₂ →
    τ₁ ≤T τ₂ →
    (x, τ₁) :: Γ₁ ≤E (x, τ₂) :: Γ₂.
  Proof.
    iIntros (HΓ₁₂ Hτ₁₂ vs) "//= ((%v & Hlookup & Hv) & HΓ₁)".
    iSplitR "HΓ₁"; last (by iApply HΓ₁₂).
    iExists v. iFrame. by iApply Hτ₁₂.
  Qed.
  
  Lemma env_le_copy_contraction Γ x τ :
    copy_ty τ →
    (x, τ) :: Γ ≤E (x, τ) :: (x, τ) :: Γ.
  Proof.
    iIntros (Hcpyτ vs) "//= [(%w & -> & Hτ) $]". 
    rewrite Hcpyτ. iDestruct "Hτ" as "#Hτ".
    iSplitL; iExists w; by iSplit.
  Qed.
  
  Lemma env_le_swap Γ x y τ κ :
    (x, τ) :: (y, κ) :: Γ ≤E (y, κ) :: (x, τ) :: Γ.
  Proof. iIntros (vs) "($ & $ & $) //=". Qed.
  
End sub_typing.

Section copyable_types.

  Ltac solve_persistent :=
    repeat (intros ? ||
            apply bi.sep_persistent ||
            apply bi.and_persistent ||
            apply bi.or_persistent ||
            apply bi.forall_persistent ||
            apply bi.exist_persistent ||
            apply bi.pure_persistent ||
            apply plainly_persistent ||
            apply bi.persistently_persistent ||
            apply bi.intuitionistically_persistent ||
            apply inv_persistent). 
  
  Context `{!heapGS Σ}.

  (* Copyable types *)
  
  Lemma copy_ty_unit : copy_ty ().
  Proof. solve_persistent. Qed.
  
  Lemma copy_ty_bool : copy_ty 𝔹.
  Proof. solve_persistent. Qed.
  
  Lemma copy_ty_nat : copy_ty ℤ.
  Proof. solve_persistent. Qed.
  
  Lemma copy_ty_ref τ : copy_ty (Ref τ).
  Proof. solve_persistent. Qed.
  
  Lemma copy_ty_uarr τ ρ κ : copy_ty (τ -{ ρ }-> κ).
  Proof. solve_persistent. Qed.
  
  Lemma copy_ty_prod τ κ : copy_ty τ → copy_ty κ → copy_ty (τ × κ).
  Proof. by solve_persistent. Qed.
  
  Lemma copy_ty_list τ : copy_ty τ → copy_ty (List τ).
  Proof.
    iIntros (Hcpy v). unfold sem_ty_list.
    apply bi.exist_persistent. intros xs.
    revert v. induction xs; by solve_persistent. 
  Qed.
  
  Lemma copy_env_nil : copy_env [].
  Proof. solve_persistent. Qed.
  
  Lemma copy_env_cons Γ x τ : 
    copy_env Γ →
    copy_ty τ →
    copy_env ((x, τ) :: Γ).
  Proof. by solve_persistent. Qed.

  Lemma copy_pers τ :
    ⌜ copy_ty τ ⌝ -∗ □ (∀ v, τ v -∗ □ (τ v)).
  Proof.
    iIntros "%Hcpy !# %v Hτ".
    unfold copy_ty, Persistent in Hcpy. 
    by iDestruct (Hcpy v with "Hτ") as "#Hτv".
  Qed.

End copyable_types.