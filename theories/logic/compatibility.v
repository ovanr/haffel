
(* compatibility.v *)

(* 
  The compatibility lemmas are what one gets when the syntactic typing judgment
  is replaced with a semantic typing judgment.
*)

From iris.proofmode Require Import base tactics.
From iris.base_logic.lib Require Import iprop invariants.

(* Hazel Reasoning *)
From hazel.program_logic Require Import weakest_precondition 
                                        tactics 
                                        shallow_handler_reasoning 
                                        deep_handler_reasoning 
                                        state_reasoning.

(* Local imports *)
From affine_tes.lib Require Import base.
From affine_tes.lang Require Import hazel.
From affine_tes.lang Require Import subst_map.
From affine_tes.logic Require Import iEff.
From affine_tes.logic Require Import sem_def.
From affine_tes.logic Require Import tactics.
From affine_tes.logic Require Import sem_types.
From affine_tes.logic Require Import sem_env.
From affine_tes.logic Require Import sem_sub_typing.
From affine_tes.logic Require Import sem_operators.


Open Scope bi_scope.
Open Scope stdpp_scope.
Open Scope ieff_scope.
  
(* Semantic typing rules. *)

Section compatibility.

  Context `{!heapGS Σ}.
  
  Lemma sem_typed_val Γ τ v : 
    ⊨ᵥ v : τ -∗ Γ ⊨ v : ⟨⟩ : τ ⊨ Γ.
  Proof.
    iIntros "#Hv !# %vs HΓ /=".
    iApply ewp_value. iIntros "{$Hv} {$HΓ}".
  Qed.

  (* Base rules *)
  
  Lemma sem_typed_unit Γ : 
    ⊢ Γ ⊨ #() : ⟨⟩ : () ⊨ Γ.
  Proof.
    iIntros (vs) "!# HΓ₁ //=". iApply ewp_value. by iFrame.
  Qed.
  
  Lemma sem_typed_bool Γ (b : bool) : 
    ⊢ Γ ⊨ #b : ⟨⟩ : 𝔹 ⊨ Γ.
  Proof.
    iIntros (vs) "!# HΓ₁ //=". iApply ewp_value. 
    iSplitR; first (iExists b); done.
  Qed.
  
  Lemma sem_typed_int Γ (i : Z) : 
    ⊢ Γ ⊨ #i : ⟨⟩ : ℤ ⊨ Γ.
  Proof.
    iIntros (vs) "!# HΓ₁ //=". iApply ewp_value. 
    iSplitR; first (iExists i); done.
  Qed.
  
  Lemma sem_typed_var Γ x τ : 
    ⊢ (x, τ) :: Γ ⊨ x : ⟨⟩ : τ ⊨ Γ.
  Proof.
    iIntros (vs) "!# /= [%v (%Hrw & Hτ & HΓ₁)] /=". 
    rewrite Hrw. iApply ewp_value. iFrame.
  Qed.

  Lemma sem_typed_bot_in_env Γ₁ Γ₂ e x τ : 
    ⊢ (x, @sem_ty_void Σ) :: Γ₁ ⊨ e : ⟨⟩ : τ ⊨ Γ₂.
  Proof.
    iIntros (vs) "!# /= [%v (%Hrw & [] & _)] /=". 
  Qed.

  Lemma sem_typed_closure f x e τ ρs κ :
    match f with BNamed f => BNamed f ≠ x | BAnon => True end →
    (x, τ) ::? (f, τ -{ ρs }-> κ) ::? [] ⊨ e : ρs : κ ⊨ [] -∗ 
    ⊨ᵥ (rec: f x := e) : (τ -{ ρs }-> κ).
  Proof.
      iIntros (?) "#He !#". iLöb as "IH".
      iIntros "%v !# Hτ /=". 
      ewp_pure_steps. destruct x as [|x]; destruct f as [|f]; simpl.
      - rewrite - {3} [e]subst_map_empty. 
        iApply (ewp_pers_mono with "[He]"); first (by iApply "He").
        iIntros "!# % [$ _] //=". 
      - rewrite -subst_map_singleton.
        iApply ewp_pers_mono; [iApply "He"; solve_env|solve_env].
        iIntros "!# % [$ _] //=".
      - rewrite -subst_map_singleton.
        iApply (ewp_pers_mono with "[Hτ]"); [iApply "He"; solve_env|solve_env].
        iIntros "!# % [$ _] //=".
      - rewrite -(subst_map_singleton f) -subst_map_singleton subst_map_union.
        iApply (ewp_pers_mono with "[Hτ]"); [iApply "He"|iIntros "!# % [$ _] //="].
        rewrite -insert_union_singleton_r; [solve_env|apply lookup_singleton_ne];
        intros ?; simplify_eq.
  Qed.

  Lemma sem_typed_Tclosure e τ ρs :
    (∀ α, ⊨ e : ρs : τ α) -∗ 
    ⊨ᵥ (Λ: e) : (∀T: α, ρs , τ α).
  Proof.
    iIntros "#He !# %u !#". ewp_pure_steps.
    rewrite - {2} [e]subst_map_empty.
    iSpecialize ("He" $! u).
    iApply (ewp_pers_mono with "[He]"); [iApply "He"|]; first done. 
    iIntros "!# % [$ _] //=".
  Qed.

  (* Signature abstraction and application *)
  Lemma sem_typed_Sclosure e C : 
    (∀ θ, ⊨ e : θ : C θ) -∗
    ⊨ᵥ (Λ: e) : (∀S: θ , C θ)%T.
  Proof.
    iIntros "#He !# %ρ /=".
    ewp_pure_steps. rewrite - {2} [e]subst_map_empty. 
    iApply (ewp_pers_mono with "[He]"); [by iApply "He"|].
    iIntros "!# % [$ _] //=". 
  Qed.

  Lemma sem_typed_closure_to_unrestricted x e τ ρs κ :
    ⊨ᵥ (λ: x, e) : (τ -{ ρs }-∘ κ) -∗
    ⊨ᵥ (λ: x, e) : (τ -{ ρs }-> κ).
  Proof. 
    iIntros "#He !# %w !# Hτ". 
    iSpecialize ("He" $! w).
    iApply ("He" with "Hτ").
  Qed.

  (* Subsumption rule *)
  
  Lemma sem_typed_sub Γ₁ Γ₁' Γ₂ Γ₂' e ρs ρs' τ τ':
    Γ₁  ≤E Γ₁' →
    Γ₂' ≤E Γ₂ →
    ρs' ≤Rs ρs → 
    τ'  ≤T τ →
    Γ₁' ⊨ e : ρs' : τ' ⊨ Γ₂' -∗ Γ₁ ⊨ e : ρs : τ ⊨ Γ₂.
  Proof.
    iIntros (HΓ₁le HΓ₂le [Hρle₁ Hρle₂] Hτle) "#He !# %vs HΓ₁ //=".
    rewrite HΓ₁le.
    iApply ewp_os_prot_mono; [iApply Hρle₁|].
    iApply ewp_ms_prot_mono; [iApply Hρle₂|].
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He").
    iIntros "!# % [Hτ HΓ₂] //=".
    rewrite HΓ₂le Hτle. by iFrame.
  Qed. 
  
  (* Convenient Subsumption rules *)
  Lemma sem_typed_sub_ty τ' τ Γ₁ Γ₂ e ρs :
  τ' ≤T τ →
  (Γ₁ ⊨ e : ρs : τ' ⊨ Γ₂) -∗ Γ₁ ⊨ e : ρs : τ ⊨ Γ₂.
  Proof.
    iIntros (Hτ).
    iApply (sem_typed_sub Γ₁ Γ₁ Γ₂ Γ₂ _ ρs ρs);
      (apply sigs_le_refl || apply env_le_refl || done). 
  Qed.

  Lemma sem_typed_sub_sig ρs ρs' Γ₁ Γ₂ e τ :
    ρs' ≤Rs ρs →
    (Γ₁ ⊨ e : ρs' : τ ⊨ Γ₂) -∗ Γ₁ ⊨ e : ρs : τ ⊨ Γ₂.
  Proof.
    iIntros (Hρ).
    iApply (sem_typed_sub Γ₁ Γ₁ Γ₂ Γ₂ _ ρs ρs' τ τ);
      (apply sigs_le_refl || apply env_le_refl || apply ty_le_refl || done).
  Qed.

  Lemma sem_typed_sub_nil Γ₁ Γ₂ e τ ρs :
    (Γ₁ ⊨ e : ⟨⟩ : τ ⊨ Γ₂) -∗ Γ₁ ⊨ e : ρs : τ ⊨ Γ₂.
  Proof. iApply sem_typed_sub_sig. apply sigs_le_nil. Qed.
  
  Lemma sem_typed_sub_env Γ₁ Γ₁' Γ₂ e ρs τ :
    Γ₁ ≤E Γ₁' →
    (Γ₁' ⊨ e : ρs : τ ⊨ Γ₂) -∗ Γ₁ ⊨ e : ρs : τ ⊨ Γ₂.
  Proof.
    iIntros (HΓ₁).
    iApply (sem_typed_sub Γ₁ Γ₁' Γ₂ Γ₂ _ ρs ρs τ τ);
      (apply sigs_le_refl || apply env_le_refl || apply ty_le_refl || done).
  Qed.

  Lemma sem_typed_swap_second Γ₁ Γ₂ x y e ρs τ₁ τ₂ κ :
    ((y, τ₂) :: (x, τ₁) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂) -∗ 
    ((x, τ₁) :: (y, τ₂) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂).
  Proof.
    iIntros "He".
    iApply sem_typed_sub_env; [apply env_le_swap_second|iApply "He"].
  Qed.

  Lemma sem_typed_swap_third Γ₁ Γ₂ x y z e ρs τ₁ τ₂ τ₃ κ :
    ((z, τ₃) :: (x, τ₁) :: (y, τ₂) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂) -∗ 
    ((x, τ₁) :: (y, τ₂) :: (z, τ₃) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂).
  Proof.
    iIntros "He".
    iApply sem_typed_sub_env; [|iApply "He"].
    eapply env_le_trans; apply env_le_swap_third.
  Qed.

  Lemma sem_typed_swap_fourth Γ₁ Γ₂ x y z z' e ρs τ₁ τ₂ τ₃ τ₄ κ :
    ((z', τ₄) :: (x, τ₁) :: (y, τ₂) :: (z, τ₃) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂) -∗ 
    ((x, τ₁) :: (y, τ₂) :: (z, τ₃) :: (z', τ₄) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂).
  Proof.
    iIntros "He".
    iApply sem_typed_sub_env; [|iApply "He"].
    do 2 (eapply env_le_trans; [apply env_le_swap_fourth|]).
    apply env_le_swap_fourth.
  Qed.

  Lemma sem_typed_swap_env_singl Γ₁ Γ₂ x e ρs τ κ :
    (Γ₁ ++ [(x, τ)] ⊨ e : ρs : κ ⊨ Γ₂) -∗ 
    ((x, τ) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂). 
  Proof.
    iIntros "He".
    iApply sem_typed_sub_env; [|iApply "He"].
    apply env_le_swap_env_singl.
  Qed.

  Lemma sem_typed_contraction Γ₁ Γ₂ x e ρs τ κ :
    copy_ty τ →
    (x, τ) :: (x, τ) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂ -∗ 
    (x, τ) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂.
  Proof.
    iIntros (?) "He".
    iApply sem_typed_sub_env; 
      [by apply env_le_copy_contraction|iApply "He"].
  Qed.

  Lemma sem_typed_weaken Γ₁ Γ₂ x e ρs τ κ :
    (Γ₁ ⊨ e : ρs : κ ⊨ Γ₂) -∗ ((x, τ) :: Γ₁ ⊨ e : ρs : κ ⊨ Γ₂).
  Proof.
    iIntros "He".
    iApply sem_typed_sub_env; [apply env_le_weaken|iApply "He"].
  Qed.

  Lemma sem_typed_frame_os Γ₁ e ρ x τ κ Γ₂:
    Γ₁ ⊨ e : ⟨ ρ, ⟩ : κ ⊨ Γ₂ -∗
    (x, τ) :: Γ₁ ⊨ e : ⟨ ρ, ⟩ : κ ⊨ (x, τ) :: Γ₂.
  Proof.
    iIntros "#He %vs !# (%v & %Hrw & Hτ & HΓ₁)".
    iApply (ewp_mono with "[HΓ₁]"); first (by iApply "He").
    iIntros (w) "[Hκ HΓ₂]". solve_env.
  Qed.

  Lemma sem_typed_frame_env_os Γ₁ Γ' e ρ τ Γ₂ :
    Γ₁ ⊨ e : ⟨ ρ, ⟩ : τ ⊨ Γ₂ -∗
    Γ' ++ Γ₁ ⊨ e : ⟨ ρ, ⟩ : τ ⊨ Γ' ++ Γ₂.
  Proof.
    iIntros "#He %vs !# HΓ'Γ₁".
    iDestruct (env_sem_typed_app with "HΓ'Γ₁") as "[HΓ' HΓ₁]".
    iInduction Γ' as [|[x κ]] "IH".
    { simpl. by iApply "He". }
    iDestruct "HΓ'" as "(%v & %Hrw & Hκ & HΓ'')".
    iApply (ewp_mono with "[HΓ'' HΓ₁]").
    { iApply ("IH" with "HΓ'' HΓ₁"). }
    iIntros (w) "[$ HΓ] !>". solve_env.
  Qed.

  Lemma sem_typed_frame_ms Γ₁ e ρs x τ κ Γ₂:
    copy_ty τ →
    Γ₁ ⊨ e : ρs : κ ⊨ Γ₂ -∗
    (x, τ) :: Γ₁ ⊨ e : ρs : κ ⊨ (x, τ) :: Γ₂.
  Proof.
    iIntros (Hcpy) "#He %vs !# (%v & %Hrw & Hτ & HΓ₁)".
    rewrite Hcpy. iDestruct "Hτ" as "#Hτ".
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He").
    iIntros "!# % [Hκ HΓ₂]". solve_env.
  Qed.

  (* λ-calculus rules *)

  Lemma sem_typed_afun Γ₁ Γ₂ x e τ ρs κ: 
    x ∉ (env_dom Γ₁) → x ∉ (env_dom Γ₂) →
    (x,τ) ::? Γ₁ ⊨ e : ρs : κ ⊨ [] -∗
    Γ₁ ++ Γ₂ ⊨ (λ: x, e) : ⟨⟩ : (τ -{ ρs }-∘ κ) ⊨ Γ₂.
  Proof.
    iIntros (??) "#He !# %vs HΓ₁₂ //=".
    iDestruct (env_sem_typed_app with "HΓ₁₂") as "[HΓ₁ HΓ₂]".
    ewp_pure_steps. iFrame.
    iIntros (w) "Hτ". 
    ewp_pure_steps. rewrite subst'_subst_map_insert.
    iApply (ewp_pers_mono with "[Hτ HΓ₁]"); [iApply "He"|iIntros "!# % [$ _] //="].
    destruct x; solve_env. 
  Qed.

  Lemma sem_typed_ufun Γ₁ Γ₂ f x e τ ρs κ:
    x ∉ (env_dom Γ₁) → f ∉ (env_dom Γ₁) → 
    match f with BNamed f => BNamed f ≠ x | BAnon => True end →
    copy_env Γ₁ →
    (x, τ) ::? (f, τ -{ ρs }-> κ) ::? Γ₁ ⊨ e : ρs : κ ⊨ [] -∗
    Γ₁ ++ Γ₂ ⊨ (rec: f x := e) : ⟨⟩ : (τ -{ ρs }-> κ) ⊨ Γ₂.
  Proof.
    iIntros (??? HcpyΓ₁) "#He !# %vs HΓ₁₂ //=".
    ewp_pure_steps.
    rewrite env_sem_typed_app. iDestruct "HΓ₁₂" as "[HΓ₁ $]".
    rewrite HcpyΓ₁. iDestruct "HΓ₁" as "#HΓ₁".
    iLöb as "IH".
    iIntros "!# %w  Hτ". 
    ewp_pure_steps. destruct f; destruct x; simpl.
    - iApply ewp_pers_mono; [by iApply "He"|iIntros "!# % [$ _] //="].
    - rewrite -subst_map_insert. 
      iApply (ewp_pers_mono with "[Hτ]"); [iApply "He"; solve_env|iIntros "!# % [$ _] //="].
    - rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[Hτ]"); [iApply "He"; solve_env|iIntros "!# % [$ _] //="].
    - assert (s ≠ s0) by (intros ?; simplify_eq).
      rewrite subst_subst_ne; last done.
      rewrite -subst_map_insert.
      rewrite -delete_insert_ne; last done. 
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[Hτ]"); [iApply "He"; solve_env|iIntros "!# % [$ _] //="].
      by do 2 (rewrite -env_sem_typed_insert; last done).
  Qed.

  Lemma sem_typed_ufun_poly_rec Γ₁ Γ₂ f x e τ ρs κ:
    x ∉ (env_dom Γ₁) → f ∉ (env_dom Γ₁) → 
    match x with BNamed x => BNamed x ≠ f | BAnon => True end →
    copy_env Γ₁ →
    (∀ ι, (x, τ ι) ::? (f, ∀T: α,, τ α -{ ρs α }-> κ α) ::? Γ₁ ⊨ e : ρs ι : κ ι ⊨ []) -∗
    Γ₁ ++ Γ₂ ⊨ (rec: f <> := λ: x, e) : ⟨⟩ : (∀T: α,, τ α -{ ρs α }-> κ α) ⊨ Γ₂.
  Proof.
    iIntros (??? HcpyΓ₁) "#He !# %vs HΓ₁₂ //=".
    ewp_pure_steps. rewrite env_sem_typed_app. 
    iDestruct "HΓ₁₂" as "[HΓ₁ $]".
    rewrite HcpyΓ₁. iDestruct "HΓ₁" as "#HΓ₁".
    iLöb as "IH".
    iIntros (α) "!#". ewp_pure_steps.
    destruct f; destruct x; simpl; 
    ewp_pure_steps; iIntros (v) "!# Hτ"; ewp_pure_steps.
    - iApply ewp_pers_mono; first (by iApply "He").  
      iIntros "!# % [$ _] //=".
    - rewrite -subst_map_insert. 
      iApply (ewp_pers_mono with "[Hτ]"); first (iApply "He"; solve_env).  
      iIntros "!# % [$ _] //=".
    - rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[Hτ]"); first (iApply "He"; solve_env).  
      iIntros "!# % [$ _] //=".
    - assert (s ≠ s0) by (intros ?; simplify_eq).
      rewrite decide_True; last auto.
      rewrite subst_subst_ne; last done.
      rewrite -subst_map_insert.
      rewrite -delete_insert_ne; last done. 
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[Hτ]"); first (iApply "He"; solve_env).  
      + by do 2 (rewrite -env_sem_typed_insert; last done).
      + iIntros "!# % [$ _] //=".
  Qed.

  Lemma sem_typed_let Γ₁ Γ₂ Γ₃ x e₁ e₂ τ ρs κ: 
    x ∉ (env_dom Γ₂) → x ∉ (env_dom Γ₃) →
    Γ₁ ⊨ e₁ : ρs : τ ⊨ Γ₂ -∗
    (x, τ) :: Γ₂ ⊨ e₂ : ρs : κ ⊨ Γ₃ -∗
    Γ₁ ⊨ (let: x := e₁ in e₂) : ρs : κ ⊨ Γ₃.
  Proof.
    iIntros (??) "#He₁ #He₂ !# %vs HΓ₁ /=".
    iApply (ewp_bind ([AppRCtx _])); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He₁").
    iIntros "!# % [Hτ HΓ₂] !> /=". ewp_pure_steps.
    rewrite -subst_map_insert.
    iApply (ewp_pers_mono with "[Hτ HΓ₂]"); first (iApply "He₂"; solve_env).
    iIntros "!# % [Hτκ HΓ₃] !> /=".
    solve_env.
  Qed.

  Lemma sem_typed_app Γ₁ Γ₂ Γ₃ e₁ e₂ τ ρs κ: 
    copy_env Γ₃ →
    Γ₂ ⊨ e₁ : ⟨ρs.1,⟩ : (τ -{ ρs }-∘ κ) ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ (e₁ e₂) : ρs : κ ⊨ Γ₃.
  Proof.
    iIntros (Hcpy) "#He₁ #He₂ !# %vs HΓ₁ /=".
    iApply (ewp_bind [AppRCtx _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He₂").
    iIntros "!# % [Hτ HΓ₂] !> /=".
    iApply (ewp_bind [AppLCtx _]); first done.
    iApply ewp_ms_prot_mono; [iApply sig_le_nil|].
    iApply (ewp_mono with "[HΓ₂]"); first (by iApply "He₁").
    iIntros "% [Hτκ HΓ₃] !> /=".
    rewrite {1}Hcpy. iDestruct "HΓ₃" as "#HΓ₃".
    iApply (ewp_pers_mono with "[Hτ Hτκ]"); first (by iApply "Hτκ").
    iIntros "!# % $ !> //=".
  Qed.

  Lemma sem_typed_app_ms Γ₁ Γ₂ Γ₃ (x₁ x₂ : string) e₁ e₂ τ ρs κ: 
    x₂ ∉ env_dom Γ₂ → x₂ ∉ env_dom Γ₃ → 
    x₁ ∉ env_dom Γ₃ → x₁ ≠ x₂ →
    copy_ty τ → copy_env Γ₃ →
    Γ₂ ⊨ e₁ : ρs : (τ -{ ρs }-∘ κ) ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ (let: x₂ := e₂ in let: x₁ := e₁ in (x₁ x₂)) : ρs : κ ⊨ Γ₃.
  Proof.
    iIntros (???? Hcpyτ HcpyΓ₃) "#He₁ #He₂".
    iApply (sem_typed_let _ Γ₂); solve_sidecond.
    iApply (sem_typed_let _ ((x₂, τ) :: Γ₃)); solve_sidecond.
    { iApply sem_typed_frame_ms; first done. iApply "He₁". }
    iApply (sem_typed_app _ ((x₁, τ -{ ρs }-∘ κ) :: Γ₃)); first done.
    { iApply sem_typed_sub_nil. iApply sem_typed_var. }
    iApply sem_typed_swap_second.
    iApply sem_typed_sub_nil. iApply sem_typed_var.
  Qed.

  Lemma sem_typed_app_alt' Γ₁ Γ₂ Γ₃ (x₁ x₂ : string) e₁ e₂ τ ρs κ: 
    x₂ ∉ env_dom Γ₂ → x₂ ∉ env_dom Γ₃ → 
    x₁ ∉ env_dom Γ₃ → x₁ ≠ x₂ →
    Γ₂ ⊨ e₁ : ⟨ρs.1,⟩ : (τ -{ ⟨ρs.1,⟩ }-∘ κ) ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ (let: x₂ := e₂ in let: x₁ := e₁ in (x₁ x₂)) : ρs : κ ⊨ Γ₃.
  Proof.
    iIntros (????) "#He₁ #He₂".
    iApply (sem_typed_let _ Γ₂); solve_sidecond.
    iApply (sem_typed_let _ ((x₂, τ) :: Γ₃)); solve_sidecond.
    { iApply sem_typed_sub_sig. 
        { apply sigs_le_comp; [apply sig_le_refl|apply sig_le_nil]. }
      iApply sem_typed_frame_os; first done. }
    iApply sem_typed_swap_env_singl. rewrite -app_comm_cons.
    iApply sem_typed_swap_env_singl. rewrite -app_assoc.
    rewrite - {3} (app_nil_r Γ₃).
    iApply sem_typed_sub_sig. 
    { apply sigs_le_comp; [apply sig_le_refl|apply sig_le_nil]. }
    iApply sem_typed_frame_env_os. simpl.
    iApply (sem_typed_app _ [(x₁, τ -{ ⟨ρs.1,⟩ }-∘ κ)]); first solve_copy.
    { iApply sem_typed_sub_nil. iApply sem_typed_var. }
    iApply sem_typed_swap_second.
    iApply sem_typed_sub_nil. iApply sem_typed_var. 
  Qed.

  Lemma sem_typed_seq Γ₁ Γ₂ Γ₃ e₁ e₂ τ ρs κ: 
    Γ₁ ⊨ e₁ : ρs : τ ⊨ Γ₂ -∗
    Γ₂ ⊨ e₂ : ρs : κ ⊨ Γ₃ -∗
    Γ₁ ⊨ (e₁ ;; e₂) : ρs : κ ⊨ Γ₃.
  Proof.
    iIntros "#He₁ #He₂ !# %vs HΓ₁ /=".
    iApply (ewp_bind ([AppRCtx _])); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He₁").
    iIntros "!# % [Hτ HΓ₂] !> /=". ewp_pure_steps.
    iApply (ewp_pers_mono with "[Hτ HΓ₂]"); first (by iApply "He₂").
    iIntros "!# % [Hτκ HΓ₃] !> /=". iFrame.
  Qed.

  Lemma sem_typed_pair Γ₁ Γ₂ Γ₃ e₁ e₂ τ ρs κ: 
    Γ₂ ⊨ e₁ : ⟨ρs.1,⟩ : τ ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : κ ⊨ Γ₂ -∗
    Γ₁ ⊨ (e₁,e₂) : ρs : (τ × κ) ⊨ Γ₃.
  Proof.
    iIntros "#He₁ #He₂ !# %vs HΓ₁ //=".
    iApply (ewp_bind ([PairRCtx (subst_map vs e₁)])); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He₂").
    iIntros "!# % [Hτ HΓ₂] !> /=".
    iApply (ewp_bind ([PairLCtx v])); first done.
    iApply ewp_ms_prot_mono; [iApply sig_le_nil|].
    iApply (ewp_mono with "[HΓ₂]"); first (by iApply "He₁").
    iIntros (w) "[Hκw HΓ₃] //= !>". ewp_pure_steps.
    solve_env.
  Qed.
  
  Lemma sem_typed_pair_ms Γ₁ Γ₂ Γ₃ (x₁ x₂ : string) e₁ e₂ τ ρs κ: 
    x₂ ∉ env_dom Γ₂ → x₂ ∉ env_dom Γ₃ → x₁ ∉ env_dom Γ₃ → x₁ ≠ x₂ →
    copy_ty κ →
    Γ₂ ⊨ e₁ : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : κ ⊨ Γ₂ -∗
    Γ₁ ⊨ (let: x₂ := e₂ in let: x₁ := e₁ in (x₁,x₂)) : ρs : (τ × κ) ⊨ Γ₃.
  Proof.
    iIntros (???? Hcpy) "#He₁ #He₂".
    iApply (sem_typed_let _ Γ₂); solve_sidecond.
    iApply (sem_typed_let _ ((x₂, κ) :: Γ₃)); solve_sidecond.
    { iApply sem_typed_frame_ms; first done. iApply "He₁". }
    iApply sem_typed_sub_nil.
    iApply (sem_typed_pair _ ((x₁, τ) :: Γ₃)); [iApply sem_typed_var|].
    iApply sem_typed_swap_second.
    iApply sem_typed_var.
  Qed.

  Lemma sem_typed_pair_elim Γ₁ Γ₂ Γ₃ x₁ x₂ e₁ e₂ τ ρs κ ι: 
    x₁ ∉ (env_dom Γ₂) → x₂ ∉ (env_dom Γ₂) →
    x₁ ∉ (env_dom Γ₃) → x₂ ∉ (env_dom Γ₃) →
    x₁ ≠ x₂ →
    Γ₁ ⊨ e₁ : ρs : (τ × κ) ⊨ Γ₂ -∗
    (x₁, τ) :: (x₂, κ) :: Γ₂ ⊨ e₂ : ρs : ι ⊨ Γ₃ -∗
    Γ₁ ⊨ (let: (x₁, x₂) := e₁ in e₂) : ρs : ι ⊨ Γ₃.
  Proof.
    iIntros (?????) "#He₁ #He₂ !# %vs HΓ₁ //=". ewp_pure_steps.
    set ex1x2 := (λ: x₁ x₂, subst_map (binder_delete x₂ 
                                      (binder_delete x₁ vs)) e₂)%V. 
    iApply (ewp_bind ([AppLCtx ex1x2; AppRCtx pair_elim])); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He₁").
    iIntros "!# % [Hτκv HΓ₂] //= !>". 
    unfold pair_elim. ewp_pure_steps.
    iDestruct "Hτκv" as "(%v₁ & %v₂ & -> & Hτ & Hκ)".
    unfold ex1x2. ewp_pure_steps. 
    destruct (decide _) as [[]|[]]; [|split; [done|congruence]].
    rewrite delete_commute -subst_map_insert -delete_insert_ne; last congruence.
    rewrite -subst_map_insert.
    iApply (ewp_pers_mono with "[Hτ Hκ HΓ₂]"); first (iApply "He₂").
    - iExists v₁. iFrame. iSplitL "".
      { rewrite lookup_insert_ne; last done. by rewrite lookup_insert. }
      iExists v₂. iFrame; iSplitL ""; [by rewrite lookup_insert|].
      by do 2 (rewrite -env_sem_typed_insert; last done).
    - iIntros "!# % [Hιv HΓ₃]". iFrame.
      rewrite -(env_sem_typed_insert _ _ x₂ v₂); last done.
      by rewrite -(env_sem_typed_insert _ _ x₁ v₁).
  Qed.
  
  Lemma sem_typed_left_inj Γ₁ Γ₂ e τ ρs κ: 
    Γ₁ ⊨ e : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ InjL e : ρs : (τ + κ) ⊨ Γ₂.
  Proof.
    iIntros "#He !# %vs HΓ₁ //=".
    iApply (ewp_bind [InjLCtx]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He").
    iIntros "!# % [Hτ HΓ₂] /= !>". ewp_pure_steps.
    iFrame. iExists v. iLeft. by iFrame.
  Qed.

  Lemma sem_typed_right_inj Γ₁ Γ₂ e τ ρs κ: 
    Γ₁ ⊨ e : ρs : κ ⊨ Γ₂ -∗
    Γ₁ ⊨ InjR e : ρs : (τ + κ) ⊨ Γ₂.
  Proof.
    iIntros "#He !# %vs HΓ₁ //=".
    iApply (ewp_bind [InjRCtx]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He").
    iIntros "!# % [Hκ HΓ₂] /= !>". ewp_pure_steps.
    iFrame. iExists v. iRight. by iFrame.
  Qed.

  Lemma sem_typed_match Γ₁ Γ₂ Γ₃ e₁ x y e₂ e₃ τ ρs κ ι: 
    x ∉ env_dom Γ₂ → x ∉ env_dom Γ₃ → y ∉ env_dom Γ₂ → y ∉ env_dom Γ₃ →
    Γ₁ ⊨ e₁ : ρs : (τ + κ) ⊨ Γ₂ -∗
    (x, τ) ::? Γ₂ ⊨ e₂ : ρs : ι ⊨ Γ₃ -∗
    (y, κ) ::? Γ₂ ⊨ e₃ : ρs : ι ⊨ Γ₃ -∗
    Γ₁ ⊨ match: e₁ with InjL x => e₂ | InjR y => e₃ end : ρs : ι ⊨ Γ₃.
  Proof.
    iIntros (????) "#He₁ #He₂ #He₃ !# %vs HΓ₁ //=".
    iApply (ewp_bind [CaseCtx _ _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He₁").
    iIntros "!# %v [(%w & [(-> & Hτ)|(-> & Hκ)]) HΓ₂] //= !>"; ewp_pure_steps.
    - destruct x; simpl.
      + iApply (ewp_pers_mono with "[HΓ₂ Hτ]"); [by iApply "He₂"|eauto].
      + rewrite -subst_map_insert.
        iApply (ewp_pers_mono with "[HΓ₂ Hτ]"); first (iApply "He₂"; solve_env).
        iIntros "!# % [$ HΓ₃] //=". solve_env.
    - destruct y; simpl.
      + iApply (ewp_pers_mono with "[HΓ₂ Hκ]"); [iApply "He₃"; solve_env|eauto].
      + rewrite -subst_map_insert.
        iApply (ewp_pers_mono with "[HΓ₂ Hκ]"); [iApply "He₃"; solve_env|].
        iIntros "!# % [$ HΓ₃] //=". solve_env.
  Qed.

  Lemma sem_typed_none Γ₁ τ: 
    ⊢ Γ₁ ⊨ NONE : ⟨⟩ : Option τ ⊨ Γ₁.
  Proof.
    iIntros. iApply sem_typed_left_inj. iApply sem_typed_unit. 
  Qed.

  Lemma sem_typed_some Γ₁ Γ₂ e ρs τ: 
    Γ₁ ⊨ e : ρs : τ ⊨ Γ₂ -∗ 
    Γ₁ ⊨ SOME e : ρs : Option τ ⊨ Γ₂.
  Proof.
    iIntros "He". iApply sem_typed_right_inj. iApply "He".
  Qed.

  Lemma sem_typed_match_option Γ₁ Γ₂ Γ₃ e₁ x e₂ e₃ ρs κ ι: 
    x ∉ env_dom Γ₂ → x ∉ env_dom Γ₃ →
    Γ₁ ⊨ e₁ : ρs : Option κ ⊨ Γ₂ -∗
    Γ₂ ⊨ e₂ : ρs : ι ⊨ Γ₃ -∗
    (x, κ) :: Γ₂ ⊨ e₃ : ρs : ι ⊨ Γ₃ -∗
    Γ₁ ⊨ match: e₁ with NONE => e₂ | SOME x => e₃ end : ρs : ι ⊨ Γ₃.
  Proof.
    iIntros (??) "#He₁ #He₂ #He₃ !# %vs HΓ₁ //=".
    iApply (ewp_bind [CaseCtx _ _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); first (by iApply "He₁").
    iIntros "!# %v [(%w & [(-> & _)|(-> & Hκ)]) HΓ₂] !> //="; ewp_pure_steps.
    - iApply (ewp_pers_mono with "[HΓ₂]"); [iApply "He₂"; solve_env|eauto].
    - rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[HΓ₂ Hκ]"); [iApply "He₃"; solve_env|].
      iIntros "!# % [$ HΓ₃] //=". solve_env.
  Qed.

  Lemma bin_op_copy_types τ κ ι op :
    typed_bin_op op τ κ ι → copy_ty τ ∧ copy_ty κ ∧ copy_ty ι.
  Proof. intros []; (split; [|split]); solve_copy. Qed.

  Lemma sem_typed_bin_op Γ₁ Γ₂ Γ₃ e₁ e₂ op τ κ ι ρs: 
    typed_bin_op op τ κ ι →
    Γ₂ ⊨ e₁ : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : κ ⊨ Γ₂ -∗
    Γ₁ ⊨ BinOp op e₁ e₂ : ρs : ι ⊨ Γ₃.
  Proof.
    iIntros (Hop) "#He₁ #He₂ !# %vs HΓ₁ //=".
    destruct (bin_op_copy_types _ _ _ _ Hop) as [Hcpyτ [Hcpyκ Hcpyι]]. 
    iApply (ewp_bind [BinOpRCtx _ _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [iApply "He₂"; solve_env|eauto].
    iIntros "!# %v [Hκ HΓ₂] //= !>". 
    iApply (ewp_bind [BinOpLCtx _ _]); first done.
    iApply (ewp_pers_mono with "[HΓ₂]"); [iApply "He₁"; solve_env|eauto].
    rewrite Hcpyκ. iDestruct "Hκ" as "#Hκ".
    iIntros "!# %w [Hτ HΓ₂] //= !>".
    destruct op; inversion_clear Hop;
      iDestruct "Hτ" as "(%n1 & ->)";
      iDestruct "Hκ" as "(%n2 & ->)";
      ewp_pure_steps; try done; eauto.
  Qed.
  
  Lemma sem_typed_if Γ₁ Γ₂ Γ₃ e₁ e₂ e₃ ρs τ: 
    Γ₁ ⊨ e₁ : ρs : 𝔹 ⊨ Γ₂ -∗
    Γ₂ ⊨ e₂ : ρs : τ ⊨ Γ₃ -∗
    Γ₂ ⊨ e₃ : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ⊨ (if: e₁ then e₂ else e₃) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros "#He₁ #He₂ #He₃ !# %vs HΓ₁ //=".
    iApply (ewp_bind [IfCtx (subst_map vs e₂) (subst_map vs e₃)]) ;first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [iApply "He₁"; solve_env|eauto].
    iIntros "!# %v ((%b & ->) & HΓ₂) //= !>".
    destruct b; ewp_pure_steps.
    - iApply (ewp_pers_mono with "[HΓ₂]"); [iApply "He₂"; solve_env|eauto].
    - iApply (ewp_pers_mono with "[HΓ₂]"); [iApply "He₃"; solve_env|eauto].
  Qed.
  
  (* Type abstraction and application *)
  Lemma sem_typed_TLam Γ₁ Γ₂ ρs e C : 
    copy_env Γ₁ →
    (∀ α, Γ₁ ⊨ e : ρs : C α ⊨ []) -∗
    Γ₁ ++ Γ₂ ⊨ (Λ: e) : ⟨⟩ : (∀T: α , ρs , C α)%T ⊨ Γ₂.
  Proof.
    iIntros (Hcpy) "#He !# %vs HΓ₁₂ //=".
    iDestruct (env_sem_typed_app with "HΓ₁₂") as "[HΓ₁ HΓ₂]".
    rewrite Hcpy. iDestruct "HΓ₁" as "#HΓ₁".
    ewp_pure_steps. iIntros "{$HΓ₂} %α //= !#". ewp_pure_steps.
    iApply (ewp_pers_mono with "[HΓ₁]"); [iApply "He"; solve_env|].
    iIntros "!# %w [$ _] //=".
  Qed.

  Lemma sem_typed_TApp Γ₁ Γ₂ e ρs τ C :
    copy_env Γ₂ →
    Γ₁ ⊨ e : ρs : (∀T: α , ρs , C α) ⊨ Γ₂ -∗
    Γ₁ ⊨ e <_> : ρs : C τ ⊨ Γ₂. 
  Proof.
    iIntros (Hcpy) "#He !# %vs HΓ₁ /=".
    iApply (ewp_bind [AppLCtx _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [iApply "He"; solve_env|].
    iIntros "!# %w [Hw HΓ₂] //= !>".
    iApply (ewp_pers_mono with "[Hw]"); [iApply "Hw"|].
    rewrite {1}Hcpy. iDestruct "HΓ₂" as "#HΓ₂".
    iIntros "!# % HC !>". iFrame "#∗".
  Qed.

  Lemma sem_typed_TApp_os Γ₁ Γ₂ (x : string) e ρ τ C :
    x ∉ env_dom Γ₂ → 
    Γ₁ ⊨ e : ⟨ρ,⟩ : (∀T: α , ⟨ρ,⟩ , C α) ⊨ Γ₂ -∗
    Γ₁ ⊨ e <_> : ⟨ρ,⟩ : C τ ⊨ Γ₂. 
  Proof.
    iIntros (?) "#He". 
    iApply sem_typed_TApp.

  Lemma sem_typed_TApp_os Γ₁ Γ₂ (x : string) e ρ τ C :
    x ∉ env_dom Γ₂ → 
    Γ₁ ⊨ e : ⟨ρ,⟩ : (∀T: α , ⟨ρ,⟩ , C α) ⊨ Γ₂ -∗
    Γ₁ ⊨ (let: x := e in x <_>) : ⟨ρ,⟩ : C τ ⊨ Γ₂. 
  Proof.
    iIntros (?) "#He". 
    iApply (sem_typed_let _ Γ₂); solve_sidecond.
    iApply sem_typed_swap_env_singl. rewrite - {3} (app_nil_r Γ₂).
    iApply sem_typed_frame_env_os. iApply sem_typed_TApp; solve_copy.
    iApply sem_typed_sub_nil. iApply sem_typed_var.
  Qed.

  (* Signature abstraction and application *)
  Lemma sem_typed_SLam Γ₁ Γ₂ e C : 
    (∀ θ, Γ₁ ⊨ e : θ : C θ ⊨ []) -∗
    Γ₁ ++ Γ₂ ⊨ (Λ: e) : ⟨⟩ : (∀S: θ , C θ)%T ⊨ Γ₂.
  Proof.
    iIntros "#He !# %vs HΓ₁₂ /=".
    iDestruct (env_sem_typed_app with "HΓ₁₂") as "[HΓ₁ HΓ₂]".
    ewp_pure_steps. iFrame.
    iIntros (ρs). ewp_pure_steps.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# % [$ _] //=".
  Qed.

  Lemma sem_typed_SApp Γ₁ Γ₂ e ρs C : 
    copy_env Γ₂ →
    Γ₁ ⊨ e : ρs : (∀S: θ , C θ) ⊨ Γ₂ -∗
    Γ₁ ⊨ e <_> : ρs : C ρs ⊨ Γ₂. 
  Proof.
    iIntros (Hcpy) "#He !# %vs HΓ₁ /=".
    iApply (ewp_bind [AppLCtx _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %v [HC HΓ₂] /= !>".
    rewrite {1}Hcpy. iDestruct "HΓ₂" as "#HΓ₂".
    iApply (ewp_pers_mono with "[HC]"); [iApply ("HC" $! ρs)|].
    iIntros "!# %w HCρ !>". iFrame "∗#".
  Qed.

  Lemma sem_typed_SApp_os Γ₁ Γ₂ (x : string) e ρ C :
    x ∉ env_dom Γ₂ → 
    Γ₁ ⊨ e : ⟨ρ,⟩ : (∀S: θ , C θ) ⊨ Γ₂ -∗
    Γ₁ ⊨ (let: x := e in x <_>) : ⟨ρ,⟩ : C ⟨ρ,⟩%R ⊨ Γ₂. 
  Proof.
    iIntros (?) "#He". 
    iApply (sem_typed_let _ Γ₂); solve_sidecond.
    iApply sem_typed_swap_env_singl. rewrite - {3} (app_nil_r Γ₂).
    iApply sem_typed_frame_env_os. iApply sem_typed_SApp; solve_copy.
    iApply sem_typed_sub_nil. iApply sem_typed_var.
  Qed.

  (* Existential type packing and unpacking *)
  Lemma sem_typed_pack Γ₁ Γ₂ ρs e C τ :
    Γ₁ ⊨ e : ρs : C τ ⊨ Γ₂ -∗
    Γ₁ ⊨ (pack: e) : ρs : (∃: α, C α) ⊨ Γ₂. 
  Proof.
    iIntros "#He %vs !# HΓ₁ //=".
    iApply (ewp_bind [AppRCtx _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %v [Hτv HΓ₂] //= !>".
    unfold exist_pack. ewp_pure_steps. iFrame.
    by iExists τ. 
  Qed.

  Lemma sem_typed_unpack Γ₁ Γ₂ Γ₃ x ρs e₁ e₂ κ C :
    x ∉ env_dom Γ₂ → x ∉ env_dom Γ₃ →
    Γ₁ ⊨ e₁ : ρs : (∃: α, C α) ⊨ Γ₂ -∗
    (∀ τ, (x, C τ) :: Γ₂ ⊨ e₂ : ρs : κ ⊨ Γ₃) -∗
    Γ₁ ⊨ (unpack: x := e₁ in e₂) : ρs : κ ⊨ Γ₃.
  Proof.
    iIntros (??) "#He₁ #He₂ %vs !# HΓ₁ //=".
    iApply (ewp_bind [AppRCtx _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He₁"|].
    iIntros "!# %w [(%τ & Hτw) HΓ₂] //= !>". unfold exist_unpack.
    ewp_pure_steps. rewrite -subst_map_insert.
    iApply (ewp_pers_mono with "[HΓ₂ Hτw]"); [iApply "He₂";solve_env|].
    iIntros "!# %u [Hκ HΓ₃]". solve_env.
  Qed.

  (* Recursive type rules *)
  Lemma sem_typed_fold Γ₁ Γ₂ e ρs C `{NonExpansive C}:
    Γ₁ ⊨ e : ρs : (C (μT: α, C α)) ⊨ Γ₂ -∗
    Γ₁ ⊨ (fold: e) : ρs : (μT: α, C α) ⊨ Γ₂.
  Proof.
    iIntros "#He %vs !# HΓ₁ //=".
    iApply (ewp_bind [AppRCtx _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %w [HC HΓ₂] //= !>".
    unfold rec_fold. ewp_pure_steps. 
    iFrame. by iApply sem_ty_rec_unfold. 
  Qed.

  Lemma sem_typed_unfold Γ₁ Γ₂ e ρs C `{NonExpansive C}:
    Γ₁ ⊨ e : ρs : (μT: α, C α) ⊨ Γ₂ -∗
    Γ₁ ⊨ (unfold: e) : ρs : (C (μT: α, C α)) ⊨ Γ₂.
  Proof.
    iIntros "#He %vs !# HΓ₁ //=".
    iApply (ewp_bind [AppRCtx _]); first done. 
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %w [Hμ HΓ₂] //= !>". 
    rewrite sem_ty_rec_unfold. 
    unfold rec_unfold. ewp_pure_steps. 
    iFrame.
  Qed.

  (* List type rules *)
  Lemma sem_typed_nil Γ τ: 
    ⊢ Γ ⊨ NIL : ⟨⟩ : List τ ⊨ Γ.
  Proof.
    iIntros "!# %vs HΓ //=". 
    ewp_pure_steps. unfold sem_ty_list. 
    rewrite sem_ty_rec_unfold. iIntros "{$HΓ} !>".
    unfold ListF. iExists #(). by iLeft.
  Qed.
  
  Lemma sem_typed_cons Γ₁ Γ₂ Γ₃ e₁ e₂ ρs τ:
    Γ₂ ⊨ e₁ : ⟨ρs.1,⟩ : τ ⊨ Γ₃-∗
    Γ₁ ⊨ e₂ : ρs : List τ ⊨ Γ₂-∗
    Γ₁ ⊨ CONS e₁ e₂ : ρs : List τ ⊨ Γ₃.
  Proof.
    iIntros "#He₁ #He₂ !# %vs HΓ₁ //=". 
    iApply (ewp_bind [InjRCtx; PairRCtx _]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He₂"|].
    iIntros "!# %l [Hl HΓ₂] //= !>".
    iApply (ewp_bind [InjRCtx; PairLCtx _]); first done.
    iApply ewp_ms_prot_mono; [iApply sig_le_nil|].
    iApply (ewp_mono with "[HΓ₂]"); [by iApply "He₁"|].
    iIntros "%x [Hx HΓ₃] //= !>". ewp_pure_steps.
    unfold sem_ty_list. rewrite !sem_ty_rec_unfold.
    iIntros "{$HΓ₃} !>". iExists (x,l)%V. iRight. iSplit; first done.
    iExists x, l. iFrame; iSplit; first done.
    by rewrite sem_ty_rec_unfold. 
  Qed.

  Lemma sem_typed_cons_ms Γ₁ Γ₂ Γ₃ (x₁ x₂ : string) e₁ e₂ ρs τ:
    x₂ ∉ env_dom Γ₂ → x₂ ∉ env_dom Γ₃ → x₁ ∉ env_dom Γ₃ → x₁ ≠ x₂ → 
    copy_ty τ →
    Γ₂ ⊨ e₁ : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : List τ ⊨ Γ₂-∗
    Γ₁ ⊨ (let: x₂ := e₂ in let: x₁ := e₁ in CONS x₁ x₂) : ρs : List τ ⊨ Γ₃.
  Proof.
    iIntros (???? Hcpy) "#He₁ #He₂".
    iApply (sem_typed_let _ Γ₂); solve_sidecond.
    iApply (sem_typed_let _ ((x₂, List τ) :: Γ₃)); solve_sidecond.
    { iApply sem_typed_frame_ms; first by apply copy_ty_list. iApply "He₁". }
    iApply sem_typed_sub_nil.
    iApply (sem_typed_cons _ ((x₁, τ) :: Γ₃)); [iApply sem_typed_var|].
    iApply sem_typed_swap_second.
    iApply sem_typed_var.
  Qed.

  Lemma sem_typed_match_list Γ₁ Γ₂ Γ₃ x xs e₁ e₂ e₃ ρs τ κ :
    x ∉ (env_dom Γ₂) -> xs ∉ (env_dom Γ₂) ->
    x ∉ (env_dom Γ₃) -> xs ∉ (env_dom Γ₃) ->
    x ≠ xs ->
    Γ₁ ⊨ e₁ : ρs : List τ ⊨ Γ₂ -∗
    Γ₂ ⊨ e₂ : ρs : κ ⊨ Γ₃ -∗
    (x, τ) :: (xs, List τ) :: Γ₂ ⊨ e₃ : ρs : κ ⊨ Γ₃ -∗
    Γ₁ ⊨ list-match: e₁ with 
            CONS x => xs => e₃ 
          | NIL => e₂
         end : ρs : κ ⊨ Γ₃.
  Proof.
    iIntros (?????) "#He₁ #He₂ #He₃ !# %vs HΓ₁ //=".
    iApply (ewp_bind [CaseCtx _ _]); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁]");
      [iApply (sem_typed_unfold with "He₁ HΓ₁")|].
    iIntros "!# %v₁ [Hl HΓ₂] !>". 
    iDestruct "Hl" as "(%v' & [[-> ->]|(-> & (%w₁ & %w₂ & -> & Hτ & Hμ))])"; 
    ewp_pure_steps.
    { iApply (ewp_pers_mono with "[HΓ₂]"); 
        [iApply ("He₂" with "[$HΓ₂]")|eauto]. }
    rewrite lookup_delete. simpl.
    rewrite decide_False; [|by intros [_ []]].
    rewrite decide_True; last done. ewp_pure_steps.
    rewrite decide_True; [|split; congruence].
    rewrite delete_commute -subst_map_insert delete_commute.
    rewrite insert_delete_insert. rewrite subst_map_insert.
    rewrite subst_subst_ne; [|congruence]. rewrite delete_commute.
    rewrite -subst_map_insert -delete_insert_ne; try congruence.
    rewrite -subst_map_insert. 
    iApply (ewp_pers_mono with "[Hμ Hτ HΓ₂]"); [iApply "He₃"; solve_env|].
    { rewrite env_sem_typed_insert; last done; solve_env. }
    iIntros "!# %u [Hκ HΓ₃]". iFrame.
    rewrite -(env_sem_typed_insert _ _ x w₁); last done.
    by rewrite -(env_sem_typed_insert _ _ xs w₂).
  Qed.

  (* Reference rules *)
  
  Lemma sem_typed_alloc Γ₁ Γ₂ e ρs τ: 
    Γ₁ ⊨ e : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ ref e : ρs : Ref τ ⊨ Γ₂.
  Proof.
    iIntros "#He !# %vs HΓ₁ //=".
    iApply (ewp_bind [AllocCtx]); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %v [Hτ HΓ₂] !>".
    iApply ewp_alloc. iIntros "!> %l Hl !>". solve_env.
  Qed.
  
  Lemma sem_typed_load Γ x τ: 
    ⊢ ((x, Ref τ) :: Γ ⊨ !x : ⟨⟩ : τ ⊨ (x, Ref Moved) :: Γ).
  Proof.
    iIntros "%vs !# //= [%v (%Hrw & (%w & -> & (%l & Hl & Hτ)) & HΓ)]".
    rewrite Hrw. iApply (ewp_load with "Hl").
    iIntros "!> Hl !>". solve_env.
  Qed.
  
  Lemma sem_typed_load_copy Γ x τ: 
    copy_ty τ →
    ⊢ ((x, Ref τ) :: Γ ⊨ !x : ⟨⟩ : τ ⊨ (x, Ref τ) :: Γ).
  Proof.
    iIntros (Hcpy) "%vs !# //= [%v (%Hrw & (%w & -> & (%l & Hl & Hτ)) & HΓ)]".
    rewrite Hrw. iApply (ewp_load with "Hl").
    rewrite {1}Hcpy. iDestruct "Hτ" as "#Hτ".
    iIntros "!> Hl !>". solve_env.
  Qed.

  Lemma sem_typed_store Γ₁ Γ₂ x e ρs τ κ ι: 
    (x, Ref τ) :: Γ₁ ⊨ e : ρs : ι ⊨ (x, Ref κ) :: Γ₂ -∗
    (x, Ref τ) :: Γ₁ ⊨ (x <- e) : ρs : () ⊨ (x, Ref ι) :: Γ₂.
  Proof.
    iIntros "#He !# %vs //= HΓ₁' //=".
    iApply (ewp_bind [StoreRCtx _]); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁']"); [iApply "He"; solve_env|].
    iIntros "!# %w [Hι [%v (%Hrw & (%l & -> & (% & Hl & Hκ)) & HΓ₂)]] /=". 
    rewrite Hrw. iApply (ewp_store with "Hl"). 
    iIntros "!> !> Hl !>". solve_env. 
  Qed.

  Lemma sem_typed_alloc_cpy Γ₁ Γ₂ e ρs τ: 
    Γ₁ ⊨ e : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ ref e : ρs : Refᶜ  τ ⊨ Γ₂.
  Proof.
    iIntros "#He !# %vs HΓ₁ //=".
    iApply (ewp_bind [AllocCtx]); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %v [Hτ HΓ₂] !>".
    iApply ewp_alloc. iIntros "!> %l Hl". iFrame.
    iMod (inv_alloc (tyN.@l) _
       (∃ w, l ↦ w ∗ τ w)%I with "[Hl Hτ]") as "#Hinv".
    { iExists v. by iFrame. }
    iModIntro. iExists l. by auto.
  Qed.

  Lemma sem_typed_load_cpy Γ₁ Γ₂ e ρs τ: 
    copy_ty τ →
    Γ₁ ⊨ e : ρs : Refᶜ τ ⊨ Γ₂ -∗
    Γ₁ ⊨ !e : ρs : τ ⊨ Γ₂.
  Proof.
    iIntros (Hcpy) "#He %vs !# //= HΓ₁".
    iApply (ewp_bind [LoadCtx]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %v [(%l & -> & Hinv) HΓ₂] /= !>".
    iApply (ewp_atomic _ (⊤ ∖ ↑tyN.@l)).
    iMod (inv_acc _ (tyN.@l) with "Hinv") as "[(%u & >Hl & Hτ) Hclose]"; first done.
    iModIntro. iApply (ewp_load with "Hl").
    iIntros "!> Hl !>". 
    rewrite {1}Hcpy. iDestruct "Hτ" as "#Hτ".
    iMod ("Hclose" with "[Hl]"); solve_env.
  Qed.

  Lemma sem_typed_store_cpy Γ₁ Γ₂ Γ₃ e₁ e₂ ρs τ: 
    copy_ty τ →
    Γ₂ ⊨ e₁ : ρs : Refᶜ τ ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ (e₁ <- e₂) : ρs : () ⊨ Γ₃.
  Proof.
    iIntros (Hcpy) "#He₁ #He₂ %vs !# /= HΓ₁ /=".
    iApply (ewp_bind [StoreRCtx _]); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He₂"|].
    iIntros "!# %w [Hτ HΓ₂] !>". 
    iApply (ewp_bind [StoreLCtx _]); first done. simpl.
    rewrite Hcpy. iDestruct "Hτ" as "#Hτ".
    iApply (ewp_pers_mono with "[HΓ₂]"); [by iApply "He₁"|].
    iIntros "!# %u [(%l & -> & Hinv) HΓ₃] !>".
    iApply (ewp_atomic _ (⊤ ∖ ↑tyN.@l)).
    iMod (inv_acc _ (tyN.@l) with "Hinv") as "[(%u & >Hl & _) Hclose]"; first done.
    iModIntro. iApply (ewp_store with "Hl"). 
    iIntros "!> Hl !>".  
    iMod ("Hclose" with "[Hl Hτ]"); solve_env.
  Qed.

  Lemma sem_typed_replace_cpy Γ₁ Γ₂ Γ₃ e₁ e₂ ρs τ: 
    Γ₂ ⊨ e₁ : ⟨ρs.1,⟩ : Refᶜ τ ⊨ Γ₃ -∗
    Γ₁ ⊨ e₂ : ρs : τ ⊨ Γ₂ -∗
    Γ₁ ⊨ (e₁ <!- e₂) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros "#He₁ #He₂ %vs !# /= HΓ₁ /=".
    iApply (ewp_bind [ReplaceRCtx _]); first done. simpl.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He₂"|].
    iIntros "!# %w [Hτ HΓ₂] !>". 
    iApply (ewp_bind [ReplaceLCtx _]); first done. simpl.
    iApply ewp_ms_prot_mono; [iApply sig_le_nil|].
    iApply (ewp_mono with "[HΓ₂]"); [by iApply "He₁"|].
    iIntros "%u [(%l & -> & Hinv) HΓ₃] !>".
    iApply (ewp_atomic _ (⊤ ∖ ↑tyN.@l)).
    iMod (inv_acc _ (tyN.@l) with "Hinv") as "[(%u & >Hl & Hu) Hclose]"; first done.
    iModIntro. iApply (ewp_replace with "Hl"). 
    iIntros "!> Hl !>".  
    iMod ("Hclose" with "[Hl Hτ]").
    { iExists w. iFrame. } 
    iIntros "!>". iFrame.
  Qed.
  
  (* Effect handling rules *)
  
  Lemma sem_typed_perform_os Γ₁ Γ₂ e τ ρ' (A B : sem_ty Σ → sem_sig Σ → sem_ty Σ) 
    `{ NonExpansive2 A, NonExpansive2 B } :
    let ρ := (∀μTS: θ, α, A α θ ⇒ B α θ)%R in
    Γ₁ ⊨ e : ⟨ρ, ρ'⟩ : A τ ρ ⊨ Γ₂ -∗
    Γ₁ ⊨ (perform: e) : ⟨ρ, ρ'⟩ : B τ ρ ⊨ Γ₂.
  Proof.
    iIntros (ρ) "#He !# %vs HΓ₁ //=". rewrite /rec_perform.
    iApply (ewp_bind [AppRCtx _; DoCtx OS; InjLCtx]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %v [Hι HΓ₂] //= !>". ewp_pure_steps.
    iApply ewp_do_os. rewrite upcl_sem_sig_rec_eff /=.
    iExists τ, v. iFrame. iSplitR; first done.
    iIntros (b) "Hκ". ewp_pure_steps. iFrame.
  Qed.

  Lemma sem_typed_perform_ms Γ₁ Γ₂ e τ ρ (A B : sem_ty Σ → sem_sig Σ → sem_ty Σ) 
    `{ NonExpansive2 A, NonExpansive2 B } :
    copy_env Γ₂ →
    let ρ' := (∀μTSₘ: θ, α, A α θ ⇒ B α θ)%R in
    Γ₁ ⊨ e : ⟨ρ, ρ'⟩ : A τ ρ' ⊨ Γ₂ -∗
    Γ₁ ⊨ (performₘ: e) : ⟨ρ, ρ'⟩ : B τ ρ' ⊨ Γ₂.
  Proof.
    iIntros (Hcpy ρ') "#He !# %vs HΓ₁ //=". rewrite /rec_perform.
    iApply (ewp_bind [AppRCtx _; DoCtx MS; InjRCtx]); first done.
    iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|].
    iIntros "!# %v [Hι HΓ₂] //= !>". ewp_pure_steps.
    iApply ewp_do_ms. rewrite upcl_sem_sig_rec_eff /=.
    iExists τ, v. iFrame. iSplitR; first done.
    rewrite {1}Hcpy. iDestruct "HΓ₂" as "#HΓ₂".
    iIntros "!# %b Hκ". ewp_pure_steps. iFrame "∗#".
  Qed.

  Lemma sem_typed_shallow_try Γ₁ Γ₂ Γ₃ Γ' w k e hos hms r A₁ B₁ A₂ B₂ τ τ' ρs 
        `{NonExpansive2 A₁, NonExpansive2 B₁, NonExpansive2 A₂, NonExpansive2 B₂}:
    w ∉ env_dom Γ₂ → w ∉ env_dom Γ' → k ∉ env_dom Γ' →
    w ∉ env_dom Γ₃ → k ∉ env_dom Γ₃ → w ≠ k →
    let ρ₁ := (∀μTS: θ, α, A₁ α θ ⇒ B₁ α θ)%R in
    let ρ₂ := (∀μTSₘ: θ, α, A₂ α θ ⇒ B₂ α θ)%R in
    Γ₁ ⊨ e : ⟨ρ₁, ρ₂⟩ : τ' ⊨ Γ₂ -∗
    (∀ α, (w, A₁ α ρ₁) :: (k, B₁ α ρ₁ -{ ⟨ρ₁, ρ₂⟩ }-∘ τ') :: Γ' ⊨ hos : ρs : τ ⊨ Γ₃) -∗
    (∀ α, (w, A₂ α ρ₂) :: (k, B₂ α ρ₂ -{ ⟨ρ₁, ρ₂⟩ }-> τ') :: Γ' ⊨ hms : ρs : τ ⊨ Γ₃) -∗
    (w, τ') :: Γ₂ ++ Γ' ⊨ r : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ++ Γ' ⊨ (shallow-try-dual: e
                  effect  (λ: w k, hos) 
                | effectₘ (λ: w k, hms) 
                | return  (λ: w, r) end) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros (??????) "%ρ₁ %ρ₂ #He #Hhos #Hhms #Hr !# %vs HΓ₁Γ' //=".
    iDestruct (env_sem_typed_app with "HΓ₁Γ'") as "[HΓ₁ HΓ']".
    iApply (ewp_try_with _ _ _ (λ v, τ' v ∗ ⟦ Γ₂ ⟧ vs)%I with "[HΓ₁] [HΓ']"). 
    { iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|eauto]. }
    iSplit; [|iSplit; iIntros (v c)].
    - iIntros (v) "[Hv HΓ₂] //=". ewp_pure_steps.
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[HΓ₂ HΓ' Hv]"); [iApply "Hr"|].
      { iExists v. rewrite env_sem_typed_app; solve_env. }
      iIntros "!# % [Hτ HΓ₃]"; solve_env.
    - rewrite upcl_sem_sig_rec_eff.
      iIntros "(%α & %a & <- & Ha & Hκb) //=". rewrite /select_on_sum. ewp_pure_steps.
      rewrite decide_True; [|split; first done; by injection].
      rewrite subst_subst_ne; last done.
      rewrite -subst_map_insert -delete_insert_ne; last done.
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[HΓ' Hκb Ha]"); [iApply "Hhos"; solve_env; iSplitR "HΓ'"|].
      + iIntros (b) "Hκ /=".
        iApply (ewp_pers_mono with "[Hκ Hκb]"); [by iApply "Hκb"|].
        iIntros "!# % [Hτ' _] !> //=".
      + by (do 2 (rewrite -env_sem_typed_insert; try done)).
      + iIntros "!# %u [$ HΓ₃] !>".
        rewrite -(env_sem_typed_insert _ _ w a); last done.
        by rewrite -(env_sem_typed_insert _ _ k c).
    - rewrite upcl_sem_sig_rec_eff.
      iIntros "(%α & %a & <- & Ha & Hκb) //=". rewrite /select_on_sum. ewp_pure_steps.
      rewrite decide_True; [|split; first done; by injection].
      rewrite subst_subst_ne; last done.
      rewrite -subst_map_insert -delete_insert_ne; last done.
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[HΓ' Hκb Ha]"); [iApply "Hhms"; solve_env|].
      + iDestruct "Hκb" as "#Hκb".
        iIntros "!# %b Hκ /=".
        iApply (ewp_pers_mono with "[Hκ]"); [by iApply "Hκb"|].
        iIntros "!# % [Hτ' _] !> //=".
      + by (do 2 (rewrite -env_sem_typed_insert; try done)).
      + iIntros "!# %u [$ HΓ₃] !>".
        rewrite -(env_sem_typed_insert _ _ w a); last done.
        by rewrite -(env_sem_typed_insert _ _ k c).
  Qed.
  
  Lemma sem_typed_shallow_try_os Γ₁ Γ₂ Γ₃ Γ' w k e h r A B τ τ' ρs `{NonExpansive2 A, NonExpansive2 B }:
    w ∉ env_dom Γ₂ → w ∉ env_dom Γ' → k ∉ env_dom Γ' →
    w ∉ env_dom Γ₃ → k ∉ env_dom Γ₃ → w ≠ k →
    let ρ := (∀μTS: θ, α, A α θ ⇒ B α θ)%R in
    Γ₁ ⊨ e : ⟨ρ,⟩ : τ' ⊨ Γ₂ -∗
    (∀ α, (w, A α ρ) :: (k, B α ρ -{ ⟨ρ, ∀μTSₘ: θ, α, ⊥ ⇒ ⊥⟩ }-∘ τ') :: Γ' ⊨ h : ρs : τ ⊨ Γ₃) -∗
    (w, τ') :: Γ₂ ++ Γ' ⊨ r : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ++ Γ' ⊨ (shallow-try-dual: e
                  effect  (λ: w k, h) 
                | effectₘ (λ: w k, w) 
                | return  (λ: w, r) end) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros (??????) "%ρ #He #Hh #Hr".
    set Bot := (λ (_ : sem_ty Σ) (_ : sem_sig Σ), @sem_ty_void Σ).
    iApply (sem_typed_shallow_try _ Γ₂ _ _ _ _ _ _ _ _ A B Bot Bot with "[] [Hh] [] [Hr]"); try assumption.
    - iApply sem_typed_sub_sig; [|iApply "He"]. rewrite /ρ.
      apply sigs_le_comp; [apply sig_le_refl|apply sig_le_nil].
    - simpl. rewrite /ρ. iIntros (α). iApply ("Hh" $! α).
    - iIntros (α). rewrite /Bot /=. 
      iApply sem_typed_sub_nil. iApply sem_typed_bot_in_env.
    - iApply "Hr".
  Qed.

  Lemma sem_typed_shallow_try_ms Γ₁ Γ₂ Γ₃ Γ' w k e h r A B τ τ' ρs `{NonExpansive2 A, NonExpansive2 B }:
    w ∉ env_dom Γ₂ → w ∉ env_dom Γ' → k ∉ env_dom Γ' →
    w ∉ env_dom Γ₃ → k ∉ env_dom Γ₃ → w ≠ k →
    let ρ := (∀μTSₘ: θ, α, A α θ ⇒ B α θ)%R in
    Γ₁ ⊨ e : ⟨,ρ⟩ : τ' ⊨ Γ₂ -∗
    (∀ α, (w, A α ρ) :: (k, B α ρ -{ ⟨∀μTS: θ, α, ⊥ ⇒ ⊥, ρ⟩ }-> τ') :: Γ' ⊨ h : ρs : τ ⊨ Γ₃) -∗
    (w, τ') :: Γ₂ ++ Γ' ⊨ r : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ++ Γ' ⊨ (shallow-try-dual: e
                  effect  (λ: w k, w) 
                | effectₘ (λ: w k, h) 
                | return  (λ: w, r) end) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros (??????) "%ρ #He #Hh #Hr".
    set Bot := (λ (_ : sem_ty Σ) (_ : sem_sig Σ), @sem_ty_void Σ).
    iApply (sem_typed_shallow_try _ Γ₂ _ _ _ _ _ _ _ _ Bot Bot A B with "[] [Hh] [] [Hr]"); try assumption.
    - iApply sem_typed_sub_sig; [|iApply "He"]. rewrite /ρ.
      apply sigs_le_comp; [apply sig_le_nil|apply sig_le_refl].
    - iIntros (α). rewrite /Bot /=. 
      iApply sem_typed_sub_nil. iApply sem_typed_bot_in_env.
    - simpl. rewrite /ρ. iIntros (α). iApply ("Hh" $! α).
    - iApply "Hr".
  Qed.

  Lemma sem_typed_deep_try Γ₁ Γ₂ Γ₃ Γ' w k e hos hms r A₁ B₁ A₂ B₂ τ τ' ρs 
        `{NonExpansive2 A₁, NonExpansive2 B₁, NonExpansive2 A₂, NonExpansive2 B₂}:
    w ∉ env_dom Γ₂ → w ∉ env_dom Γ' → k ∉ env_dom Γ' →
    w ∉ env_dom Γ₃ → k ∉ env_dom Γ₃ → w ≠ k → copy_env Γ' →
    let ρ₁ := (∀μTS: θ, α, A₁ α θ ⇒ B₁ α θ)%R in
    let ρ₂ := (∀μTSₘ: θ, α, A₂ α θ ⇒ B₂ α θ)%R in
    Γ₁ ⊨ e : ⟨ρ₁, ρ₂⟩ : τ' ⊨ Γ₂ -∗
    (∀ α, (w, A₁ α ρ₁) :: (k, B₁ α ρ₁ -{ ρs }-∘ τ) :: Γ' ⊨ hos : ρs : τ ⊨ Γ₃) -∗
    (∀ α, (w, A₂ α ρ₂) :: (k, B₂ α ρ₂ -{ ρs }-> τ) :: Γ' ⊨ hms : ρs : τ ⊨ Γ₃) -∗
    (w, τ') :: Γ₂ ++ Γ' ⊨ r : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ++ Γ' ⊨ (deep-try-dual: e
                  effect  (λ: w k, hos) 
                | effectₘ (λ: w k, hms) 
                | return  (λ: w, r) end) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros (?????? Hcpy) "%ρ₁ %ρ₂ #He #Hhos #Hhms #Hr !# %vs HΓ₁Γ' //=".
    iDestruct (env_sem_typed_app with "HΓ₁Γ'") as "[HΓ₁ HΓ']".
    rewrite Hcpy. iDestruct "HΓ'" as "#HΓ'".
    rewrite /select_on_sum. ewp_pure_steps. 
    iApply (ewp_deep_try_with _ _ _ (λ v, τ' v ∗ env_sem_typed Γ₂ vs) with "[HΓ₁] []").
    { iApply (ewp_pers_mono with "[HΓ₁]"); [by iApply "He"|eauto]. }
    iLöb as "IH". rewrite {2}deep_handler_unfold.
    iSplit; [|iSplit; iIntros (v c)].
    - iIntros (v) "[Hv HΓ₂] //=". ewp_pure_steps.
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[HΓ₂ HΓ' Hv]"); [iApply "Hr"|].
      { iExists v. rewrite env_sem_typed_app; solve_env. }
      iIntros "!# % [Hτ HΓ₃]"; solve_env.
    - rewrite upcl_sem_sig_rec_eff.
      iIntros "(%α & %a & <- & Ha & Hκb) //=". ewp_pure_steps.
      rewrite decide_True; [|split; first done; by injection].
      rewrite subst_subst_ne; last done.
      rewrite -subst_map_insert -delete_insert_ne; last done.
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[HΓ' Hκb Ha]"); [iApply "Hhos"; solve_env; iSplitR "HΓ'"|].
      + iIntros (b) "Hκ /=".
        iApply (ewp_pers_mono with "[Hκ Hκb]"); [iApply ("Hκb" with "Hκ IH")|].
        iIntros "!# % [Hτ' _] !> //=".
      + by (do 2 (rewrite -env_sem_typed_insert; try done)).
      + iIntros "!# %u [$ HΓ₃] !>".
        rewrite -(env_sem_typed_insert _ _ w a); last done.
        by rewrite -(env_sem_typed_insert _ _ k c).
    - rewrite upcl_sem_sig_rec_eff.
      iIntros "(%α & %a & <- & Ha & Hκb) //=". ewp_pure_steps.
      rewrite decide_True; [|split; first done; by injection].
      rewrite subst_subst_ne; last done.
      rewrite -subst_map_insert -delete_insert_ne; last done.
      rewrite -subst_map_insert.
      iApply (ewp_pers_mono with "[HΓ' Hκb Ha]"); [iApply "Hhms"; solve_env|].
      + iDestruct "Hκb" as "#Hκb".
        iIntros "!# %b Hκ /=".
        iApply (ewp_pers_mono with "[Hκ]"); [iApply ("Hκb" with "Hκ IH")|].
        iIntros "!# % [Hτ' _] !> //=".
      + by (do 2 (rewrite -env_sem_typed_insert; try done)).
      + iIntros "!# %u [$ HΓ₃] !>".
        rewrite -(env_sem_typed_insert _ _ w a); last done.
        by rewrite -(env_sem_typed_insert _ _ k c).
  Qed.

  Lemma sem_typed_deep_try_os Γ₁ Γ₂ Γ₃ Γ' w k e h r A B τ τ' ρs `{NonExpansive2 A, NonExpansive2 B }:
    w ∉ env_dom Γ₂ → w ∉ env_dom Γ' → k ∉ env_dom Γ' →
    w ∉ env_dom Γ₃ → k ∉ env_dom Γ₃ → w ≠ k → copy_env Γ' →
    let ρ := (∀μTS: θ, α, A α θ ⇒ B α θ)%R in
    Γ₁ ⊨ e : ⟨ρ,⟩ : τ' ⊨ Γ₂ -∗
    (∀ α, (w, A α ρ) :: (k, B α ρ -{ ρs }-∘ τ) :: Γ' ⊨ h : ρs : τ ⊨ Γ₃) -∗
    (w, τ') :: Γ₂ ++ Γ' ⊨ r : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ++ Γ' ⊨ (deep-try-dual: e
                  effect  (λ: w k, h) 
                | effectₘ (λ: w k, w) 
                | return  (λ: w, r) end) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros (???????) "%ρ #He #Hh #Hr".
    set Bot := (λ (_ : sem_ty Σ) (_ : sem_sig Σ), @sem_ty_void Σ).
    iApply (sem_typed_deep_try _ Γ₂ _ _ _ _ _ _ _ _ A B Bot Bot with "[] [Hh] [] [Hr]"); try assumption.
    - iApply sem_typed_sub_sig; [|iApply "He"]. rewrite /ρ.
      apply sigs_le_comp; [apply sig_le_refl|apply sig_le_nil].
    - simpl. rewrite /ρ. iIntros (α).
      iApply sem_typed_sub_env; [|iApply "Hh"].
      apply env_le_cons; [|apply ty_le_refl].
      apply env_le_cons; [apply env_le_refl|].
      apply ty_le_aarr; [|apply ty_le_refl|apply ty_le_refl].
      apply sigs_le_refl.
    - iIntros (α). rewrite /Bot /=. 
      iApply sem_typed_sub_nil. iApply sem_typed_bot_in_env.
    - iApply "Hr".
  Qed.

  Lemma sem_typed_deep_try_ms Γ₁ Γ₂ Γ₃ Γ' w k e h r A B τ τ' ρs `{NonExpansive2 A, NonExpansive2 B }:
    w ∉ env_dom Γ₂ → w ∉ env_dom Γ' → k ∉ env_dom Γ' →
    w ∉ env_dom Γ₃ → k ∉ env_dom Γ₃ → w ≠ k → copy_env Γ' →
    let ρ := (∀μTSₘ: θ, α, A α θ ⇒ B α θ)%R in
    Γ₁ ⊨ e : ⟨,ρ⟩ : τ' ⊨ Γ₂ -∗
    (∀ α, (w, A α ρ) :: (k, B α ρ -{ ρs }-> τ) :: Γ' ⊨ h : ρs : τ ⊨ Γ₃) -∗
    (w, τ') :: Γ₂ ++ Γ' ⊨ r : ρs : τ ⊨ Γ₃ -∗
    Γ₁ ++ Γ' ⊨ (deep-try-dual: e
                  effect  (λ: w k, w) 
                | effectₘ (λ: w k, h) 
                | return  (λ: w, r) end) : ρs : τ ⊨ Γ₃.
  Proof.
    iIntros (???????) "%ρ #He #Hh #Hr".
    set Bot := (λ (_ : sem_ty Σ) (_ : sem_sig Σ), @sem_ty_void Σ).
    iApply (sem_typed_deep_try _ Γ₂ _ _ _ _ _ _ _ _ Bot Bot A B with "[] [Hh] [] [Hr]"); try assumption.
    - iApply sem_typed_sub_sig; [|iApply "He"]. rewrite /ρ.
      apply sigs_le_comp; [apply sig_le_nil|apply sig_le_refl].
    - iIntros (α). rewrite /Bot /=. 
      iApply sem_typed_sub_nil. iApply sem_typed_bot_in_env.
    - simpl. rewrite /ρ. iIntros (α).
      iApply sem_typed_sub_env; [|iApply "Hh"].
      apply env_le_cons; [|apply ty_le_refl].
      apply env_le_cons; [apply env_le_refl|].
      apply ty_le_uarr; [|apply ty_le_refl|apply ty_le_refl].
      apply sigs_le_refl.
    - iApply "Hr".
  Qed.

End compatibility.
