import Lean.Data.HashMap
import Mrs.Basic
import Mrs.Hof
import Util.InsertionSort

namespace SMT2

open Lean (HashMap)
open MRS (Var EP Constraint MRS)
open HOF
open MM
open InsertionSort

def libraryRoutines : String :=
  "; Library routines\n" ++
  "(declare-fun a_q (Pred Pred) Bool)\n" ++
  "(declare-fun every_q (Pred Pred) Bool)\n" ++
  "(declare-fun some_q (Pred Pred) Bool)\n" ++
  "(declare-fun the_q (Pred Pred) Bool)\n" ++
  "(declare-fun proper_q (Pred Pred) Bool)\n" ++
  "(declare-fun pronoun_q (Pred Pred) Bool)\n" ++
  "(declare-fun udef_q (Pred Pred) Bool)\n" ++
  "(declare-fun def_explicit_q (Pred Pred) Bool)\n" ++
  "(declare-fun no_q (Pred Pred) Bool)\n" ++
  "(declare-fun never_a_1 (Bool) Bool)\n" ++
  "(declare-fun neg (Event Bool) Bool)\n" ++
  "(declare-fun colon_p_namely (Event Bool Bool) Bool)\n" ++
  "(declare-fun therein_p_dir (Event Event) Bool)\n" ++
  "(declare-fun live_v_1 (Event Entity) Bool)\n" ++
  "(declare-fun people_n_of (Entity) Bool)\n" ++
  "(declare-fun victim_n_of (Entity) Bool)\n" ++
  "(declare-fun only_a_1 (Event Entity) Bool)\n" ++
  "(declare-fun named (Entity String) Bool)\n" ++
  "(declare-fun and_c_x (Entity Entity Entity) Bool)\n" ++
  "(declare-fun and_c_e (Event Event Event) Bool)\n" ++
  "(declare-fun butler_n_1 (Entity) Bool)\n" ++
  "(declare-fun killer_n_1 (Entity) Bool)\n" ++
  "(declare-fun implicit_conj (Entity Entity Entity) Bool)\n" ++
  "(declare-fun be_v_id (Event Entity Entity) Bool)\n" ++
  "(declare-fun in_p_loc (Event Event Entity) Bool)\n" ++
  "(declare-fun compound (Event Entity Entity) Bool)\n" ++
  "(declare-fun person (Entity) Bool)\n" ++
  "(declare-fun kill_v_1 (Event Entity Entity) Bool)\n" ++
  "(declare-fun hate_v_1 (Event Entity Entity) Bool)\n" ++
  "(declare-fun pron (Entity) Bool)\n" ++
  "(declare-fun poss (Event Entity Entity) Bool)\n" ++
  "(declare-fun more_comp (Event Event Entity) Bool)\n" ++
  "(declare-fun rich_a_in (Event Entity) Bool)\n" ++
  "(declare-fun always_a_1 (Event) Bool)\n" ++
  "(declare-fun aunt_n_of (Entity) Bool)\n" ++
  "(declare-fun card (Event Entity String) Bool)\n" ++
  "(declare-fun generic_entity (Entity) Bool)\n" ++
  "(declare-fun except_p (Event Entity Entity) Bool)\n" ++
  "(declare-fun therefore_a_1 (Bool) Bool)\n" ++
  "(declare-fun unknown (Event) Bool)\n"

def removeQuotes (s : String) : String :=
  if s.startsWith "\"" && s.endsWith "\"" then s.extract ⟨1⟩ ⟨s.length - 1⟩ else s

def formatId (s : String) : String :=
  let str := removeQuotes s
  s!"id_{str}"

def fixName (ep : EP) : String :=
  let checkEonly (ep : EP) : Bool :=
    let ret2 := ep.rargs.filter (fun item => item.2.sort == 'e')
    (ret2.length == ep.rargs.length)
  let selectAndForm (ep : EP) : String :=
    if (checkEonly ep) then "_and_c_e" else "_and_c_x"
  let PredName := if ep.predicate == "_and_c" then selectAndForm ep else ep.predicate
  match (PredName.get? 0) with
    | '_' => PredName.drop 1
    | _ => PredName

def joinSep (l : List String) (sep : String) : String := l.foldr (fun s r => (if r == "" then s else r ++ sep ++ s)) ""

def Var.format.typeOnly (var : Var) : String :=
  match var.sort with
  | 'e' => "Event"
  | 'x' => "Entity"
  | 'h' => s!"Handle"
  | _ => "Bool"

def Var.format.labelOnly (sentenceNumber : Nat) (var : Var) : String :=
  if var.sort == 'x' then
    s!"S{sentenceNumber}_{var.sort.toUpper}{var.id}"
  else
    s!"s{sentenceNumber}_{var.sort}{var.id}"

def Var.format.labelOnlyGround (sentenceNumber : Nat) (var : Var) : String :=
  s!"s{sentenceNumber}_{var.sort}{var.id}"

def Var.format.pair (sentenceNumber : Nat) (var : Var) : String :=
  s!"({Var.format.labelOnly sentenceNumber var} {Var.format.typeOnly var})"

def Var.format.labelWithDeps (sentenceNumber : Nat) (ep : EP) (var : Var) (qm : HashMap Var Var) (em : Multimap Var Var) : String :=
  let defaultExpr := Var.format.labelOnly sentenceNumber var
  match qm.find? var with
  | some iterVar => 
    match (em.find? var) with
    | some extraList => 
      let l := extraList.filter (fun evar => iterVar != evar)
      let l1 := (insertionSort l).eraseDups
      let l2 := l1.map (fun item => Var.format.labelOnly sentenceNumber item)
      let l2str := joinSep l2 " "
      let lab := Var.format.labelOnlyGround sentenceNumber var
      if l2str == "" then lab else s!"(apply {lab} {l2str})"
    | none => defaultExpr
  | none =>
    match (em.find? var) with
    | some extraList => 
      let l := (insertionSort extraList).eraseDups
      s!"(apply {Var.format.labelOnlyGround sentenceNumber var} {joinSep (l.map (fun item => Var.format.labelOnly sentenceNumber item)) " "})"
    | none => defaultExpr

def EP.format.type (sentenceNumber : Nat) (qm : HashMap Var Var) (em : Multimap Var Var) (hm : Multimap Var EP) (rootHandle : Var) (handle : Var) : String :=
  let preds := match (hm.find? handle) with
  | some value => value
  | none => []

  let firstEp := match preds.head? with
  | some value => value
  | none => 
    dbg_trace "firstEP"; sorry

  let getArgs (ep : EP) : List (String × Var) :=
    let ret1 := ep.rargs
    let ret2 := ret1.filter (fun item => item.2.sort == 'x' || item.2.sort == 'h' || item.2.sort == 'e') 
    ret2

  let extraArgs (qm : HashMap Var Var) (labelVar : Var) : String := 
    match (em.find? labelVar) with
    | some value => 
      let l := match (qm.find? labelVar) with
               | some larg => value.filter (fun arg => arg != larg)
               | none => value
      let ls : List Var := (insertionSort l).eraseDups
      let estr : String := (joinSep (ls.map (fun var => Var.format.typeOnly var)) " ")
      estr
    | none => ""

  let printNormal (l : Var) (preds : List EP) : String :=
    let lookupArg (labelVar : Var) : String :=
      match (qm.find? labelVar) with
      | some value => Var.format.typeOnly value
      | none => ""
    let joinArgs0 (ep : EP) := joinSep ((getArgs ep).map fun a => Var.format.typeOnly a.2)  " "
    let joinArgs (ep : EP) := 
      match ep.carg with
      | some str => joinArgs0 ep ++ " String"
      | none => joinArgs0 ep
    let lstr := lookupArg l
    let estr := extraArgs qm l
    let combined := estr ++ (if lstr == "" then "" else (if estr == "" then "" else " ") ++ lstr)
    let lab := if handle == rootHandle then s!"s{sentenceNumber}_root" else Var.format.labelOnlyGround sentenceNumber handle
    s!"(declare-fun {lab} ({combined}) Bool)"

  printNormal firstEp.label preds

def EP.format.defn (sentenceNumber : Nat) (qm : HashMap Var Var) (em : Multimap Var Var) (hm : Multimap Var EP) (rootHandle : Var) (handle : Var) : String :=
  let preds := match (hm.find? handle) with
  | some value => value
  | none => []

  let firstEp := match preds.head? with
  | some value => value
  | none => 
    dbg_trace "firstEP"; sorry

  let getArgs (ep : EP) : List (String × Var) :=
    let ret1 := ep.rargs
    let ret2 := ret1.filter (fun item => item.2.sort == 'x' || item.2.sort == 'h' || item.2.sort == 'e') 
    ret2

  let extraArgs (qm : HashMap Var Var) (labelVar : Var) : String := 
    match (em.find? labelVar) with
    | some value => 
      let l := match (qm.find? labelVar) with
               | some larg => value.filter (fun arg => arg != larg)
               | none => value
      let ls : List Var := (insertionSort l).eraseDups
      let estr : String := (joinSep (ls.map (fun var => Var.format.pair sentenceNumber var)) " ")
      estr
    | none => ""

  let printNormal (l : Var) (preds : List EP) : String :=
    let lookupArg (labelVar : Var) : String :=
      match (qm.find? labelVar) with
      | some value => Var.format.pair sentenceNumber value
      | none => ""
    let joinArgs0 (ep : EP) := joinSep ((getArgs ep).map fun a => Var.format.labelWithDeps sentenceNumber ep a.2 qm em)  " "
    let joinArgs (ep : EP) := 
      match ep.carg with
      | some str => joinArgs0 ep ++ s!" \"{str}\""
      | none => joinArgs0 ep
    let lstr := lookupArg l
    let estr := extraArgs qm l
    let combined := estr ++ (if lstr == "" then "" else (if estr == "" then "" else " ") ++ lstr)
    let allCalls := preds.foldl (fun acc ep => (acc.1 ++ acc.2 ++ s!"({fixName ep} {joinArgs ep})"," ")) ("","")
    let lab := if handle == rootHandle then s!"s{sentenceNumber}_root" else Var.format.labelOnlyGround sentenceNumber handle
    if combined == "" then
      s!"(assert (= {lab} {allCalls.1}))"
    else
      s!"(assert (forall ({combined}) (= ({lab} {combined}) {allCalls.1})))"

  printNormal firstEp.label preds

def MRS.format (sentenceNumber : Nat) (mrs : MRS.MRS) : (String × List String × List Var) :=
 let strings := mrs.preds.foldl (fun stab pred =>
  match pred with
  | {predicate := p, link := some (n,m), label := l, rargs := rs, carg := some c} =>
    stab.insert c l
  | {predicate := p, link := some (n,m), label := l, rargs := rs, carg := none} =>
    stab
  | {predicate := p, link := none, label := l, rargs := rs, carg := some c} =>
    stab.insert c l
  | {predicate := p, link := none, label := l, rargs := rs, carg := none} =>
    stab) Multimap.empty
 let eSet := collectEvents mrs.preds 
 let qm := collectQuantifierVars mrs.preds
 let em := collectHOExtraVarsForEPs mrs.preds $
           collectHOExtraVarsForEPs mrs.preds $
           collectHOExtraVarsForEPs mrs.preds $
           collectHOExtraVarsForEPs mrs.preds $ collectExtraVarsForEPs mrs.preds qm
 let hm := collectEPsByHandle mrs.preds
 let rlt := hm.keys.map (EP.format.type sentenceNumber qm em hm mrs.top) 
 let rla := hm.keys.map (EP.format.defn sentenceNumber qm em hm mrs.top) 
 
 -- Generate root axioms
 let rootAxioms := hm.keys.map (fun handle =>
   let preds := match (hm.find? handle) with
   | some value => value
   | none => []
   let firstEp := match preds.head? with
   | some value => value
   | none => dbg_trace "firstEP"; sorry
   let getArgs (ep : EP) : List (String × Var) :=
     let ret1 := ep.rargs
     let ret2 := ret1.filter (fun item => item.2.sort == 'x' || item.2.sort == 'h' || item.2.sort == 'e') 
     ret2
   let args := getArgs firstEp
   let argDecls := args.map (fun (_, var) => Var.format.pair sentenceNumber var)
   let argNames := args.map (fun (_, var) => Var.format.labelOnly sentenceNumber var)
   let lab := if handle == mrs.top then s!"s{sentenceNumber}_root" else Var.format.labelOnlyGround sentenceNumber handle
   s!"(assert (exists ({joinSep argDecls " "}) ({lab} {joinSep argNames " "})))")

 let etypes := (joinSep (eSet.map (fun (var : Var) => s!"(declare-const s{sentenceNumber}_{var.sort}{var.id} Event)")) "\n")
 let str := libraryRoutines ++ "\n" ++ etypes ++ "\n\n" ++ (joinSep rlt "\n") ++ "\n\n" ++ (joinSep rla "\n") ++ "\n\n" ++ (joinSep rootAxioms "\n")
 (str, strings.keys, eSet)

end SMT2


