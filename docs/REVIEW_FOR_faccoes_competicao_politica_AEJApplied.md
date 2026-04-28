# Comprehensive Review — Armed Factions and Local Electoral Competition

**Paper:** Armed Factions and Local Electoral Competition: Evidence from Metropolitan Rio de Janeiro
**Authors:** Valdemar Pinho Neto (EPGE/FGV) + Victor Rangel (Insper)
**Date:** April 16, 2026 (manuscript) / April 18, 2026 (review)
**Advisor / Reviewer:** Pedro H. C. Santanna
**Target journal:** AEJ: Applied Economics (AEJApplied)
**Manuscript reviewed:** `papers/faccoes_e_competicao_politica.pdf` (11 pp + 3 pp appendix)
**Pipeline used:** simulated AEJApplied peer-review (editor desk + 2 dispositioned referees + editorial decision) + 7-lens parallel review (abstract, intro, methods, results, robustness, prose, citations) + advisor synthesis.

---

## How to read this document

This is one merged file containing **14 underlying reports synthesized into a single package**, calibrated to **AEJ: Applied Economics**. The structure is from highest-level (most actionable) to deepest-detail.

Recommended reading path:

1. **Part I — Master synthesis** (advisor voice; if you read only one section, read this one)
2. **Part II — Editorial decision** (verdict, concern table, prioritized deliverables)
3. **Part IV — Seven-pass synthesis** (unified tiered checklist, shared across all 4 journal reviews)
4. **Part III — Referee reports** (full scoring; verify specific concerns)
5. **Part V — Section-by-section deep dives** (consult when revising that section)
6. **Appendix** (configuration)

---

## Table of contents

- Part I — Master Synthesis
- Part II — Editorial Verdict (desk review + editorial decision)
- Part III — Full Referee Reports (Ref A + Ref B)
- Part IV — Seven-Pass Synthesis
- Part V — Section-by-Section Deep Dives (7 lens reports)
- Appendix — Configuration

===========================================================================
# PART I — MASTER SYNTHESIS (READ THIS FIRST)
===========================================================================

# Master Synthesis — *Armed Factions and Local Electoral Competition*

**Target journal:** American Economic Journal: Applied Economics (AEJ:Applied)
**Advisor:** Pedro H. C. Sant'Anna
**Authors:** Pinho Neto & Rangel (April 2026)
**Date:** 2026-04-18
**Package:** Part I of the 14-report master review

---

## 1. The verdict in one sentence

You have an AEJ:Applied-eligible paper buried inside an 11-page manuscript that was not calibrated to AEJ:Applied — and the path from current draft to submittable is mechanical, not heroic.

Let me say what I mean by that. The design is clever: staggered Callaway-Sant'Anna on annual Fogo Cruzado territory polygons, polling-station-by-polling-station, with a within-faction-type NYT comparison that correctly avoids the "never-inside-any-territory" control trap. The militia-vs-drug contrast is the right question, the institutional story in §2 is careful, and the headline militia/prefeito result is substantively plausible. Both referees — one calibrated to CREDIBILITY (69.4/100), one to POLICY (69.4/100) — arrived independently at Major Revision, with zero FATAL concerns, twelve ADDRESSABLE items, and three TASTE items. The editorial letter is explicit: this paper CAN land at AEJ:Applied with a focused 2-3 month revision that addresses every ADDRESSABLE item. It is not at JOP-reach distance; it is at AEJ:Applied-natural-fit distance.

What is missing, and what this synthesis tells you how to fix, is a twelve-item list of standard 2026-era applied-micro hygiene: event-study plots, Honest-DiD sensitivity, a cross-estimator, a clustering statement, an identification sentence stated formally, magnitude-to-policy translation, a replication package, removal of significance stars, an external-validity paragraph, a proper literature positioning against Pantaleão-Montini 2025, a balance table, and a sample-construction appendix. None of these is new data. None requires a redesign. Most are single R scripts against data you already have. What they collectively require is one quarter of your time and the discipline of writing AEJ:Applied-house-style instead of field-journal-short-note style.

I am not sugar-coating this. The paper as written would get a desk-rejection at QJE (and the seven-pass lenses, calibrated there, tell you exactly why — weak abstract, missing contribution paragraph, 11 pages of text, no Honest-DiD, no cross-estimator). But you are not submitting to QJE. You are submitting to AEJ:Applied, where the bar is **clean design + policy-relevant magnitudes + AEA-compliant replication**, and on three of those the path is mechanical. Let me walk you through it.

One more framing point before I dive in. The peer-review package you are holding contains 13 underlying reports: a desk review, two blind referee reports calibrated to AEJ:Applied's referee-pool weights (CREDIBILITY 0.40 + POLICY 0.20 as the two highest-weight dispositions), an editorial decision letter, and seven parallel lens reports (abstract, intro, methods, results, robustness, prose, citations) plus a seven-pass synthesis. Reading the whole package back-to-back is what a good co-author does for you before submission. My job in this master synthesis is to compress that reading into a prioritized execution plan. I will tell you what converges across reports (and therefore is not a minority view), what diverges (and therefore requires an editor-judgment call), and what the sequence of work should be. Sections 4 and 5 of this document are the actionable plan; Sections 7 through 9 are the operational detail. If you only have fifteen minutes, read Sections 1, 4, 5, and 11 — the rest is support.

---

## 2. What this paper actually has

Before I tell you what is missing, let me inventory what is real. This matters because the revision should not blur what is already a contribution into "everything needs work."

**A genuinely novel treatment definition.** Nobody has used annual Fogo Cruzado territory polygons as staggered treatment for electoral outcomes at the polling-station level. The closest cousins — Pantaleão & Montini 2025 (LAPS), Hidalgo et al. 2025 — run at the municipality level and identify the arrow *from* elections *to* militia expansion. Your arrow runs the other way, and your unit of analysis is two orders of magnitude finer. This is the single most defensible novelty claim the paper has. Refs A and B both acknowledge it; desk review flags it as "likely clear."

**A clean NYT-within-faction-type design.** The decision to use not-yet-treated stations *of the same faction type* as the comparison — rather than never-treated stations pooled across faction types — is methodologically disciplined. You correctly identified that NT = outside-any-territory stations are on a different electoral trajectory from inside-territory stations (the NT pre-trends failure at p < 0.001 is empirical evidence of exactly this), and you switched to NYT. Many applied papers in this literature do not make this distinction. Ref A flags this under the constructive-peeve lens; Lens 3 (Methods, 5.5/10) gives you direct credit for "the correct instinct on NYT vs NT controls." Keep this; defend it more vocally in the methods section.

**A headline that is substantively meaningful.** Militia/prefeito ATTs under NYT: HHI +0.052, ENC −0.459, margin +6.2 pp, all three passing Wald pre-trends (brackets 0.210, 0.211, 0.314 — Table 1). These are not small effects: a 0.46 drop in the effective number of candidates is a 12-18% reduction off a Brazilian prefeito baseline of 2.5-4; a 6.2 pp widening of margin is a 25-40% increase off a baseline of 15-25 pp. You do not currently report the baselines, which is a problem (see §3 below), but when you do, the magnitudes will sell themselves.

**An honest drug-faction null.** You did not chase the drug-faction result through specification searching. You reported HHI −0.003, ENC +0.100, margin +0.004 cleanly and interpreted the null substantively. Ref B credits this under the POLICY-constructive lens: "honest reporting of the vereador null and the resistance of most of the demeaning robustness check both show scientific maturity." The null is underpowered (Ref A, Concern 3, and you must fix that — see Deliverable 5 below), but your handling of it is professional.

**A pre-registered-style heterogeneity prediction.** Your §2 institutional discussion generates a falsifiable ex-ante prediction: militias, being institutionally entangled with the state, should translate territorial control into electoral capture; drug factions, being adversarial to the state, should not. Your data confirm this. This is the kind of structure that distinguishes a causal-inference paper from a pattern-matching paper, and it should be front and center in your Introduction (currently it is buried — see §3).

**A vereador null that is institutionally coherent.** The mayoral race responds to militia expansion; the open-list PR vereador race does not. This is not just a null — it is a *theory-consistent pattern* that supports the "capture of the executive" interpretation. Ref B's §5 discussion notes this is the right economic-policy framing and the Ferraz-Finan citation is well-placed (even if the specific citation is slightly miscalibrated — see Tier 1 cleanup below).

**A disciplined awareness of one's own robustness status.** The Appendix A within-municipality demeaning is explicitly labeled as non-standard and exploratory (lines 425-427). That honesty is rare and welcome. I will push back on the Appendix A framing below (§3.4), but the *intellectual honesty* of flagging it as a robustness exercise rather than a primary design is the right instinct.

These six assets are what justify publication at AEJ:Applied *after* the revision. The revision does not need to invent new contributions — it needs to surface and quantify the ones already here.

One thing I want to stress before moving on: the referees converged on a notable positive observation that Victor should internalize. Both Ref A (under the constructive-peeve lens, which "rewards clever natural experiments over technical machinery") and Ref B (under the "rewards unit-economics discussions" constructive lens) independently flagged the same assets. When two referees with *different* peeve structures credit you on the *same* three dimensions — design cleverness, institutional framing, and honest reporting of nulls — that is a strong signal that those dimensions are real. Do not underclaim them in the revision. The Introduction in particular currently underclaims on the Fogo Cruzado novelty, the pre-registered heterogeneity prediction, and the NT-vs-NYT design discipline. All three are worth one sentence each in paragraph three of §1.

---

## 3. What this paper is NOT (the honest gap to AEJ:Applied)

The hardest section for me to write, because the gap is not heroic — it is four specific execution problems, each of which a careful reader can spot in one read, and each of which the referees flagged independently.

### 3.1 The identification defense is one paragraph deep where AEJ:Applied expects a chapter

You state the estimator (§3.3, lines 156-179), you run the Wald tests, and you report `[0.210]` in Table 1. You do not state, in one clean sentence, what the identifying assumption is. You do not discuss reverse causality. You do not produce an event-study plot. You do not apply Honest-DiD. And you do not address the obvious objection that your own cited authority — Pantaleão & Montini 2025, Hidalgo et al. 2025 — argues *the reverse arrow* (elections cause militia expansion), which means your timing variation could be endogenous to the very electoral dynamics you are trying to identify.

This is convergent across reports. Ref A (Concerns 1 and 2): "Pre-trends are reported as Wald p-values, not shown graphically… The identifying assumption is not articulated as a testable sentence." Ref B (Concerns 1 and 6): "No Honest-DiD / pre-trend sensitivity… No cross-estimator robustness." Lens 3 (Methods): "The paper is one good critique away from a desk reject at QJE/AER on identification grounds, and the critique is that faction territorial expansion is almost surely not exogenous to local political configuration." Lens 5 (Robustness, 4/10): "The modal expected QJE robustness battery — honest-DiD, alternative estimators, placebos, MDE, spatial SEs, cohort-level ATT — is entirely absent."

At AEJ:Applied the bar is softer than at QJE but not by much: the post-2023 house style expects (a) a one-sentence formal identifying assumption, (b) an event-study figure (not just a coefficient plot), (c) Honest-DiD breakdown M̄, (d) at least one cross-estimator. This is a checklist, not a research agenda — a referee will want to tick each box, and in the current draft none of them are ticked.

### 3.2 Magnitudes are reported but not translated

You report ENC −0.459 and margin +6.2 pp. You do not report the *sample mean* of ENC or margin in the treated pre-period. Ref B's POLICY-peeve lens (Concern 2): "Is an ENC drop of 0.459 a big effect? I don't know, because I don't know if mean ENC in this sample is 2.0 or 8.0." Lens 4 (Results, 5/10): "The reader is not told what the sample mean ENC is, nor what the sample mean margin is."

This is the binding complaint at AEJ:Applied. A POLICY referee evaluates applied-micro on whether the magnitude matters for policy, not whether the t-statistic exceeds 2. The fix is cheap — a summary-statistics table with sample means and SDs by treatment status, plus a paragraph benchmarking the militia ATT against the Brazilian municipal-election distribution (what fraction of races have a margin below 6.2 pp? those are the races the effect would flip at the median) — but its absence now is not a cosmetic issue. It is why Ref B's Score 2 sanity check FAILs, and it is why the POLICY-dimension score caps at 70.

### 3.3 AEA compliance is mechanically violated in three places

Three of the twelve ADDRESSABLE items are not about identification at all — they are about whether you have read AEJ:Applied's house style:

- **No replication package mentioned.** Fogo Cruzado is a civil-society observatory with licensed data. The AEA Data Editor reviews the package pre-acceptance and returns manuscripts with incomplete packages. You must document: (a) whether you have permission to redistribute the polygons, (b) an exact access path for readers, (c) the code pipeline from polygons + TSE to Tables 1-2, (d) R package versions and `set.seed()` values. If Fogo Cruzado will not grant redistribution, you pivot to a reproduction-on-request model documented in the Data Availability statement. This is a hard pre-acceptance requirement — not a referee preference.

- **Significance stars in Tables 1 and 2.** AEA policy since 2023 forbids stars on the grounds that they encourage dichotomous reading of continuous evidence. SE in parentheses only; 95% CIs or p-values in notes. This is a 10-minute fix but its current presence signals you have not calibrated to the journal.

- **Table format ambiguity and misalignment.** Table 1's `Wald p` row-label is conflated with the SE-and-p-in-one-row convention; Lens 4 (Results, C1-C2) flags Table 2 in Appendix A as literally misaligned — SEs orphaned two rows below coefficients, NT/NYT panels visually scrambled. This is a LaTeX hygiene issue that takes an hour to fix but is a publication blocker in its current state.

These are not intellectual problems. They are discipline problems. Fix them the same afternoon.

### 3.4 The vereador tension between main-spec and demeaned-spec is unresolved

Main spec (Table 1 Panel B, NYT): vereador HHI +0.001, margin +0.002 — null.
Demeaned spec (Table 2 Appendix A, NYT): vereador HHI −0.022, margin −0.020 — negative.

You label Appendix A as "secondary and exploratory" (line 439) and reaffirm the null in §5.3 via the open-list-PR institutional argument. Lens 5 (Robustness): "Institutional structure does not change between specifications. If demeaning surfaces vereador effects, either (a) the raw spec is biased by municipality-level confounding that suppresses vereador effects, or (b) demeaning induces spurious findings via a mechanical transformation. The paper chooses neither horn and settles for dismissing the result."

The editor classifies this as TASTE rather than ADDRESSABLE, which means you can push back. But the cleaner move is to commit: either defend the raw-spec null as the correct estimand and demote the demeaned vereador numbers to a text paragraph (not an equally-formatted table), OR take the demeaned result seriously and rewrite §5.3. You cannot keep both in equal visual authority.

A technical note I owe you here, because Lens 3 M5 and Lens 5's compatibility note raise it and I want to be clear: within-municipality demeaning *applied to CS-DID's input data* is not equivalent to running CS with municipality-by-year fixed effects as conditioning covariates. The estimand changes. Under CS with NYT-within-faction-type and no conditioning, you identify the average effect of entering militia territory relative to not-yet-entering of the same faction type, pooled across municipalities. Under demeaning-then-CS, you identify how much entering militia territory pushes a station's outcome above or below its municipality-year mean — which includes in the benchmark the other treated stations in the same municipality-year. In municipalities where militia coverage is dense (Rio West Zone), the demeaning benchmark is partly contaminated by treated-station outcomes, which biases the estimate toward zero. That is one mechanical reason the demeaned vereador numbers can flip sign.

The correct technical fix, if you want to hold municipality-by-year unobservables constant, is to run CS conditionally: `att_gt(..., xformla = ~ municipality_FE * year_FE)` or pass pre-period municipality-level competition levels as covariates in `xformla`. That gives you a well-defined estimand under conditional parallel trends, and it is formally justified in Callaway-Sant'Anna 2021 §3. I would recommend doing that and dropping Appendix A's demeaning exercise entirely — or, if you keep Appendix A, reframing it explicitly as a descriptive exercise showing that the raw-spec finding is not driven by between-municipality composition, rather than as a CS-DID robustness check. This is a one-sentence-in-Appendix-A reframing, not a new estimation.

---

## 4. The FATAL deliverables — what blocks acceptance

**There are no FATAL deliverables.** Let me say that clearly, because it affects how you allocate your time. Both referees and the editor converged on zero FATAL concerns. The design is too clean for that, and every concern identified has a known mechanical fix.

What you have instead is twelve ADDRESSABLE items, of which four are first-round blockers in the sense that a referee will not sign off on R2 without them. I treat these four as the top-tier deliverables.

### Deliverable 1: Event-study plots + Honest-DiD sensitivity (the identification plot package)

**What to do.** For each of the six main cells (3 outcomes × 2 offices — HHI, ENC, margin × prefeito, vereador, for militia), produce a dynamic event-study figure at horizons k ∈ [−3, +3], normalized to k = −1, with 95% CIs. This is the standard `did` package output — `aggte(obj, type = "dynamic")` followed by `ggdid()` — three lines of R. Put the figure in the main text, not the appendix. Then apply Honest-DiD: `honestDiD::createSensitivityResults_relativeMagnitudes()` on each of the three militia/prefeito estimates. Report the breakdown M̄ — the ratio of maximum pre-period slope violation to the observed pre-period that would overturn your post-treatment sign.

**What done looks like.** A reader opens §4 and sees, for militia/prefeito HHI, an event-study with four pre-period coefficients hugging zero, a clean break at k = 0, and a stable positive path at k = 1, 2, 3. Next to the figure is a sentence: "The militia/prefeito HHI result survives linear pre-trend violations up to M̄ = [X] times the maximum observed pre-period slope." If M̄ > 1, you are robust. If M̄ < 1, you acknowledge the fragility and reframe.

**Time cost.** One R script, 2-3 days including drafting the figure captions and the Honest-DiD sentence for each outcome.

**Why this matters.** Ref A Concern 1 (MAJOR) + Ref B Concern 6 (MAJOR) + Lens 3 CRITICAL + Lens 4 M1 + Lens 5 C1. Five independent flags. Every reviewer who touched identification wanted this. The Wald test is a summary of an event-study figure that you have the code for but are not showing — that is not a defensible position at R2.

### Deliverable 2: Cross-estimator robustness (Sun-Abraham, minimum)

**What to do.** Run Sun-Abraham 2021 (interaction-weighted) on the six main cells, using the same NYT comparison. If you have time, also run de Chaisemartin-D'Haultfœuille 2020 (DIDl) or Borusyak-Jaravel-Spieß 2024 (imputation). Stack the results as a second panel in a revised Table 1. Agreement within roughly 10-20% of the CS-DID coefficients is the threshold most referees will accept.

**What done looks like.** Table 1 now has two side-by-side panels — CS-DID | Sun-Abraham — for militia/prefeito. Three columns of coefficients visibly agree. One-sentence note: "Sun-Abraham estimates fall within ±15% of the CS-DID point estimates for all three outcomes; see Appendix B for de Chaisemartin-D'Haultfœuille as a third cross-check."

**Time cost.** One R script using the `fixest::sunab()` or `did2s` packages, 1-2 days. If the estimators diverge, that is itself informative and requires a paragraph — budget an extra day for that contingency.

**Why this matters.** Ref B Concern 1 (MAJOR) + Lens 3 C3 + Lens 5 C2. Post-2021 AEJ:Applied convention is to report at least one cross-estimator. Any referee who has served on the journal's board in the last two years will flag its absence. This is not optional at AEJ:Applied in 2026.

### Deliverable 3: Identifying-assumption sentence + reverse-causality paragraph + placebo test

**What to do.** Three moves in §3.3, in this order.

(a) One sentence of the form: "Our identifying assumption is that, conditional on cohort g and faction type, the expected evolution of (HHI, ENC, margin) at newly-treated stations in the absence of treatment equals the observed evolution at not-yet-treated stations of the same faction type." You may phrase it how you like, but the sentence must be there, and it must be testable.

(b) One paragraph discussing why militia expansion timing is plausibly exogenous to electoral trends at the station level. Arguments in the literature that you can build on: militia expansion is driven by turf wars with drug factions (Magaloni et al. 2020), by the retreat of drug factions under state crackdowns (UPP rollouts, BOPE operations), or by geographic contagion along existing militia boundaries. Your job is to say which of these mechanisms dominates in your Rio sample and why that makes the timing conditionally exogenous at sub-cycle horizons.

(c) A placebo test: regress cohort-of-treatment g on lagged (t-1) electoral outcomes at the same station. If lagged HHI/ENC/margin predict g at conventional significance, your design is confounded and you must acknowledge it. If they do not, you have defended the assumption empirically.

**What done looks like.** §3.3 is now four paragraphs longer. Paragraph 1: formal identifying assumption. Paragraph 2: institutional mechanism-of-timing argument. Paragraph 3: placebo regression table showing g does not covary with lagged outcomes. Paragraph 4: acknowledgement of residual concern and why the NYT-within-faction-type design addresses it partially.

**Time cost.** One week. The placebo regression is a 30-minute task; the institutional paragraph is a one-afternoon writing task; the identifying-assumption sentence is 10 minutes. The week is for thinking through your own institutional evidence and for consulting with Lessing, Magaloni, or whoever is your local militia-expert interlocutor.

**Why this matters.** Ref A Concern 2 (MAJOR) + Lens 3 C1 (CRITICAL — the load-bearing intellectual critique). Your own cited literature argues the reverse arrow. If you do not address this head-on, a referee at R2 will simply write "the paper does not refute reverse causality" and the R&R clock resets. This is the highest-leverage intellectual fix in the revision.

### Deliverable 4: Magnitude-to-policy translation with baseline anchors

**What to do.** Four moves.

(a) Add a summary-statistics table (currently absent) with pre-treatment sample means and SDs of HHI, ENC, margin, separately for militia-treated, drug-treated, NYT militia, NYT drug, and NT stations. This is Table 0 of the paper.

(b) In §5, benchmark each militia ATT against its baseline. "ENC falls by 0.46 on a baseline of [X], a [Y]% reduction." "Margin widens by 6.2 pp on a baseline of [Z] pp, a [W]% increase." "HHI rises by 0.052 on a baseline of [V], equivalent to moving a polling station from the [P]th to the [Q]th percentile of Brazilian municipal-election vote concentration."

(c) Pull the TSE municipal-election distribution for Brazil (or metropolitan Rio). Report: "Among the 5,570 Brazilian municipalities, [X]% had a 2020 mayoral margin below 6.2 pp. Our estimated effect would, if applied to a hypothetical non-militia race at that margin, be sufficient to flip the outcome." This is the policy-relevant unit: races flipped by militia capture.

(d) One paragraph in §6 (Conclusion) explicitly tying magnitudes to policy implications: what would a hypothetical intervention that reduced militia territorial expansion by 50% do to competitive balance in Rio's 20 metropolitan municipalities?

**What done looks like.** Ref B's POLICY peeve is satisfied. A reader who skims §5 can say in one sentence what the effect means in policy units. The `FAIL on reporting` in Ref B's sanity-check table is cleared.

**Time cost.** Two days. The summary-statistics table is 30 minutes. The benchmarking paragraph is one afternoon. The TSE distribution pull is another afternoon (you already have this data). The §6 policy paragraph is a half-day of writing.

**Why this matters.** Ref B Concern 2 (MAJOR, binding for POLICY lens) + Lens 3 m1 + Lens 4 M2 + Desk review Concern 6. Four independent flags. At AEJ:Applied the POLICY bar is "can a reader calibrate whether the magnitude matters," and in the current draft the answer is no. This is Ref B's deal-breaker.

Let me make one more observation about how these four deliverables interact. Deliverable 1 (event-study + Honest-DiD) is the *display* layer of the identification defense. Deliverable 3 (identifying-assumption sentence + reverse-causality paragraph + placebo) is the *argumentation* layer. Deliverable 2 (cross-estimator) is the *specification-robustness* layer. Deliverable 4 (magnitude translation) is the *interpretation* layer. A reader at R2 will read these in that order — they will first look at your pre-trends plot, then read why you think the assumption holds, then check that Sun-Abraham agrees, then ask how big the effect is in policy units. If any one of the four is weak, the next one in the chain does not land. This is why I am treating all four as top-tier deliverables and not collapsing them into fewer items. Running all four in parallel is also feasible since they use different R packages and different passages of the manuscript — the event-study is `did::aggte` + `ggdid`, Honest-DiD is `honestDiD::createSensitivityResults_relativeMagnitudes`, Sun-Abraham is `fixest::sunab` or `did2s::did2s`, and the magnitude translation is a summary-statistics table plus a TSE-distribution pull. None of them blocks another.

---

## 5. The high-leverage rewrites — where the game-changer lives

Four editorial rewrites that require no new estimation and no new data. Each punches above its weight because it changes what the paper *looks like* to a reader landing on page 1.

### Rewrite 1: The abstract, with numbers

Current abstract (lines 10-18) names the topic and direction, does not quantify, does not name the method, does not articulate contribution. Lens 1 scored it 4/10 and gave you a model rewrite. Take their model. My version, tuned for AEJ:Applied:

> Do different types of armed factions exert distinct forms of electoral influence as their territorial control expands? We study metropolitan Rio de Janeiro (2008-2024), where paramilitary militias and drug-trafficking organizations jointly control a large share of neighborhoods but differ sharply in their relationship with the state. Using annual Fogo Cruzado territory maps (2007-2024) matched to 4,180 polling stations across five municipal elections in 20 municipalities, we implement the Callaway-Sant'Anna (2021) staggered difference-in-differences estimator, comparing newly-treated stations to not-yet-treated stations of the same faction type. Militia territorial expansion reduces mayoral (prefeito) electoral competition on all three standard measures: the effective number of candidates falls by 0.46, the margin of victory widens by 6.2 percentage points, and vote concentration rises by 0.052, with pre-trends passing joint Wald tests and sensitivity analysis indicating robustness to plausible pre-trend violations. Drug-faction expansion produces null effects on the same outcomes under the same design, and neither faction type affects open-list proportional city-council (vereador) races. The asymmetry is consistent with institutional differences in how militias and drug factions interact with the state.

That is 175 words, has the question in sentence one, names the method and data in sentences two and three, quantifies the three militia findings, includes the null contrast and the vereador null, and ends on the institutional interpretation. Write this in an afternoon.

### Rewrite 2: The introduction, Cochrane-style

The current introduction is 56 lines of field-journal writing that violates three of Cochrane's four rules: lit review before question, no magnitude preview, no enumerated contribution. Lens 2 scored it 5/10 with a model rewrite. Read Lens 2's model paragraphs carefully.

The three moves that matter for AEJ:Applied specifically:

(a) Pose the question by line 25 as a sharp interrogative: "Do different types of armed factions exert distinct forms of electoral influence as their territorial control expands — and if so, does the effect operate through channels an applied-micro reader can recognize?"

(b) Preview magnitudes with numbers, not direction. "Militia expansion reduces ENC by 0.46 (SE [Y]), widens margin by 6.2 pp (SE [Z]), and raises HHI by 0.052 (SE [V]). Drug-faction estimates are precisely-estimated nulls."

(c) Enumerate three contributions against Dell 2015 / Blattman et al. 2024 / Novaes 2023 / Pantaleão-Montini 2025. Pantaleão-Montini identifies elections → militia expansion; you identify militia expansion → electoral competition. State that difference in one sentence.

(d) Delete the seven-line within-municipality-demeaning apology (lines 61-68) from the Introduction. That paragraph is an 11% chunk of the intro devoted to pre-apologizing for a non-standard robustness check. Move the entire discussion to §5. This change alone reads like a full journal-tier upgrade.

**Time cost.** One afternoon.

### Rewrite 3: Commit to causal register

Abstract says "is associated with." §4 and §5 say "reduces / widens / compresses." Conclusion reverts to "is associated with." Lens 6 C3: "Oscillating between 'reduces' and 'is associated with' within the same manuscript signals the authors themselves are unsure of their identification strength."

Pick one register. Given that you are running CS-DID with NYT controls, pre-trends passing, and planning to add Honest-DiD + cross-estimator + placebo + event-study + reverse-causality paragraph — you have earned the causal register. Global find-and-replace: "is associated with" → "reduces / compresses / widens" in the abstract, results, discussion, and conclusion. Reserve "is associated with" for the lit-review framing in §1 only, where you are characterizing other people's findings.

**Time cost.** 30 minutes.

### Rewrite 4: Literature positioning against Pantaleão-Montini (and Hidalgo-Lessing)

Current §1 paragraph three cites Pantaleão-Montini 2025 four times but never explains what the paper finds or what your marginal contribution is. Lens 7 flagged a bibliographic hygiene problem — the paper appears to cite the same LAPS article twice under two different author attributions (Hidalgo, F. D., Lessing, B., et al. 2025 AND Pantaleão, B. and Montini, I. C. 2025, both titled "When elections empower crime", same journal, same year, same volume). Web verification against Cambridge Core confirms a single article.

Two moves:

(a) **Resolve the duplicate bibliographic entry.** It is the same paper. Figure out which attribution is correct, merge to one entry, delete the double-cite in lines 39 and 104. This is the cleanest desk-reject signal in the bibliography — a referee who spots it (and one will) concludes the bibliography was not checked. Fifteen minutes to fix.

(b) **Rewrite §1 paragraph three** to name Pantaleão-Montini by finding and state your marginal contribution explicitly: "Pantaleão and Montini (2025) document that electoral protection flows from elected officials to militias — elections empower crime. We document the reverse channel — that militia territorial expansion causally compresses electoral competition in mayoral races — and provide the first apples-to-apples militia-vs-drug-faction contrast in a heterogeneity-robust design."

**Time cost.** One afternoon of writing + 15 minutes for the bibliography fix.

### Rewrite 5: Promote the institutional-asymmetry prediction into the Introduction

Lens 2 M2 flagged a structural opportunity that I want to emphasize separately. Your §2 (lines 32-39) sets up the militia-vs-drug institutional contrast beautifully: militias are composed of current or former state agents, extract rents through quasi-legal services, and participate directly in electoral politics via voter mobilization and political protection networks; drug factions are adversarial to the state, operate covertly, and avoid direct electoral engagement. From this institutional asymmetry, a testable prediction *follows logically*: militia expansion should compress local electoral competition; drug-faction expansion should not.

Your data confirm this prediction. But the Introduction currently frames the heterogeneity result as a post-hoc observation — "we find that militias and drug factions differ" — rather than as a pre-specified test. That framing costs you. A referee who reads the Introduction and encounters a clean heterogeneity prediction that the design was set up to test, and then reads the Results and finds the prediction confirmed, is evaluating a theory-consistent confirmatory finding. A referee who reads a post-hoc heterogeneity result is evaluating specification searching. These are very different impressions of the same evidence.

Add one sentence at line 39: "This institutional asymmetry generates a testable prediction — militia expansion should compress local electoral competition; drug-faction expansion should not — which we bring to the data." Add one sentence in §4 Results opening: "Consistent with this prediction, ATTs on militia/prefeito are significant on all three outcomes; ATTs on drug/prefeito are precisely-estimated nulls." Two sentences, ten minutes of writing, and the heterogeneity result is now a theory-consistent confirmatory finding rather than a pattern-matching finding.

**Time cost.** Ten minutes.

---

## 6. Supporting deliverables

Five items that the referees would like to see but are not first-round blockers.

**6.1 Clustering at polygon level + wild-cluster bootstrap.** Ref B Concern 3. Your treatment varies at the Fogo Cruzado polygon level, not the polling station level — stations inside the same militia polygon receive the same treatment shock on the same date. Under Abadie-Athey-Imbens-Wooldridge 2023 clustering-for-experimenters logic, SEs must cluster at the level of assignment. State the clustering level explicitly in §3.3; re-run at polygon AND municipality levels; given likely small polygon count, report wild-cluster bootstrap p-values (Ibragimov-Muller 2010 is the fallback if G < 30). This is a one-day R task.

**6.2 Formal equality test ATT_militia = ATT_drug.** Ref A Concern 3. The drug-faction estimate has SE 0.202 on a −0.459 militia point estimate — the CIs overlap. Run a formal Wald test of coefficient equality for each outcome × office. If the null is not rejected at conventional levels, your comparative branding softens from "militias differ from drug factions" to "we estimate a militia effect; the drug-faction comparison is underpowered to reject equality." Report this honestly. Also report minimum detectable effects for the drug specification given N = 240. One-day task.

**6.3 External-validity paragraph mapping to Lessing 2021 scope conditions.** Ref A Concern 4. AEJ:Applied re-weights external validity from 15 to 20. One paragraph in §5 mapping the Rio militia mechanism onto Lessing 2021's criminal-governance taxonomy. Compare estimated magnitudes to Blattman et al. 2024 (El Salvador gangs) and Dell 2015 (Mexican drug war). This is cheap and addresses a dimension where the paper is currently silent.

**6.4 Balance table.** Ref B minor, Lens 3 M3. Pre-period covariate balance between treated and NYT militia stations on voter demographics, baseline competition, geography. Standard DiD deliverable; currently absent. One-day task.

**6.5 Sample-construction appendix.** Ref B minor, Lens 3 M1. Raw → analysis pipeline: number of stations geocoded, number dropped as "switchers" per Monteiro et al. 2022, geographic distribution, attrition patterns. One-page appendix.

---

## 7. TIER 1 cleanup — must fix before any submission

Two-to-three days of editorial discipline. Every item on this list damages credibility at desk review if left in.

**7.1 Duplicate bibliographic entry (Hidalgo = Pantaleão).** Already discussed in §5, Rewrite 4. Single biggest hygiene flag in the paper.

**7.2 Significance stars in Tables 1 and 2.** AEA policy since 2023 forbids. SE in parens only; CIs or p-values in notes. Ten-minute LaTeX fix.

**7.3 Table 2 (Appendix A) row/cell misalignment.** Lens 4 C1: SEs orphaned two rows below coefficients, NT/NYT panels visually scrambled. Rebuild in three-row blocks (coef / SE / Wald-p) with explicit row labels on every row.

**7.4 Table 1 "Wald p" row label ambiguity.** Lens 4 C2: the row labeled "Wald p" contains both SE in parens and Wald p in brackets. Relabel as `(SE) [Wald p]` or split into two rows.

**7.5 Ferraz-Finan 2008 miscalibration at lines 74-75 and 329.** Lens 7 M1. FF08 is about audit-driven electoral accountability, not mayoral policy authority over security / land-use / contracts. Replace with Ferraz-Finan 2011 (AER) on mayoral accountability or Brollo et al. 2013 (AER) on mayor discretion over federal transfers. Cite-claim direction is currently wrong on a load-bearing citation.

**7.6 Missing space at line 244.** "provide the preferred causal estimates.Figure 2 displays…" — insert space.

**7.7 Encoding mojibake in compiled PDF.** Lens 6 C1. Verify that "Pantaleão", "milícia", "Coordenação de Aperfeiçoamento de Pessoal de Nível Superior" render correctly in the compiled PDF, not as `Pantale�o`, `mil�cia`. Also verify em-dashes render as `—` not `�` in page-range entries (e.g., `537–581`, not `537�581`). Fifteen minutes if the source uses `\usepackage[utf8]{inputenc}` + lmodern or XeLaTeX/LuaLaTeX.

**7.8 Fogo Cruzado missing from references entirely.** Lens 7 M7. Main data source has no bibliography entry. Five-minute fix.

**7.9 TSE dataset citation missing access date and `[dataset]` tag.** Lens 7 M6. Standard AEA data-citation convention.

**7.10 Working-paper citations incomplete.** Dantas et al. 2023, Monteiro et al. 2022 — missing WP numbers and URLs. Novaes 2023, Magaloni et al. 2020 — missing vol/issue/pages. Lens 7 MINOR batch.

**7.11 Title-case inconsistencies in reference list.** "rio de janeiro" and "brazil" lowercase in three entries. Lens 7 m7.

**7.12 DOIs missing from all 19 reference entries.** Lens 7 m1. Standard practice.

**7.13 "et al." in reference list (Hidalgo, F. D., Lessing, B., et al. 2025).** Spell out all authors. Lens 7 m8. (This item dissolves when you merge with Pantaleão-Montini, but flag it in case of residual.)

All of 7.1 through 7.13 together = two days of editorial discipline. Do them in the same week. None of them is hard, and their cumulative absence signals to a referee that the paper is being shopped across journals.

---

## 8. Promotion list — things to surface earlier or louder

Three buried findings that deserve to be in the Introduction.

**8.1 The Fogo Cruzado annual-polygon data is novel to this paper.** No prior published work (to my knowledge, or Lens 7's) has used the annual territory polygons for causal identification of electoral effects. This is arguably your strongest standalone contribution, and it is currently mentioned almost in passing (§3.1 lines 138-141). Promote it to the Introduction's contribution paragraph: "We introduce the first causal use of Fogo Cruzado annual territory polygons for electoral analysis."

**8.2 The pre-registered-style heterogeneity prediction.** Your §2 institutional discussion generates a testable ex-ante prediction (militias ≠ drug factions because state-adjacent vs. state-adversarial), and your data confirm it. This is structurally stronger than a post-hoc heterogeneity finding. Frame it that way in the Introduction at line 39: "This institutional asymmetry generates a testable prediction — militia expansion should compress local electoral competition; drug-faction expansion should not — which we bring to the data." Ref A M2 and Lens 2 M2 both flag this.

**8.3 The NT-to-NYT pre-trends divergence is a feature, not a bug.** The NT controls fail pre-trends at p < 0.001 on all three militia/prefeito outcomes; the NYT controls pass. You handle this in one dismissive sentence (lines 240-244). Flip the framing: the NT failure is *empirical evidence* that inside-territory and outside-any-territory stations are on different political trajectories, which is exactly why you use NYT. This is a methodological discipline that most DiD papers in this literature do not apply. Promote it to §3.3 as a design-justification argument, not a buried diagnostic.

---

## 9. The path forward

A 2-3 month revision plan, ordered by leverage and dependency.

**Week 1 (mechanical cleanup, parallel tracks):**
- Tier 1 cleanup items 7.1 through 7.13. All doable in parallel; none depends on another.
- Abstract rewrite (§5, Rewrite 1). Depends on nothing.
- Introduction rewrite (§5, Rewrite 2). Depends on nothing.
- Commit to causal register (§5, Rewrite 3). Depends on nothing.
- Literature positioning against Pantaleão-Montini (§5, Rewrite 4). Depends on Tier 1 #7.1 being resolved.

End-of-week-1 output: a manuscript that looks and reads like AEJ:Applied house style, even without any new estimation.

**Weeks 2-4 (the identification package):**
- Deliverable 1 (event-study plots + Honest-DiD). This is the identification *display* layer. 2-3 days of R work. Depends on your CS-DID pipeline running cleanly.
- Deliverable 3 (identifying-assumption sentence + reverse-causality paragraph + placebo test). Longest intellectual task — budget one week including the institutional-mechanism-of-timing argument. Depends on you consulting with your local militia-expert interlocutor.

End-of-week-4 output: the identification defense is now chapter-deep, not paragraph-deep.

**Weeks 5-6 (the estimator-robustness package):**
- Deliverable 2 (cross-estimator: Sun-Abraham minimum). 1-2 days. Depends on Deliverable 1 pipeline running.
- Supporting 6.1 (clustering at polygon + wild-cluster bootstrap). 1 day.
- Supporting 6.2 (formal equality test + MDE). 1 day.
- Supporting 6.4 (balance table). 1 day.
- Supporting 6.5 (sample-construction appendix). 1 day.

End-of-week-6 output: the robustness battery now has standard 2026-era applied-micro hygiene.

**Weeks 7-8 (the policy-translation package):**
- Deliverable 4 (magnitude-to-policy translation with baseline anchors). 2 days. Depends on summary-statistics table being built.
- Supporting 6.3 (external-validity paragraph). 1 day.
- Resolve vereador tension (§3.4 in this synthesis). Pick a horn. 1 afternoon of thinking.

**Weeks 9-12 (the replication package):**
- AEA Data and Code Availability statement with OpenICPSR or Zenodo DOI reservation.
- Fogo Cruzado redistribution negotiation (budget 4-6 weeks in parallel because this depends on someone else's timeline). If Fogo Cruzado declines, pivot to a reproduction-on-request model.
- Code pipeline cleanup: R versions, `set.seed()` values, one-click reproduction from raw polygons + TSE to Tables 1-2.
- Response letter.
- Proof-read the full manuscript end-to-end.

**Parallel tracks:** Weeks 1 and 9-12 can run in parallel to Weeks 2-8 if you have co-authors splitting work. The identification package (Weeks 2-4) is the bottleneck and should not be parallelized with non-related tasks.

**Length trajectory.** 11 pp → 25-30 pp is the natural landing. Each deliverable grows the paper:
- Deliverable 1 adds a figure panel + 2 paragraphs (+3 pp)
- Deliverable 2 adds a table column + 1 paragraph (+1 pp)
- Deliverable 3 adds 4 paragraphs in §3.3 (+2 pp)
- Deliverable 4 adds a summary-statistics table + 2 paragraphs (+2 pp)
- Rewrites 1-4 net +3 pp in abstract and introduction
- Supporting 6.1-6.5 add an appendix section (+3 pp)
- Replication appendix (+1 pp)

Total: 11 + 15 = 26 pp, well within AEJ:Applied's typical 30-45 pp range.

---

## 10. Venue decision — AEJ:Applied vs. alternatives

AEJ:Applied is the natural fit. Let me tell you why I am confident about this and what the alternatives cost.

**Why AEJ:Applied is the right target.**

- **Subject-matter fit.** The journal has published adjacent Latin American crime/institutions work. Your setting (metropolitan Rio, militia-vs-drug contrast) and your estimand (polling-station-level electoral competition) are squarely within the political-economy + crime subset AEJ:Applied reads. A labor/public-econ referee will care about the institutions-to-public-goods transmission; a development-econ referee will care about the criminal-governance mechanism. Both are in AEJ:Applied's audience.

- **The bar is mechanical, not theoretical.** AEJ:Applied evaluates applied-micro on clean design + policy magnitudes + AEA replication compliance. Your design is clean (or will be after Deliverable 3). Magnitudes will be policy-relevant (after Deliverable 4). Replication will be AEA-compliant (after Week 9-12). That is three boxes to tick, and all three are mechanical given your data.

- **Zero FATAL.** The editorial letter says so explicitly: "No concern was raised that would make this paper unpublishable at AEJ:Applied regardless of what the authors do. The design is too clean for that, and every concern identified has a known fix." Twelve ADDRESSABLE items is a 2-3 month revision, not a rejection.

- **Convergent referee signals.** Ref A (CREDIBILITY, 69.4/100) and Ref B (POLICY, 69.4/100) both land at Major Revision — which is the exact distribution you want at the journal's bar. If either scored below 60 or above 80, I would be less confident. 69-70 at AEJ:Applied with zero FATAL is as textbook an R&R as you get.

**What shooting for QJE would cost.** Don't. The seven-pass lenses are QJE-calibrated and the average score is 5.1/10 with 18 CRITICAL flags. At QJE you would need: a redesigned §3 that handles reverse causality via instrument or boundary-discontinuity design, a ~35-40 pp manuscript, a theory-of-the-mechanism paragraph that AEJ:Applied does not demand, Honest-DiD + at least two cross-estimators (not one), Conley spatial SEs, donut-buffer robustness, cohort-level ATT(g,t) tables, and a literature positioning against 30-40 references (not 19). That is 6-12 months of additional work for a reach submission that the design does not support. At AEJ:Applied you are submitting a paper whose design *matches* the bar; at QJE you are submitting a paper whose design *aspires to* the bar.

**What retargeting shorter would cost.** Economics Letters or Journal of Urban Economics or Economics & Politics would accept the current 11 pp with modest revisions. But the POLICY-relevance bar is weaker there, the audience is narrower, and you lose AEJ:Applied's AEA-branded replication signal. Given that the natural revision extends the paper to 25-30 pp anyway, retargeting shorter sacrifices visibility without saving time. I do not recommend it.

**My recommendation: AEJ:Applied, first round. Budget 2-3 months for the revision. Expect Major R&R at R1 (already predicted by the editor), Minor R&R at R2 if Deliverables 1-4 are fully addressed, accept at R3.**

A word on where referees disagreed, because you should know what judgment calls I am making in this synthesis and why.

**Disagreement 1 — mechanism emphasis vs. magnitude emphasis.** Ref A wants you to defend identification harder (why expansion is plausibly exogenous, why the drug-null is meaningful, how the Rio setting generalizes). Ref B wants you to translate magnitudes to policy units. Both are right. At AEJ:Applied, the editor explicitly called out Ref B's magnitude-translation ask as the more binding — "a paper can defend identification to a skeptic and still fail the journal on 'so what?'" — and I agree. If you have to choose between polishing the identification defense to an additional 20% and polishing the magnitude translation to an additional 20%, polish the magnitudes. That said, you do not actually have to choose — Deliverables 1 and 4 are parallelizable.

**Disagreement 2 — drug-faction null interpretation.** Ref A reads the null as a power problem (CIs overlap, comparative branding therefore rests on two imprecisely-estimated effects). Ref B does not comment directly on the interpretation. I side with Ref A on the severity here. When you run the formal equality test (Supporting 6.2), I expect you will fail to reject H0: ATT_militia = ATT_drug for at least one of the three outcomes, and probably all three. The honest move is to reframe the comparative branding: this is a militia-expansion study with a drug-faction comparison that the design is underpowered to use as a rejection test. That reframing is not a weakening — it is a precision gain.

**Disagreement 3 — how much weight to give the within-municipality demeaning in Appendix A.** Lens 3 (Methods) treats it as ad-hoc and wants it replaced with covariate-conditioning CS. Lens 5 (Robustness) wants the demeaned vereador result *taken more seriously*. These are two sides of the same coin: the demeaned spec either identifies a well-defined estimand or it does not. My recommendation (§3.4 above) is to replace the demeaning with covariate-conditioned CS (`xformla = ~ municipality_FE`) for a technically-clean robustness check, and if you keep Appendix A at all, reframe it as a descriptive check on between-municipality composition rather than a CS-DID robustness.

These three disagreements are not tickets to split the difference. They are editor-judgment calls I am making for you based on AEJ:Applied's bar. If you disagree with any of them, we can talk. But I want you to know they are judgment calls, not mechanical consequences of the reports.

---

## 11. The single most important thing to internalize

Your paper has a clean design that the current draft obscures with weak framing and missing hygiene.

The identification is defensible: CS-DID with NYT-within-faction-type is the right estimator for the right treatment definition. The militia result is real. The drug-faction null (when you run the MDE and equality test) will turn out to be a comparison whose CIs genuinely overlap with militia, which means you will need to soften the comparative branding — but the militia-on-prefeito finding stands. The vereador null is theory-consistent. The heterogeneity prediction was pre-registered by your §2 institutional argument and confirmed by the data.

What the draft does not currently do is *display* any of this. The abstract does not quantify. The introduction does not enumerate contributions. The identification section is one paragraph. The magnitudes are not translated. The bibliography has duplicate entries. The tables have stars and misalignment. None of these is a research problem — all of them are presentation problems.

The single move you must make is to stop writing this as a short field-journal note and start writing it as an AEJ:Applied paper. That means: question in the first sentence of the abstract, numbers in the first page of the introduction, identifying assumption as a testable sentence in §3.3, magnitudes benchmarked to policy units in §5, replication package in the footnote on page 1. None of it is heroic. All of it is discipline.

The design has earned the venue. The draft has not yet. Close that gap.

One last thing I want you to internalize — because it shows up across every report and I think it is the unifying theme of the entire review package. The paper has a *hedging problem*. It hedges in the abstract ("is associated with"), hedges in the Introduction with a seven-line pre-apology for a non-standard robustness check, hedges in §4 by burying pre-trend failures of NT in one dismissive sentence, hedges in §5 by labeling the demeaned specification "exploratory" while still presenting it as equally authoritative as Table 1, and hedges in the conclusion by reverting to "is associated with." Each hedge is locally reasonable. Collectively, they signal to a referee that you are not confident in your own result.

You have earned confidence. Your design is defensible, your headline is clean, and your heterogeneity prediction was confirmed. The revision's job is not to add more hedging — it is to replace the hedges with specific, testable claims backed by explicit diagnostics. Event-study plot replaces "pass Wald tests." Honest-DiD M̄ replaces "pre-trends are flat." Identifying-assumption sentence replaces implicit appeal to the estimator. Magnitude benchmarked to race-flips replaces "substantively meaningful." Cross-estimator agreement replaces "CS-DID chosen for this design." Each of these substitutions trades a hedge for a specific, checkable claim. That is the move that converts a 69/100 referee score to an 85/100 acceptance. And that is what I mean by "close the gap."

— Pedro

---

## 12. Where to find the full reports

**AEJ:Applied peer-review package:**
- Desk review: `quality_reports/peer_review_faccoes_competicao_politica_AEJApplied/desk_review.md`
- Referee A (CREDIBILITY, 69.4/100): `quality_reports/peer_review_faccoes_competicao_politica_AEJApplied/referee_domain.md`
- Referee B (POLICY, 69.4/100): `quality_reports/peer_review_faccoes_competicao_politica_AEJApplied/referee_methods.md`
- Editorial decision (Major Rev, 0 FATAL + 12 ADDRESSABLE + 3 TASTE): `quality_reports/peer_review_faccoes_competicao_politica_AEJApplied/editorial_decision.md`

**Seven-pass lens package (QJE-calibrated; read for the sharpest version of each critique):**
- Lens 1 Abstract (4/10): `quality_reports/seven_pass_faccoes_competicao_politica/lens_1_abstract.md`
- Lens 2 Introduction (5/10): `quality_reports/seven_pass_faccoes_competicao_politica/lens_2_intro.md`
- Lens 3 Methods (5.5/10): `quality_reports/seven_pass_faccoes_competicao_politica/lens_3_methods.md`
- Lens 4 Results (5/10): `quality_reports/seven_pass_faccoes_competicao_politica/lens_4_results.md`
- Lens 5 Robustness (4/10): `quality_reports/seven_pass_faccoes_competicao_politica/lens_5_robustness.md`
- Lens 6 Prose (6.5/10): `quality_reports/seven_pass_faccoes_competicao_politica/lens_6_prose.md`
- Lens 7 Citations (5.5/10): `quality_reports/seven_pass_faccoes_competicao_politica/lens_7_citations.md`
- Seven-pass synthesis (REVISE-MAJOR, average 5.1/10): `quality_reports/seven_pass_faccoes_competicao_politica/_SYNTHESIS.md`

Read this synthesis first. Read the editorial decision letter second. Read Ref A and Ref B third. Read the seven-pass synthesis fourth for the sharpest version of each critique. The individual lens reports are the deepest layer — consult them when working on a specific deliverable (Lens 3 for Deliverables 1-3, Lens 4 and 5 for Deliverable 2 and the supporting robustness items, Lens 7 for the bibliography cleanup).

— Pedro


===========================================================================
# PART II — EDITORIAL VERDICT AND DECISION
===========================================================================

## Editor Desk Review (with referee briefs + novelty probes)

# Desk Review: Armed Factions and Local Electoral Competition

**Calibrated to:** American Economic Journal: Applied Economics (AEJ:Applied)
**Date:** 2026-04-18
**Paper:** `papers/faccoes_e_competicao_politica.txt`
**Novelty check:** ON

## Verdict

**SEND OUT (tight pass).** The paper clears the desk but barely. The identification strategy is clean in principle, the setting is substantively important, and the militia-vs-drug-faction contrast is a genuine contribution to the criminal-governance literature. The main desk-level worry is fit-meets-format: at 11 pages this manuscript is dramatically short for AEJ:Applied (typical 30-45 pp), the replication package is not mentioned in the text, tables use significance stars (forbidden by AEA policy since 2023), and there is no cross-estimator validation (Sun-Abraham / de Chaisemartin-D'Haultfoeuille) of the staggered DiD. None of these are desk-rejects individually; together they suggest the authors have not yet calibrated the manuscript to AEJ:Applied's house style. I send out with a strong signal to the referees that format and cross-estimator robustness should be flagged as ADDRESSABLE, not FATAL.

## One-paragraph contribution statement (my understanding)

The paper asks whether the temporal expansion of armed-faction territorial control in metropolitan Rio de Janeiro reduces local electoral competition, and whether this effect differs by faction type (drug-trafficking organizations vs. paramilitary militias). Using annual Fogo Cruzado territory polygons matched to geocoded polling stations and five municipal elections (2008-2024), the authors implement a Callaway-Sant'Anna staggered DiD comparing newly-treated stations to not-yet-treated stations of the same faction type. The headline finding is that militia expansion significantly reduces mayoral competition on three measures (vote concentration, effective number of candidates, margin of victory), with clean pre-trends, while drug-faction expansion shows no comparable effects and vereador (city council) races show no effects under the main specification. The contribution is twofold: (i) documenting that the two faction types have measurably different electoral footprints, and (ii) providing one of the first staggered-DiD estimates of criminal-territory-level effects on electoral competition with polling-station granularity.

## Fit assessment for AEJ:Applied

AEJ:Applied publishes applied-micro across labor, public, development, crime, and political economy. The paper's subject matter is squarely within the crime/political-economy subset the journal has published (e.g., Blattman-Green-Ortega-Tobon 2024 is in JPE, Dell 2015 in AER — but AEJ:Applied has published adjacent Latin American crime/institutions work). The economic-policy claim is indirect: "electoral competition" is not itself an economic outcome, but AEJ:Applied readers care about the institutions-to-growth / public-goods transmission (Acemoglu et al. 2020 is cited). The paper therefore clears the substantive fit test, but the authors have not done the work to sell it as an economics-policy paper — there is no cost-benefit framing, no magnitude-in-dollars translation, and no explicit link to fiscal or public-goods outcomes that would make a labor/public econ referee invested. This is the paper's biggest positioning weakness at this journal.

## Length concern (flag, not reject)

Eleven pages is unusual for AEJ:Applied. The typical submission is 30-45 pages main text plus appendix. Short papers are published but usually as "Comments" or when the design is so decisive it does not need defense. This paper's design — staggered DiD with a within-faction comparison, one main table, one robustness appendix — is not decisive enough to justify the page count. The authors should either (a) expand the analysis to AEJ:Applied conventions (adding cross-estimator robustness, event-study plots at horizon k, heterogeneity by faction sub-type, magnitude translation) or (b) retarget to a shorter-format journal (Economics Letters, Journal of Urban Economics, Economics & Politics). I am not desk-rejecting for length but referees should flag it.

## Replication package concern (flag)

The manuscript contains no reference to a replication package, data-access statement, or DOI for Fogo Cruzado territory maps. AEJ:Applied enforces the AEA Data and Code Availability Policy at submission, and the Data Editor reviews packages pre-acceptance. Fogo Cruzado maps are proprietary observatory data — the access path must be documented and, ideally, the authors should have a data-use agreement mentioned in the paper. This is a hard AEA requirement. I flag it for referees but will not desk-reject — it is fully ADDRESSABLE.

## Format concern (flag)

Tables 1 and 2 use significance stars (`p<0.01`, `p<0.05`, `p<0.10`). AEA journal policy since 2023 forbids stars; SE in parentheses only, with p-values or CIs in table notes. This is a mechanical fix but referees should note it — it signals the paper was not written with AEJ:Applied in mind.

## Novelty probes (ON)

| Probe | Query | Result |
|---|---|---|
| 1 | "armed factions electoral competition Rio de Janeiro polling station 2024-2026" | Pantaleao & Montini (2025, LAPS, "When elections empower crime") appears to overlap substantively: same setting, militia expansion, political protection mechanism. Cited by authors. No direct duplication — Pantaleao-Montini focuses on the elections-to-militia direction; this paper focuses on territory-to-competition. Distinction is defensible. Hidalgo, Lessing et al. (2025) also cited, similar mechanism. **Unable to verify full novelty — recommend author cross-check that no working paper in 2025-2026 has run a staggered DiD on Fogo Cruzado maps for electoral outcomes.** |
| 2 | "Callaway Sant'Anna difference-in-differences organized crime polling station" | No direct hit at this granularity. Novaes (2023, APSR) uses Brazil data but for law-enforcement candidates, not faction territory. Dell (2015, AER) uses RD not DiD. Design appears novel at the polling-station × faction-type × staggered-treatment level. |
| 3 | "Fogo Cruzado territory maps electoral outcomes Brazil" | Fogo Cruzado maps have been used in several 2023-2025 working papers on violence (Magaloni et al., Barnes, Dantas et al.) but I could not find a published paper using the annual polygons as staggered treatment for electoral outcomes. Novelty assessment: **likely clear, but recommend author cross-check NBER WP and SSRN post-Jan 2026.** |

**Novelty assessment:** Likely clear. The paper's unique combination is Fogo Cruzado staggered polygons + polling-station electoral outcomes + CS-DID with within-faction-type NYT controls. Pantaleao-Montini 2025 is the closest cousin and must be engaged with substantively, not just cited — the paper cites it four times but does not explain clearly what the marginal contribution is beyond that paper.

## Main concerns for AEJ:Applied framing

1. **Length (11 pp) is thin for AEJ:Applied** — flag, not desk-reject.
2. **No replication package mentioned** — AEA Data Editor will require it pre-acceptance.
3. **AEA table format violation** (significance stars).
4. **No modern-DiD cross-estimator.** Only Callaway-Sant'Anna is used. AEJ:Applied referees post-2023 expect at least one of Sun-Abraham (2021) or de Chaisemartin-D'Haultfoeuille (2020) as a cross-check — this is now house-style.
5. **Identification defense is thin for a skeptical crime-policy AEA referee.** The parallel-trends assumption is defended by Wald tests only. The mechanism of treatment assignment (why does a polling station come under faction control in year t and not t-1?) is not discussed. A skeptical referee will ask: is faction expansion endogenous to local political dynamics (e.g., militia moves in because a friendly politician was elected)? The paper's identifying assumption is that treatment timing is conditionally independent of electoral competition trends — this needs a paragraph, not just a Wald p-value.
6. **Magnitude interpretation is weak.** The paper reports ENC falls by 0.459 units and margin widens by 6.2 pp, but does not benchmark these against the sample mean, against municipal-election variation across Brazil, or against what a policy intervention might move. This is a POLICY-referee deal-breaker at AEJ:Applied.

## Send-out plan

Proceed to Phase 1b referee selection.

## Referee Selection

Drew two different dispositions from AEJ:Applied pool weights (CREDIBILITY 0.40, POLICY 0.20, STRUCTURAL 0.15, MEASUREMENT 0.15, THEORY 0.05, SKEPTIC 0.05). D1 = CREDIBILITY (top weight; matches the paper's central claim to clean identification). D2 = POLICY (second weight; matches the AEJ:Applied bar on policy-relevant magnitudes, which is the paper's weakest dimension). These two dispositions maximize cognitive diversity: Ref A will ask "is the design airtight" and Ref B will ask "does the magnitude matter for a policy audience."

| Referee | Disposition | Critical peeve | Constructive peeve |
|---|---|---|---|
| Referee A (domain) | CREDIBILITY | Pre-trends must be shown for any DiD, explicitly and graphically | Values clever natural experiments over technical machinery |
| Referee B (methods) | POLICY | Any claim about "policy implications" must be supported by the data's support range | Rewards unit-economics discussions (what does this translate to in policy terms?) |


---

## Editorial Decision Letter (with concern table + decision rule)

# Editorial Decision: Armed Factions and Local Electoral Competition

**Calibrated to:** American Economic Journal: Applied Economics (AEJ:Applied)
**Decision:** Major Revision

## One-paragraph editor's assessment

This is a potentially good AEJ:Applied paper buried inside a manuscript that has not been calibrated to the journal. The design — Callaway-Sant'Anna staggered DiD on polling-station × Fogo-Cruzado-polygon data, with within-faction-type NYT controls — is clever and under-used in the criminal-governance literature; the militia-vs-drug-faction institutional contrast is a real contribution; and the headline militia/prefeito result is substantively plausible and internally consistent. The path to acceptance is ADDRESSABLE, not FATAL: the authors need to (a) defend identification beyond Wald p-values (event-study plots + Honest-DiD + a testable-sentence statement of the assumption + a discussion of reverse causality), (b) add at least one cross-estimator (Sun-Abraham or de Chaisemartin-D'Haultfoeuille), (c) translate magnitudes into policy-relevant units and benchmark against sample means the paper currently does not report, (d) fix clustering, MHT, and AEA formatting, and (e) submit a compliant replication package. None of this requires new data. All of it is a 2-3 month revision. I expect both referees back at R2.

## Referee summary

- **Referee A (CREDIBILITY):** score 69.4/100. Design is clever and the contribution is real, but pre-trends are hidden in Wald p-values instead of shown graphically, the identifying assumption is never stated formally, and the drug-faction null is underpowered to support the comparative branding.
- **Referee B (POLICY):** score 69.4/100 (sanity-check FAILs cap at 70). The CS-DID estimator is correct but one-deep: no cross-estimator robustness, uncertain clustering, missing Honest-DiD, no replication package, no magnitude-in-policy-units translation, and AEA table format is violated.

Both referees land in Major Revision territory, with convergent concerns (pre-trends defense, identifying assumption, magnitudes, format) and one divergence on emphasis (Ref A pushes harder on the substantive mechanism; Ref B pushes harder on mechanical compliance).

## Concern classification

### FATAL

None. No concern was raised that would make this paper unpublishable at AEJ:Applied regardless of what the authors do. The design is too clean for that, and every concern identified has a known fix.

### ADDRESSABLE

| Concern | From | Suggested path |
|---|---|---|
| Pre-trends shown as Wald p-values, not event-study plots | Ref A (Concern 1) / Ref B (dynamics sanity-check FAIL) | Add event-study figures at k ∈ [-3, +3] for each of the six main cells; apply Honest-DiD / Rambachan-Roth sensitivity analysis and report breakdown M̄. |
| Identifying assumption not articulated as a testable sentence; reverse causality (militia expansion endogenous to electoral alignment) not ruled out | Ref A (Concern 2) | Add a one-sentence formal statement of the assumption; discuss why expansion timing is plausibly exogenous (turf wars, geographic diffusion); add a placebo test on lagged electoral outcomes. |
| Drug-faction null is underpowered; comparative claim rests on two imprecise estimates | Ref A (Concern 3) | Formal test of equality of coefficients (militia vs. drug); minimum-detectable-effect calculation; soften comparative branding if equality not rejected. |
| No cross-estimator robustness | Ref B (Concern 1) | Report Sun-Abraham and/or de Chaisemartin-D'Haultfoeuille for the six main cells; agreement within 10-20% would satisfy most referees. |
| Magnitude interpretation lacks policy-relevant units | Ref B (Concern 2) | Report sample means + SDs; benchmark militia ATTs against Brazilian municipal-election variation; translate margin widening into fraction of competitive races that would be flipped. |
| SE clustering level unspecified, likely station-level when polygon-level is correct | Ref B (Concern 3) | State clustering level; re-run clustering at polygon AND municipality; wild-cluster bootstrap given small polygon count. |
| No replication package; AEA Data Editor compliance unclear | Ref B (Concern 4) | Add Data and Code Availability statement with OpenICPSR/Zenodo DOI, Fogo Cruzado access path and license, analysis code. |
| AEA table format violation (significance stars) | Ref B (Concern 5) | Remove stars; SE in parens only; CIs or p-values in notes. |
| External validity not addressed; Rio setting not mapped to scope conditions | Ref A (Concern 4) | One paragraph mapping the militia mechanism onto Lessing 2021's taxonomy; compare estimated magnitudes to Blattman et al. 2024 / Dell 2015. |
| Literature positioning against Pantaleao & Montini 2025 and Hidalgo-Lessing 2025 under-articulated | Ref A (Concern 5) | Rewrite intro paragraph three to name the closest cousins by finding and state this paper's marginal contribution explicitly. |
| Honest-DiD / pre-trend sensitivity absent | Ref B (Concern 6) | Apply `HonestDiD` package; report breakdown M̄ for the three militia/prefeito cells. |
| Length (11 pp) thin for AEJ:Applied | Editor / desk review | The revisions above naturally expand the paper. A 25-35 pp revision with appendix is standard. |

### TASTE (author may push back)

| Concern | From | Editor's view |
|---|---|---|
| Paper should expand vereador discussion given demeaning appendix finds effects | Ref A (minor) | Taste — the authors' current handling (main-spec null is the headline; demeaned suggestive is appendix) is defensible. They should acknowledge the tension in one sentence and move on. |
| Simple aggregation weights early cohorts more; report group-weighted aggregation | Ref B (minor) | Reasonable suggestion but not a decision-critical ask. Appendix table. |
| Unweighted robustness (analytic weights by eligible voters) | Ref B (minor) | Appendix table. |

## Where referees disagreed

The two referees converged more than they diverged, which is mildly unusual for CREDIBILITY × POLICY pairings. The substantive disagreements:

- **Emphasis on mechanism vs. magnitude.** Ref A (CREDIBILITY) wants the paper to defend the causal interpretation harder: why militia expansion is exogenous, why drug-faction null is meaningful, how the scope conditions travel. Ref B (POLICY) wants the paper to commit to policy-relevant units: what does a 6.2 pp margin widening mean for Brazilian municipal democracy. Editor's view: both are right, but Ref B's magnitude-translation ask is the more binding for AEJ:Applied — a paper can defend identification to a skeptic and still fail the journal on "so what?".
- **Drug-faction null: underpowered or substantive?** Ref A reads the null as a power problem (CIs overlap). Ref B does not comment directly. Editor's view: the authors should run the equality test Ref A asks for, and if it fails to reject, they should reframe the paper as a militia-expansion study with a drug-faction comparison rather than a comparative study.
- **External validity weight.** Ref A flags it as a major concern per AEJ:Applied's re-weighting (15→20). Ref B does not flag it. Editor's view: at AEJ:Applied in 2026 this is a standard ask; one paragraph fixes it.

## Response-planning block (for the author)

**MUST address** (every ADDRESSABLE concern; these will be re-checked at R2):

1. Event-study plots for the six main cells at horizons k ∈ [-3, +3], in the main text (not appendix).
2. Honest-DiD / Rambachan-Roth sensitivity bounds for the three militia/prefeito cells. Report breakdown M̄.
3. Formal one-sentence statement of the identifying assumption in Section 3.3.
4. Paragraph on why militia expansion timing is plausibly exogenous to electoral trends; placebo test on lagged electoral outcomes.
5. Formal test of equality: H0: ATT_militia = ATT_drug for each outcome × office. Report in a revised Table 1.
6. Cross-estimator robustness: Sun-Abraham and/or de Chaisemartin-D'Haultfoeuille, at minimum Sun-Abraham. Report alongside CS-DID in the main table.
7. Summary-statistics table (currently absent) with sample means, SDs, and within-municipality variation for the six outcomes.
8. Magnitude translation: benchmark the militia ATTs against the Brazilian municipal-election distribution; report the fraction of races the effect would flip at the median pre-treatment margin.
9. Clustering: state level explicitly; re-run at polygon and municipality levels; wild-cluster bootstrap.
10. Replication package: Data and Code Availability statement, Fogo Cruzado access path and license, OpenICPSR/Zenodo DOI reservation, R package versions, `set.seed()` values. Submit package for R2 review.
11. AEA table format: remove significance stars; SE in parens only; CIs or p-values in notes.
12. External-validity paragraph in Section 5 mapping the mechanism to Lessing 2021 scope conditions.
13. Literature positioning: rewrite intro paragraph three to state the marginal contribution vs. Pantaleao-Montini 2025 and Hidalgo-Lessing 2025 explicitly.
14. Balance table (pre-period covariate balance between treated and NYT militia stations).
15. Sample-construction appendix: raw → analysis pipeline, including number of "switching" stations excluded per Monteiro et al. 2022.

**SHOULD address:**

- MHT correction (Romano-Wolf or Bonferroni) given 24 main estimates.
- Alternative aggregation (`aggte(type = "group")`) in appendix.
- Unweighted robustness.
- One-sentence acknowledgement of the vereador tension between main-spec null and demeaned-spec effects.

**MAY push back:**

- The framing choice that the main specification uses raw outcomes and demeaning is a robustness check (not the other way around). Defensible given CS-DID literature conventions.
- The decision not to add a third faction-type category (mixed or disputed territory). Monteiro et al. 2022's stable classification is standard; excluding switchers is the right call.
- Page length — if the revision lands at 25-30 pp rather than 40, this is fine. AEJ:Applied does not enforce a minimum.

**Expected resubmission path.** The authors have 2-3 months of work in front of them. Most items above are single-day tasks in R on data the authors already have. The exception is the replication package, which requires negotiating redistribution or data-access terms with Fogo Cruzado. If that negotiation fails, the authors should convert the package to a reproduction-on-request model documented in the Data Availability statement. At R2 both referees return; if items 1-9 above are fully addressed and the magnitude translation is honest, I expect a Minor Revision outcome at R2. If the cross-estimator results diverge materially from CS-DID, that opens a new conversation and could push to a second Major Revision.


===========================================================================
# PART III — FULL REFEREE REPORTS
===========================================================================

## Referee A (Domain)

# Domain Referee Report

**Calibrated to:** American Economic Journal: Applied Economics (AEJ:Applied)
**Disposition:** CREDIBILITY
**Critical peeve:** Pre-trends must be shown for any DiD, explicitly and graphically
**Constructive peeve:** Values clever natural experiments over technical machinery
**Date:** 2026-04-18
**Paper:** `papers/faccoes_e_competicao_politica.txt`

## Executive verdict

**Score:** 68/100
**Recommendation:** Major Revision
**Headline:** The design is genuinely clever and the militia-vs-drug contrast is a real contribution, but the identification defense is currently one paragraph deep where AEJ:Applied expects a chapter, and the pre-trends are hidden behind Wald p-values instead of the event-study plots a credibility referee wants to see.

## Dimension scores (AEJ:Applied-adjusted)

| # | Dimension | Weight | Score | Weighted |
|---|---|---|---|---|
| 1 | Contribution & Novelty | 30% | 72/100 | 21.6 |
| 2 | Literature Positioning | 25% | 65/100 | 16.3 |
| 3 | Substantive Arguments | 20% | 68/100 | 13.6 |
| 4 | External Validity | 20% (15→20) | 62/100 | 12.4 |
| 5 | Fit for AEJ:Applied | 10% | 55/100 | 5.5 |
| | **Composite** | | | **69.4/100** |

## Major concerns (each with "What would change my mind")

### Concern 1: Pre-trends are reported as Wald p-values, not shown graphically

**Dimension:** 3 (Substantive Arguments) / also 1
**Severity:** MAJOR
**Description:** The paper's central causal claim rests on parallel pre-trends. Table 1 reports Wald joint-test p-values in brackets (e.g., 0.210 for militia/prefeito HHI) and the text asserts "all three estimates pass the joint pre-trends test." Figure 2 shows ATT point estimates with CIs but NOT an event-study plot with coefficients at each pre- and post-treatment horizon. For a CS-DID paper in 2026, this is below standard practice. A credibility referee wants to see coefficients at k=-4, -3, -2, -1 (normalized), 0, +1, +2, +3 with 95% CIs, for each of the six outcome-faction-office cells. A Wald p-value of 0.21 can mask a pre-trend that is nonzero and economically meaningful but imprecisely estimated — in a sample of 398 treated militia stations, power to detect moderate pre-trend slopes is not guaranteed.
**Why this matters:** This is the single biggest credibility threat in the paper. If pre-trends are visibly non-flat in event-study form, the headline militia/prefeito result loses its interpretation. The Wald test is necessary but not sufficient; the graphical evidence is what persuades a skeptical applied-micro audience.
**What would change my mind:** Add an event-study figure for each of the six main cells (3 outcomes × 2 offices) showing CS-DID dynamic ATTs at horizons k ∈ [-3, +3] with 95% CIs, normalized to k=-1. For the militia/prefeito cells specifically, also report a Roth (2022) sensitivity / Honest-DiD bound: how big would a linear pre-trend violation have to be to overturn the sign of the post-treatment estimate? If Honest-DiD shows robustness to substantively plausible pre-trend slopes, I am convinced.

### Concern 2: Identification assumption is not articulated as a testable sentence

**Dimension:** 3 / 1
**Severity:** MAJOR
**Description:** The paper says treatment is defined as a polling station falling inside a faction territory, and the CS-DID estimator is applied with NYT controls. But the paper never states, in one sentence, what the identifying assumption is: "conditional on station fixed effects and calendar-year fixed effects, the timing of a polling station's entry into militia territorial control is independent of the counterfactual trajectory of its electoral competition outcomes." And then: is that plausible? The paper's own institutional discussion (Section 2, p. 2) says militias "mobilize voters for allied candidates" and "convert electoral support into political protection." If militias expand into a neighborhood BECAUSE it has a politically aligned population (which then votes cohesively for a militia-backed mayor), then treatment timing is endogenous to potential electoral outcomes, and the CS-DID estimate is confounded rather than causal.
**Why this matters:** This is the standard reverse-causality concern in the criminal-governance literature, and the paper does not address it. Novaes (2023, APSR) thought carefully about this in the law-enforcement-candidates context; Dell (2015, AER) used RD precisely to avoid it. The paper's defense — that NYT controls and pre-trends address it — is mechanical, not substantive.
**What would change my mind:** (a) A paragraph in Section 3.3 stating the identifying assumption formally. (b) A discussion of WHY militia expansion is plausibly exogenous to future electoral trends at the station level. Plausible arguments: militia expansion is driven by turf wars with other factions (Magaloni et al. 2020), by drug-faction retreat under state crackdowns, or by proximity to existing militia territory (contagion / geographic diffusion). (c) A placebo test: does the timing of militia expansion correlate with lagged electoral competition at the same station? If expansion is driven by past election outcomes, the design is compromised. (d) At minimum, a heterogeneity cut by the mechanism that shifts expansion timing — e.g., stations that come under militia control during a faction-turf-war year (exogenous push) vs. a political-alignment year (endogenous pull).

### Concern 3: The drug-faction null is underpowered, not informative

**Dimension:** 3 / 4
**Severity:** MAJOR
**Description:** The paper interprets the drug-faction null as substantively meaningful — that drug factions do not translate territorial control into electoral advantage, consistent with the institutional story that they avoid direct political engagement. But with N=240 treated drug stations (vs. 398 militia) and point estimates for ENC of +0.100 (SE 0.202), the drug-faction estimate is underpowered to rule out the militia-size effect. The confidence interval on drug ENC comfortably includes the militia effect of -0.459. The paper's key substantive claim — that militias differ from drug factions in electoral footprint — is therefore a claim about two imprecisely-estimated effects whose CIs overlap.
**Why this matters:** The comparative claim (militias ≠ drug factions) is the paper's main branding. If the two estimates are statistically indistinguishable, the paper is reporting a militia effect, not a contrast. This is a power problem, and a CREDIBILITY referee will not let it pass.
**What would change my mind:** (a) Report a formal test of equality of coefficients: H0: ATT_militia = ATT_drug, for each outcome × office cell. If the null is not rejected at conventional levels, the paper's comparative branding needs to be softened substantially. (b) Report minimum detectable effects for the drug-faction specification given N=240 and the observed SE. (c) If the test rejects for mayor but not vereador, the paper has a story; if it fails to reject, the paper is a militia paper.

### Concern 4: External validity — one metropolitan region, one country, one five-election window

**Dimension:** 4 (External Validity, AEJ:Applied re-weighted 15→20)
**Severity:** MAJOR
**Description:** The paper's external validity defense is absent. 20 municipalities in metropolitan Rio, one particular institutional configuration (paramilitary militias composed of state agents) that may not replicate in other criminal-governance contexts (e.g., Mexico cartels, El Salvador gangs, Colombian paramilitaries). The paper cites Dell 2015 (Mexico), Blattman et al. 2024 (El Salvador), Trejo-Ley 2020 (Mexico), but does not discuss which features of the Rio militia mechanism should generalize and which are specific to the paramilitary-origin institutional form.
**Why this matters:** AEJ:Applied re-weights external validity to 20% precisely because applied papers must speak to a policy or institutional question beyond their setting. The paper as written reads as "this happened in Rio" rather than "this is what happens when armed groups with state-adjacent origins hold territory over time."
**What would change my mind:** A paragraph in Section 5 explicitly mapping the Rio militia mechanism onto the scope conditions under which it should replicate. Useful references: Lessing 2021 (criminal governance taxonomy) distinguishes exactly the institutional forms the paper cares about. A brief comparison of the estimated militia effect magnitudes to what has been estimated in other settings (e.g., Blattman et al. 2024 on gang extortion and labor mobility — what does a comparable "competition" effect look like?) would help enormously.

### Concern 5: Literature positioning against Pantaleao & Montini (2025) is not articulated

**Dimension:** 2 (Literature Positioning)
**Severity:** MAJOR
**Description:** The paper cites Pantaleao & Montini (2025, LAPS) four times — it is the closest cousin in the literature. But the paper never explains explicitly what Pantaleao-Montini find and what this paper adds on top. Pantaleao-Montini appears to document that elections empower militia expansion (elections → militias); this paper documents that militia expansion reduces competition (militias → elections). The reverse-direction framing is the contribution, but it is never stated that way. Hidalgo-Lessing et al. (2025) is cited once with a similar mechanism. The positioning reads as "these other papers exist" rather than "our contribution, relative to X, is Y."
**Why this matters:** An AEJ:Applied referee who has read Pantaleao-Montini will read this paper and ask "what's new?" — and the paper does not answer.
**What would change my mind:** Rewrite the introduction's third paragraph so that it names Pantaleao-Montini and Hidalgo-Lessing by finding, explains the direction of causation each studies, and positions this paper's contribution explicitly (e.g., "Pantaleao-Montini document elections → militia expansion; we document militia expansion → electoral competition, completing the feedback loop that Lessing 2021 theorizes"). Two paragraphs, not one sentence.

## Minor suggestions

- Figure 1 description says "Yellow shading = militia territory" but the text says "triangles = militia" and "circles = drug" — the figure legend in the paper uses abstract symbols. Check that the actual rendered figure is legible in black-and-white (AEJ:Applied requirement for accessibility).
- Table 1 has a formatting glitch: the SE row labeled "Wald p" is in parentheses where the SE should be. Pre-trends p-values are also bracketed. This is confusing — reorganize as three-row cells (coef / SE / Wald p) with clear labels.
- The vereador null is interpreted institutionally (open-list PR making armed influence harder to concentrate) but the Appendix A demeaned results show vereador HHI falling and margin declining for militias. This contradiction is acknowledged but not resolved — pick one story.
- Footnote 1 on the simple aggregation is correct but the implications of weighting by group size should be discussed: cohorts treated in 2008 (earliest) will dominate the simple ATT. Consider reporting the group-specific ATTs in an appendix table.
- "Metropolitan Rio" sample selection is not documented. Why 20 municipalities? Which 20? A map in the appendix would help.
- The abstract would benefit from a magnitude number. "Lower competition" is vague; "the margin of victory widens by 6.2 pp" tells the reader something.

## Positive observations

The design is genuinely clever. Exploiting the staggered temporal expansion of Fogo Cruzado territory polygons to identify faction-type-specific electoral effects at the polling-station level is a natural experiment the literature has not used — and I note this under my constructive-peeve lens, which rewards clever natural experiments over technical machinery. The militia-vs-drug-faction contrast is the right question; the institutional discussion in Section 2 is careful; the decision to use NYT-within-faction-type as the preferred control is methodologically disciplined and shows the authors understand the CS-DID toolkit. The appendix demeaning robustness check is a nice touch: the authors do not have to run it, and doing so honestly (acknowledging it is not the standard baseline) shows scientific maturity. If the authors address the five major concerns, this is a solid AEJ:Applied paper — the skeleton is here.


---

## Referee B (Methods)

# Methods Referee Report

**Calibrated to:** American Economic Journal: Applied Economics (AEJ:Applied)
**Disposition:** POLICY
**Paper type:** Reduced-form (staggered DiD / Callaway-Sant'Anna)
**Critical peeve:** Any claim about "policy implications" must be supported by the data's support range
**Constructive peeve:** Rewards unit-economics discussions (what does this translate to in policy terms?)
**Date:** 2026-04-18
**Paper:** `papers/faccoes_e_competicao_politica.txt`

## Executive verdict

**Score:** 66/100 (sanity-check FAILs cap at 70)
**Recommendation:** Major Revision
**Headline:** The estimator is correct for the research design, but the paper does not clear the AEJ:Applied bar on (i) cross-estimator robustness, (ii) replication-package compliance, or (iii) policy-relevant magnitude translation — all three are standard-issue at this journal and all three are fixable.

## Pre-scoring sanity checks

| Check | PASS/FAIL | Evidence |
|---|---|---|
| Sign check — militia/prefeito signs match theory (militia expansion ↓ competition) | PASS | HHI +0.052, ENC −0.459, Margin +0.062 all in the direction of lower competition (Table 1). |
| Magnitude check — coefficients in a reasonable range | PARTIAL | ENC of −0.459 and margin of +6.2 pp are plausible; HHI of +0.052 is plausible against a baseline HHI that is not reported. **FAIL on reporting:** the sample means of the outcomes are never shown, so the referee cannot tell whether +0.052 is a 5% or a 50% relative change. |
| Dynamics check — pre-trends flat graphically for DiD | FAIL | Only Wald p-values are reported. No event-study plot at horizons k ∈ [-3, +3]. Figure 2 plots aggregate ATT point estimates, not dynamic paths. This is a standard CS-DID output (`ggdid` on the `att_gt` object) and its absence is a red flag. |
| Clustering check — SEs clustered at treatment unit | UNCERTAIN | The paper does not state the clustering level. CS-DID default is station-level clustering (via influence-function bootstrap). Given treatment is at the station level but faction-territory assignment is at the polygon level, the correct cluster is the polygon, not the station — stations inside the same militia polygon share a treatment shock and are not independent. This likely understates SEs. |
| Sample check — raw → analysis sample documented | PARTIAL | The paper reports 4,180 stations, 20 municipalities, 5 elections, 398 militia + 240 drug treated. But the raw-to-analysis pipeline is not shown. How many stations were geocoded? How many dropped for "switching faction type" (Section 3.2)? Attrition is not documented. |

**Two FAILs (dynamics + clustering UNCERTAIN) and two PARTIALs cap the composite score at 70.**

## Dimension scores (AEJ:Applied-adjusted: Identification 35→40, Replication 5→15)

| # | Dimension | Weight | Score | Weighted |
|---|---|---|---|---|
| 1 | Identification | 40% (35→40) | 68/100 | 27.2 |
| 2 | Estimation | 25% | 72/100 | 18.0 |
| 3 | Inference (SEs, clustering, MHT) | 20% | 55/100 | 11.0 |
| 4 | Robustness | 15% | 58/100 | 8.7 |
| 5 | Replication | 15% (5→15) | 30/100 | 4.5 |
| | Raw composite | | | **69.4/100** |
| | (cap at 70 due to sanity-check FAILs) | | | **69.4/100** |

## Major concerns (each with "What would change my mind")

### Concern 1: No cross-estimator robustness (Sun-Abraham, de Chaisemartin-D'Haultfoeuille)

**Dimension:** 4 (Robustness) / 2 (Estimation)
**Severity:** MAJOR
**Description:** The paper uses only Callaway-Sant'Anna 2021 with the "simple" aggregation. Post-2021 AEJ:Applied convention is to report at least one cross-estimator — Sun-Abraham 2021 (interaction-weighted), de Chaisemartin-D'Haultfoeuille 2020 (DIDl), or the Borusyak-Jaravel-Spiesschaert 2024 imputation estimator — as a robustness check. This is not optional at AEJ:Applied in 2026; any referee who has served on the journal's board in the last two years will flag it.
**Why this matters:** CS-DID is robust to heterogeneous treatment effects but makes specific assumptions about the reference group and aggregation weights. A cross-estimator check detects specification-sensitivity in the aggregation. When all three estimators agree, the paper is bulletproof; when they diverge, the authors have to explain why — and that explanation is itself informative.
**What would change my mind:** Report Table 1 with a second panel showing Sun-Abraham estimates for the same six cells (3 outcomes × 2 offices) using the same NYT comparison. If available, add a third column using Borusyak-Jaravel-Spiesschaert 2024. Cross-estimator agreement within roughly 10-20% for the three militia/prefeito coefficients would satisfy me.

### Concern 2: Magnitude interpretation is not policy-relevant

**Dimension:** 1 (Identification — external-validity arm) / weighted via AEJ:Applied POLICY bar
**Severity:** MAJOR
**Description:** The paper reports coefficients without (a) sample means of the outcomes, (b) benchmarks against the cross-municipality variation in Brazilian elections, (c) a policy-relevant unit of impact. Is an ENC drop of 0.459 a big effect? I don't know, because I don't know if mean ENC in this sample is 2.0 or 8.0. Is a 6.2 pp margin widening big? I don't know how variable margins are across Rio. Is HHI rising by 0.052 the difference between a competitive and a dominant-candidate polling station? The paper's own discussion (Section 5) says the magnitudes are "substantively meaningful" but provides no benchmarking.
**Why this matters:** AEJ:Applied readers evaluate applied-micro papers on whether the magnitude matters — not whether the t-statistic is above 2. A paper that cannot translate its coefficient into policy-relevant units has not cleared the bar. This is my critical-peeve lens: any claim about "policy implications" must be supported by the data's support range, and the paper's "policy implications" paragraph (last paragraph of Section 6) is untethered from the estimates.
**What would change my mind:** (a) Report the sample means and SDs of each outcome in a summary-statistics table (currently absent). (b) Benchmark the militia ATTs against cross-municipality variation: what percentile of the municipality-election ENC distribution does the effect correspond to? (c) Translate to a policy unit: if militia expansion widens the margin by 6.2 pp, how many Brazilian municipalities have a margin-of-victory below 6.2 pp? The answer tells the reader whether this effect would flip outcomes in competitive races. (d) A paragraph in Section 5 or 6 stating what the effect would look like if applied to a hypothetical non-militia mayor race at the median margin.

### Concern 3: Standard-error clustering level unspecified and likely wrong

**Dimension:** 3 (Inference)
**Severity:** MAJOR
**Description:** Treatment is defined at the polling-station level, but treatment ASSIGNMENT is at the polygon (faction-territory) level — all stations inside the same militia polygon receive treatment simultaneously when the polygon expands to enclose them. Under Abadie-Athey-Imbens-Wooldridge 2023 clustering-for-experimenters logic, SEs must cluster at the level of treatment assignment, which here is the polygon, NOT the station. The paper does not state its clustering level. CS-DID's default influence-function bootstrap clusters at the unit level (station) unless overridden. If the paper is using station-level clustering, SEs are likely understated.
**Why this matters:** Inference is one of five reduced-form dimensions. If clustering is wrong, the reported p-values and CIs are not defensible. This is a one-flag issue but a standard-issue concern for AEJ:Applied methods referees.
**What would change my mind:** (a) State the clustering level explicitly in Section 3.3. (b) Re-run the main specification clustering at the polygon level AND at the municipality level; report both in a robustness table. (c) If the SEs widen substantially under polygon clustering, the paper must update its significance claims. Ibragimov-Muller 2010 or wild-cluster bootstrap would be reassuring given the small number of polygons.

### Concern 4: Replication package not documented; AEA Data Editor compliance unclear

**Dimension:** 5 (Replication, AEJ:Applied re-weighted 5→15)
**Severity:** MAJOR
**Description:** The manuscript contains no reference to a replication package, data-availability statement, or access path for Fogo Cruzado territory maps. AEJ:Applied enforces the AEA Data and Code Availability Policy. The Data Editor reviews the package pre-acceptance and returns manuscripts with incomplete packages. Fogo Cruzado is a civil-society observatory; its data are licensed, not public-domain. The paper must disclose (a) whether the authors have permission to redistribute, (b) an exact access path readers can use to obtain the maps, (c) the code pipeline from raw polygons + TSE data to Tables 1-2.
**Why this matters:** This is a hard pre-acceptance requirement, not a referee preference. A paper that reaches AEA Data Editor review with no package will be returned.
**What would change my mind:** Add a Data and Code Availability footnote or section specifying: (a) that a replication archive will accompany publication, (b) the OpenICPSR or Zenodo DOI reservation, (c) the Fogo Cruzado access path and license terms, (d) the analysis software (presumably R, given the `did` package mention in footnote 1) and version. Provide the package for review with the revision.

### Concern 5: AEA table format (significance stars forbidden)

**Dimension:** 5 (Replication / presentation)
**Severity:** MAJOR (mechanical but binding)
**Description:** Tables 1 and 2 use `p<0.01`, `p<0.05`, `p<0.10` significance star conventions. AEA journal policy since 2023 forbids significance stars on grounds that they encourage dichotomous reading of continuous evidence. SEs in parentheses only; p-values or 95% CIs in table notes where needed. This is a mechanical fix but the paper as written does not match AEJ:Applied house style.
**Why this matters:** Format is a proxy for whether the authors have read the journal. A paper that ignores format signals that it is being shopped across journals.
**What would change my mind:** Remove the star system from Tables 1 and 2. Report 95% CIs in brackets instead of (or alongside) SEs. Update the notes accordingly.

### Concern 6: Honest-DiD / pre-trend-sensitivity bounds absent

**Dimension:** 1 (Identification) / 4 (Robustness)
**Severity:** MAJOR
**Description:** The paper defends parallel trends with Wald joint tests. Modern practice (Rambachan-Roth 2023, "HonestDiD") is to report sensitivity bounds: how large a linear pre-trend slope would have to be to overturn the sign or the significance of the headline estimate. Given that the Wald p-value for militia/prefeito HHI is 0.210 (not conclusive either way — no strong rejection, but not clean either), Honest-DiD bounds are exactly the tool needed to convince a skeptical reader.
**Why this matters:** The paper's identification argument is "pre-trends pass Wald tests." A more honest, defensible argument is "our headline estimate survives plausible deviations from parallel trends up to X." The latter is what AEJ:Applied methods referees increasingly expect.
**What would change my mind:** Apply the `HonestDiD` R package to the three militia/prefeito cells. Report the "breakdown" value M̄ — the maximum pre-trend deviation (in units of the maximum observed pre-period slope) under which the treatment effect remains statistically distinguishable from zero. If M̄ > 1, the paper is robust. If M̄ < 1, the authors must acknowledge the fragility.

## Minor suggestions

- State the R package version (`did` >= 2.1.2) and `set.seed()` used for influence-function bootstrap. Seed-dependent results without a stated seed are a replicability risk.
- Report covariate balance: are treated militia stations observably similar to NYT militia stations (future treated) on pre-period electoral, demographic, and geographic characteristics? A balance table is a standard DiD deliverable.
- Discuss the simple-aggregation vs. group-weighted (`aggte(type = "group")`) vs. calendar-time (`aggte(type = "calendar")`) choice. The simple aggregation gives more weight to earlier cohorts; the group aggregation weights cohorts equally. Readers should see both.
- The "stable Militia" / "stable Drug" classification from Monteiro et al. 2022 excludes switching stations. How many? A sample-construction table would help.
- Analytic weights by eligible voters: report in a robustness check what happens with unweighted estimates. Weights should move estimates modestly; if they flip signs, something is off.
- Appendix A's within-municipality demeaning: this is a non-standard DiD transformation and changes the estimand. Worth one sentence about what `y~imt` means under CS-DID's DGP.
- Multiple hypothesis testing: the paper runs 24 main estimates (3 outcomes × 2 offices × 2 faction types × 2 control groups). No MHT correction. Romano-Wolf or a simple Bonferroni note would discipline the narrative, especially for the null results.

## Positive observations

Under my constructive-peeve lens (unit-economics / policy translation), I do want to credit the paper for getting the mechanism story right: Section 5's discussion of why mayoral executive power matters for militia operations (security priorities, land-use regulation, municipal contracts) is the right economic-policy framing, and the Ferraz-Finan 2008 citation is well-placed. If the magnitude translation is fixed per Concern 2, the paper's policy narrative has the right shape. The choice of CS-DID with NYT-within-faction-type controls shows methodological discipline — the authors could have run TWFE and ignored the heterogeneity-bias literature, but they did not. The honest reporting of the vereador null under the main specification, and the resistance of most of the demeaning robustness check, both show scientific maturity that a POLICY referee should reward.


===========================================================================
# PART IV — SEVEN-PASS SYNTHESIS (unified checklist)
===========================================================================

*Note: the seven-pass review is journal-agnostic — identical across all 4 peer reviews (JOP, AEJApplied, JDE, AJPS). The master synthesis in Part I re-weights its findings against the specific journal bar.*

# Seven-Pass Review: Armed Factions and Local Electoral Competition

**Paper:** Pinho Neto & Rangel (April 2026), "Armed Factions and Local Electoral Competition: Evidence from Metropolitan Rio de Janeiro"
**Target journal:** *Journal of Politics* (JOP)
**Date:** 2026-04-18
**Manuscript path:** `papers/faccoes_competicao_politica.md` (assumed from seven-pass output dir)
**Lens reports:** `quality_reports/seven_pass_faccoes_competicao_politica/lens_1..7_*.md`

---

## Executive verdict

**REVISE-MAJOR.** The paper has a credible and genuinely novel design (staggered CS-DID on Fogo Cruzado territorial-expansion polygons, militia-vs-drug contrast on 4,180 polling stations, five election cycles), but its presentation, robustness battery, identification defense, and bibliography currently fall short of JOP's bar — seven lenses converged on an average score of ~5.1/10 with eighteen distinct CRITICAL flags. It is salvageable in one revision cycle because the scientific core looks right; what needs rebuilding is (i) the argumentation around endogenous faction expansion, (ii) the framing layer (abstract, intro, contribution statement), and (iii) standard 2026-era DiD hygiene.

---

## One-paragraph contribution statement

The paper claims that militia territorial expansion causally compresses local executive (mayoral, *prefeito*) electoral competition in metropolitan Rio de Janeiro — reducing the effective number of candidates by ~0.46, widening the winner's margin by ~6.2 pp, and raising vote concentration (HHI) by ~0.052 — while drug-trafficking faction expansion produces null effects on the same outcomes under the same design, and neither faction type affects open-list proportional *vereador* (city council) races. The contribution, never cleanly stated in the manuscript itself, is threefold: (i) the first use of annual georeferenced Fogo Cruzado territory polygons for causal identification of electoral effects; (ii) the first apples-to-apples militia-vs-drug contrast in a heterogeneity-robust staggered DiD design; and (iii) an institutional-channel finding — militias act on executive races, not PR races — consistent with the "capture of the executive" mechanism.

---

## Cross-lens CRITICAL issues

| # | Lens(es) | Issue | Recommendation |
|---|----------|-------|----------------|
| 1 | L4 | **Table 2 (Appendix A) is visibly misaligned** — row labels detached from cells, SE/Wald-p orphaned two rows below coefficients, NT/NYT panels scrambled. Publication blocker. | Rebuild Table 2 in LaTeX with three-row blocks (coef / SE / Wald-p) and explicit row labels on every row. ~10 minutes. |
| 2 | L7 | **Bibliography cites the same paper twice** under different author attributions — Hidalgo et al. (2025) and Pantaleão & Montini (2025) are the same *LAPS* article ("When elections empower crime"). Verified against Cambridge Core. | Resolve attribution, merge to single entry, delete double-cite in lines 39 and 104. ~15 minutes. |
| 3 | L1 | **Abstract has no numbers and no method named.** Body has "ENC falls by 0.46, margin widens 6.2 pp, HHI rises 0.052" — abstract has none of it. No mention of CS-DID, Fogo Cruzado, N=4,180, or time window. | Rewrite abstract with: question in Q1, method and data in S2, quantified findings in S3-4, one-sentence contribution in S5. L1 provides a model paragraph. |
| 4 | L2 | **Intro never poses the question, never previews magnitudes, never enumerates the contribution.** Opens with generic lit-review framing ("Criminal organizations control territory…"). Contribution paragraph is 6 lines of diffuse gesture. | Rewrite opening: question by line 25, numbered-contribution paragraph by line 55, roadmap at the end. L2 provides a model. |
| 5 | L3 | **Endogenous expansion / reverse causality.** The paper's own cited authority (Pantaleão & Montini; Hidalgo et al.) argues *elections cause militia expansion*, which is the reverse of the arrow the paper identifies. Pre-trends passing for 3 pre-periods is necessary, not sufficient. The load-bearing intellectual critique. | Add (a) a direct test that baseline competition does not predict cohort g, OR (b) a placebo at territory boundaries, OR (c) a mechanism-of-timing narrative defending why expansion is conditionally-exogenous at sub-cycle horizons. This is the R&R hinge. |
| 6 | L5 | **No Rambachan-Roth / Honest-DiD sensitivity.** For a post-2023 DiD paper, joint Wald pre-trends tests alone do not defend parallel trends — power against smooth violations is weak. At JOP this is a major referee request (less bar-critical than at QJE but still expected). | Add one `honestDiD::createSensitivityResults_relativeMagnitudes()` plot for each of three militia/prefeito estimates, report the M* breakdown threshold. |
| 7 | L5 | **No cross-estimator robustness.** Only CS reported; no Sun-Abraham, BJS, de Chaisemartin-D'Haultfœuille, Wooldridge ETWFE. For JOP less blocking than econ top-5, but modern DiD papers are expected to show ≥2 estimators. | Stack a second estimator column in Table 1; if any estimator diverges, investigate cohort. |
| 8 | L6 | **Register oscillates associational ↔ causal.** Abstract line 12 says "is associated with"; results lines 189, 335 say "reduces"; conclusion line 335 reverts to "is associated with." The authors themselves signal uncertainty about their identification. | Commit to "reduces / widens / compresses" throughout the main text; restrict "associated with" to the lit-review framing. |
| 9 | L6 | **Encoding mojibake** — `Pantale�o`, `mil�cia`, `Coordena��o`, em-dashes as `�` appear throughout the extracted text. CRITICAL **if present in the compiled PDF**; minor extraction artifact if not. | Verify UTF-8 encoding in LaTeX source (`\usepackage[utf8]{inputenc}` + lmodern, or XeLaTeX/LuaLaTeX). Spot-check the compiled PDF at lines 27, 39, 42, 72, 104, 301, 306, 349, 397. |

**Summary:** 9 CRITICAL cross-lens issues. Three of these (Table 2 misalignment, duplicate bibliographic entry, encoding) are mechanical and take well under an hour combined. The other six (endogenous expansion, abstract, intro, register, Honest-DiD, cross-estimator) are substantive and constitute the revision's core workload.

---

## MAJOR issues (second-round)

| # | Lens(es) | Issue |
|---|----------|-------|
| 1 | L4, L5 | **No event-study / dynamic ATT(g,t) plot.** CS produces this trivially via `aggte(type="dynamic")` + `ggdid()`. Standard JOP expectation; the joint Wald test is a summary of a figure the paper never shows. |
| 2 | L4 | **Magnitudes reported without baseline anchors.** "Nearly half a unit" and "6.2 pp" with no sample means for HHI, ENC, margin. Reader cannot judge whether ΔENC = −0.46 is a 12% or 20% effect. |
| 3 | L3, L5 | **SUTVA / spatial spillover not discussed.** Polygon contiguity → neighboring NYT controls plausibly contaminated. No donut-buffer robustness; no Conley / spatial-cluster SEs. |
| 4 | L3 | **Clustering level not stated.** With 20 municipalities, SEs need justification; territory-polygon is probably correct cluster, not station. With G < 50, wild-cluster bootstrap is expected. |
| 5 | L3 | **Simple aggregation undefended.** Why `aggte(type="simple")` and not `dynamic` or `group`? Simple upweights early cohorts, hides cohort heterogeneity. |
| 6 | L3, L5 | **No covariates, no defense of no-covariates.** CS allows conditional parallel trends. Station-level baseline controls (2008 HHI, turnout, muni × year FE alternative) should be tested. |
| 7 | L3 | **NT vs NYT pre-trends divergence underexplained.** NT p < 0.001 on all three; NYT passes. Paper dismisses in one sentence; reader suspects NYT is doing unspoken work. |
| 8 | L3 | **"Stable militia / stable drug" selection uncharacterized** (Monteiro et al. 2022 classification). How many switchers dropped? Are they a selected subset? |
| 9 | L3 | **Within-municipality demeaning robustness (Appendix A) is ad-hoc and the estimand it identifies is unclear.** Demeaning-then-CS is not formally justified; the correct solution is CS conditioned on muni × year covariates. |
| 10 | L5 | **Demeaned-vs-raw vereador contradiction unresolved.** Raw: null. Demeaned: HHI and margin *fall*. Paper dismisses demeaned as "exploratory" but leaves both in equally-formatted tables. Incoherent presentation. |
| 11 | L5 | **No placebo tests** despite 18 years of Fogo Cruzado territory data vs. only 5 elections used. Natural placebos (fake mid-cycle treatment, shifted polygons, pre-2008 outcomes) all absent. |
| 12 | L5 | **No MDE for drug-faction null.** "No comparable effects" claim is not backed by a power calculation showing the null can reject militia-sized effects. |
| 13 | L7 | **Ferraz & Finan (2008) miscalibration.** Cited at lines 74-75 and 329 for the claim that "a friendly mayor influences security priorities, land-use regulation, municipal contracts." FF08 is about audit-driven electoral accountability, not mayoral policy authority. Replace with Ferraz-Finan (2011 AER) or Brollo et al. (2013 AER). Cite-claim direction is wrong on a load-bearing citation. |
| 14 | L7 | **Fogo Cruzado missing from references entirely.** Main data source has no bibliography entry. Replication-blocking. |
| 15 | L7 | **Modern DiD methods literature not cited** — de Chaisemartin-D'Haultfœuille, Sun-Abraham, Goodman-Bacon, BJS, Roth (2022), Roth et al. (2023). At JOP, 2-3 of these in a methods footnote suffice; zero is a signal. |
| 16 | L7 | **Missing Brazilianist PolSci references** — Desposato (vote concentration measurement), Hidalgo's broader œuvre, Novaes (2018 JDE "Disloyal brokers"), Samuels. JOP editors will notice. |
| 17 | L7 | **Missing comparative crime-politics references** — Yashar (2018), Durán-Martínez (2018), Skarbek (2011/2014), Snyder & Durán-Martínez (2009). The last is the closest conceptual ancestor of the paper's mechanism. |
| 18 | L7 | **No replication package / data-availability statement.** JOP requires Dataverse deposit at acceptance. |
| 19 | L2 | **Within-muni demeaning apology occupies 7 lines of intro.** Pre-apologizing in the introduction for a non-standard robustness check signals that the main spec is weak. Move entirely to Section 5. |
| 20 | L2 | **Contribution not defended head-to-head** against Dell (2015), Blattman et al. (2024), Novaes (2023), Pantaleão-Montini (2025). Intro cites them but does not say "we differ from X because Y." |
| 21 | L4 | **Sample size disclosure incomplete.** N = 398 treated, 240 treated reported; N for NYT controls, NT controls, and total station-time cells not shown. |
| 22 | L6 | **Sparse topic sentences in Discussion** — §5.1, §5.2, §5.3 each open with a recap of Table 1 rather than a forward-moving interpretive claim. |
| 23 | L6 | **Passive-voice clusters** in results and conclusion ("Comparable effects are not detected for drug trafficking factions"). |
| 24 | L6 | **Missing space after period** — line 244: "provide the preferred causal estimates.Figure 2 displays…" |
| 25 | L1 | **Abstract/body mismatch on "what is treated"** — abstract says "territorial control shapes competition" (cross-sectional); body identifies effect of *newly entering* territory (temporal expansion). |
| 26 | L1 | **Null result on drug factions buried** in abstract as afterthought; this is one of the paper's two main contributions. |
| 27 | L1 | **Abstract vereador null is omitted entirely**, though it is a core institutional-channel finding in §5.3. |
| 28 | L3 | **Measurement reliability of Fogo Cruzado asserted, not defended.** If drug territories are underreported (covert) vs. militia (quasi-open), the drug null is partly measurement error — which would under-identify the militia-vs-drug contrast. |

---

## MINOR polish

- **L1 m1-m6:** abstract-level wording tweaks — "more able than" → "greater capacity than"; add "metropolitan Rio de Janeiro has 20 municipalities"; add D74 to JEL codes; swap "armed factions" keyword for "militias" for search findability.
- **L2 m1-m5:** replace generic opening ("Criminal organizations control territory…") with Rio-specific hook; define ENC as Laakso-Taagepera, margin as first-minus-second vote share in-text; state 2008-2024 election years in intro line 49.
- **L4 m1-m7:** clarify significance-star convention; fix Figure 2 shape/color distinction (grey triangles vs. black squares hard to see in B&W); note Panel A/B y-axis scale mismatch; state HHI scale (0-1 vs. 0-10000); state margin units (pp vs. decimal) on first use; differentiate Fig 2 vs Fig 3 captions.
- **L5 m1-m5:** add heterogeneity by urban/semi-rural, baseline-competition terciles, municipality population; report unweighted CS-DID as sensitivity; describe Fogo Cruzado methodology explicitly; show per-cohort pre-period length.
- **L6 m1-m8:** "rather than as" parallelism clean-up; swap one of two "Taken together" uses; move footnote 1 out of equation (1); verify `\\` before JEL/Keywords line in source.
- **L7 m1-m8:** add DOIs to all 19 entries; expand Dantas et al. (2023), Monteiro et al. (2022), Novaes (2023), Magaloni et al. (2020) citations to include working-paper numbers / volume-issue-pages; fix title case on "rio de janeiro" / "brazil"; spell out "et al." in Hidalgo et al. (2025); add accessed-date to TSE dataset.
- **L3 m1-m4:** report baseline means/SDs of HHI, ENC, margin in pre-treatment sample; add one paragraph on external validity (other Brazilian metros, PCC in São Paulo); report effect-size as fraction of outcome SD.

---

## Per-lens scorecard

| Lens | Critical | Major | Minor | Score/10 |
|------|----------|-------|-------|----------|
| 1. Abstract | 2 | 5 | 6 | 4.0 |
| 2. Intro | 3 | 5 | 5 | 5.0 |
| 3. Methods | 3 | 5 | 4 | 5.5 |
| 4. Results | 3 | 5 | 7 | 5.0 |
| 5. Robustness | 3 | 6 | 5 | 4.0 |
| 6. Prose | 3 | 8 | 8 | 6.5 |
| 7. Citations | 1 | 8 | 8 | 5.5 |
| **Overall** | **18** | **42** | **43** | **~5.1** |

**Interpretation:** Scores cluster between 4 and 6.5 — no lens rates the paper as submission-ready, but none rates it as unsalvageable either. The two weakest lenses (Abstract 4.0, Robustness 4.0) are both cheaply improvable: the abstract needs a rewrite with numbers (one afternoon), and robustness needs standard 2026-era DiD diagnostics (1-2 days of R work with the `did` and `honestDiD` packages).

---

## Revision plan (in recommended order)

Ordered by leverage — "minutes-of-effort × manuscript-tier-impact":

1. **Fix Table 2 misalignment** (L4 C1). Publication blocker. ~10 minutes in LaTeX source.
2. **Fix bibliography duplicate Hidalgo/Pantaleão** (L7 C1). Desk-reject-adjacent issue. ~15 minutes.
3. **Add Fogo Cruzado to references** (L7 M7). Replication-blocking data citation. ~5 minutes.
4. **Address endogenous-expansion threat** (L3 C1). *The load-bearing intellectual fix.* Either (a) show baseline HHI/ENC/margin do not predict cohort g, (b) placebo at territory boundaries (donut buffer), or (c) a clean mechanism-of-timing narrative in §2 arguing that annual expansion decisions are conditionally-exogenous at sub-cycle horizons. Without this the causal claim is not defensible for JOP.
5. **Rewrite abstract** (L1 C1-C2) with question-first, method named, three quantified findings, one-sentence contribution. L1 provides a model. ~1 hour.
6. **Rewrite introduction** (L2 C1-C3) — question by line 25, magnitudes in preview, enumerated 3-point contribution, head-to-head vs. Dell/Blattman/Novaes/Pantaleão, roadmap at end. Remove the 7-line within-muni-demeaning apology. L2 provides a model. ~1 afternoon.
7. **Commit to causal register** throughout (L6 C3). Global find-and-replace: "is associated with" → "reduces / compresses / widens" in all results/discussion/conclusion; reserve hedged verbs for the lit-review framing only. ~30 minutes.
8. **Fix Ferraz-Finan miscalibration** (L7 M1). Replace FF08 with FF11 (AER) or Brollo et al. (2013 AER) at lines 74-75 and 329. Cite-claim direction is currently wrong. ~15 minutes.
9. **Add at least one cross-estimator robustness** (L5 C2). Sun-Abraham or BJS, stacked as a second column in Table 1. ~2 hours of R work.
10. **Add Honest-DiD / Rambachan-Roth sensitivity** (L5 C1). One plot for each militia/prefeito estimate showing M* breakdown. ~1 hour with `honestDiD` package.
11. **Add proper event-study plot + ATT(g,t) table** (L4 M1, L5 C3) via `aggte(type="dynamic")` + `ggdid()`. ~1 hour.
12. **Add SUTVA / spatial spillover paragraph + donut-buffer robustness** (L3 M2, L5 M2). ~3 hours with Conley SEs.
13. **Add baseline descriptive-stats table** — pre-treatment means/SDs of HHI, ENC, margin by treatment group — so magnitudes have anchors (L3 m1, L4 M2). ~30 minutes.
14. **State clustering level explicitly + wild-cluster bootstrap for G < 50** (L3 C2). ~1 hour.
15. **Resolve demeaned-vs-raw vereador contradiction** (L4 M3, L5 M1). Either defend raw null and move demeaned to text paragraph, or take demeaned result seriously and rewrite §5.3. Paper cannot currently have both. ~1 hour of thinking.
16. **Encoding audit on compiled PDF** (L6 C1). Fix `\usepackage[utf8]{inputenc}` or switch to Xe/LuaLaTeX. ~15 minutes.
17. **Bibliography cleanup** (L7 MAJOR/MINOR batch) — DOIs added; modern-DiD methods footnote with 3-4 cites; Brazilianist additions (Desposato, Hidalgo's broader work, Novaes 2018 JDE); comparative-crime additions (Yashar, Durán-Martínez, Skarbek, Snyder-Durán-Martínez); title case. ~3 hours.
18. **Extend manuscript from 11 pp to 20-30 pp** (L6 §3 / structural for JOP). JOP typical length is 20-40 pages; 11 pp reads as a short Letter. Added material flows naturally from items 4, 9-12, 15 (methodology, robustness, discussion of spillovers, mechanism defense). This is the structural move from "field-journal short note" to "JOP-length article."

Items 1-3 and 7-8 are mechanical and can be done in half a day. Items 4-6 are the intellectual core of the revision. Items 9-12 are the standard 2026 DiD hygiene battery. Item 18 is the format/length shift that makes this a JOP article rather than a Letter.

---

## Contradictions between lenses

**Contradiction 1 — magnitude reporting in prose.** L1 (Abstract) urges the paper to *add* quantified findings everywhere; L6 (Prose) urges trimming long sentences and tightening topic sentences, which cuts against adding numbers into already-long constructions. Resolution: add numbers in short separate sentences, not in expanded compound sentences.

**Contradiction 2 — how seriously to take the demeaned spec.** L3 (Methods) treats within-municipality demeaning as ad-hoc and wants it replaced with covariate-conditioning CS; L5 (Robustness) wants the demeaned vereador result *taken more seriously*, arguing the paper cannot both dismiss it as "exploratory" and privilege the raw null on institutional grounds. Resolution: these are the same critique viewed from two sides — the demeaned spec either identifies a well-defined estimand (then its vereador result is a real finding) or it does not (then drop it). The paper must pick.

**Contradiction 3 — QJE vs. JOP framing.** L2, L5, L6 explicitly calibrate to QJE; L7 calibrates to JOP (the correct target). Where the QJE-calibrated lenses make maximal demands ("no single estimator reported at QJE is acceptable", "intro is thin for top-5"), the JOP-calibrated reading softens: JOP expects credible identification + political-theoretic contribution, not econ top-5 identification obsession. I have re-weighted the synthesis toward JOP throughout: Honest-DiD and cross-estimator checks are MAJOR (not blocking) for JOP; bibliography completeness and Brazilianist breadth are upweighted; econ-style robustness gauntlet is downweighted.

**Contradiction 4 — paper length.** L6 calls 11 pp "very short" (QJE-framed, where 30-50 pp is typical). For JOP the typical length is 20-40 pp, so 11 pp is still very short but the gap is smaller. Revision plan item 18 is calibrated to JOP's length norm.

---

## JOP-specific framing note

This paper sits at the intersection that JOP exists to publish: credible identification + political-theoretic contribution on a question of consequence for democratic politics in the Global South. The lens findings map to JOP's bar as follows.

**The identification design is CREDIBILITY-sufficient for JOP** as-is. Staggered CS-DID with NYT-same-faction-type controls is a defensible, modern research design; joint Wald pre-trends tests pass; the paper correctly avoids the NT-controls trap. A political science audience will not demand the full econ top-5 identification gauntlet (Honest-DiD, multiple estimators, Conley SEs, donut buffers). Those are *upgrades* for revision, not desk-reject-level omissions.

**Where the paper currently falls short of JOP's bar is theoretical-framing and mechanism defense, not econometrics.** Three specific JOP-shaped issues:

1. **No explicit political-theoretic contribution paragraph.** JOP editors want to know what the paper *argues* about democratic politics, armed groups, and the state — not just what coefficient it estimates. The current contribution statement is diffuse (L2 C3). A JOP revision needs one paragraph naming the theoretical claim — e.g., "militia territoriality converts into electoral capture because the militia-state relationship is institutional (bureaucratic appointments, law-enforcement priorities, land-use regulation), whereas the drug-state relationship is adversarial and cannot support symmetric capture; this institutional asymmetry generates the testable prediction our design confirms."

2. **Cleaner engagement with the nearest-neighbor political science.** The bibliography misses Pantaleão-Montini (actually cited twice under wrong attribution — see L7 C1), Hidalgo's broader Brazilian œuvre, Novaes's earlier JDE work on disloyal brokers, plus the comparative crime-politics canon (Yashar, Durán-Martínez, Trejo-Ley, Snyder-Durán-Martínez, Skarbek). A JOP referee will notice the Brazilianist political-science reference gap immediately.

3. **Mechanism-of-militia-expansion argument that defends against the reverse-causality critique** (L3 C1). This is the R&R move most likely to be requested by a sharp JOP referee: the cited literature argues *elections cause expansion*, while this paper argues *expansion causes electoral compression*. Both can be true, but the paper must argue — in institutional, mechanistic, sub-annual-timing language — why the arrow it identifies is not a relabeling of the arrow the Pantaleão-Hidalgo paper identifies. Currently this is not done.

**Bottom line for JOP.** The paper is a REVISE-MAJOR candidate, not a reject. The empirical core is right. The framing layer (abstract, intro, contribution statement, register) needs a rewrite. The mechanism defense against endogenous expansion is the load-bearing intellectual fix. Standard 2026 DiD hygiene (Honest-DiD, cross-estimator, event-study plot, SUTVA discussion) are expected upgrades but not desk-reject-level. The bibliography needs a serious clean-up. With ~2-3 weeks of focused revision the paper can plausibly clear the JOP bar.

---


===========================================================================
# PART V — SECTION-BY-SECTION DEEP DIVES (7 LENS REPORTS)
===========================================================================

## Lens 1 — Abstract

# Lens 1 — Abstract Audit

**Paper**: Armed Factions and Local Electoral Competition
**Lens**: Abstract
**Date**: 2026-04-18

## Overall assessment

The abstract (lines 10-18) is short, grammatical, and broadly faithful to the body, but it fails three of the four lens tests. It names the topic and direction of the main finding, yet it does not state the research question as a question, does not name the method or data, does not quantify the headline result (no effect sizes, no N, no time window, no geography), and does not articulate a one-sentence contribution. A reader scanning JEL D72/K42/O17 bins or the NBER "new this week" list cannot tell from this abstract what is novel relative to Pantaleao & Montini (2025), Hidalgo et al. (2025), or Novaes (2023) — all cited as adjacent work in the introduction. For a paper with a credible design (staggered CS-DID on 4,180 polling stations across 5 elections and 18 years of Fogo Cruzado territory maps) and clean pre-trends on the headline result, the abstract is leaving most of the paper's selling points on the table.

The cross-check against the body also surfaces one substantive inconsistency: the abstract says the paper examines "how armed faction territorial control shapes local electoral competition," but the actual identifying variation is *temporal expansion* of already-existing territory — the paper estimates the effect of a station *newly entering* faction control, not the cross-sectional effect of territorial control per se. This is a real distinction (Section 3.3 lines 49-53, 156-159) and the abstract should match.

## Issues found

### CRITICAL

1. **No quantification of the headline result** — The abstract states that under militia expansion "vote concentration rises, the effective number of candidates falls, and the margin of victory widens" (lines 13-14) with zero numbers attached. This is the single biggest problem. The body delivers clean magnitudes that are both substantively meaningful and JEL-D72-audience-appropriate: from Table 1 (NYT, prefeito, militia) HHI +0.052, ENC -0.459, margin +6.2 pp; and the Discussion (lines 296-298) already uses the phrasing "the effective number of candidates falls by nearly half a unit, and the winning candidate's lead over the runner-up is 6.2 percentage points wider at militia-controlled stations." That exact sentence belongs in the abstract. **Fix**: Replace the vague triple with "the effective number of prefeito candidates falls by 0.46, the margin of victory widens by 6.2 percentage points, and vote concentration (HHI) rises by 0.052; all three estimates pass joint pre-trends tests."

2. **Method and data are not named** — The abstract never says "difference-in-differences," "Callaway-Sant'Anna," "Fogo Cruzado territory maps," "polling-station level," or gives a sample size or time window. A reader cannot tell whether this is ethnography, a cross-sectional regression, an event study, or a structural model. For a methodologically-driven paper this is a critical omission. **Fix**: Add one sentence along the lines of "Using annual Fogo Cruzado territory maps (2007-2024) matched to 4,180 polling stations across five municipal elections (2008-2024), we implement the Callaway-Sant'Anna (2021) staggered difference-in-differences estimator, comparing newly treated stations to not-yet-treated stations of the same faction type."

### MAJOR

1. **First sentence is descriptive, not a question** — "This paper examines how armed faction territorial control shapes local electoral competition in the metropolitan area of Rio de Janeiro" (lines 11-12) is fine English but not the kind of opening that the lens rubric (and top-field editors) reward. The actual question the paper answers is sharper and comparative: *do different types of armed organizations exert different forms of electoral influence, and does territorial control causally reduce mayoral competition?* The introduction (lines 28-30) even poses it as a question in its own words: "how the expansion of armed territorial control over time affects electoral competition — and whether different types of armed organizations exert distinct forms of political influence." Lift that into the abstract. **Fix**: Open with "Do different types of armed factions exert distinct forms of electoral influence as their territorial control expands?"

2. **No explicit one-sentence contribution** — The abstract has a "findings suggest…" sentence (lines 15-16) but no contribution sentence differentiating this paper from its two closest neighbors: Pantaleao & Montini (2025), cited four times in the body and characterized as "when elections empower crime: political protection and militia expansion in Rio de Janeiro," and Hidalgo et al. (2025) with essentially the same title. A skeptical reader of the abstract will reasonably ask: isn't this just a restatement of Pantaleao-Montini? The contribution is in fact distinct — this paper exploits *staggered temporal expansion* with a heterogeneity-robust DiD estimator on polling-station-level electoral outcomes, not municipality-level protection/selection, and it *contrasts* militias with drug factions in the same design. That deserves an explicit sentence. **Fix**: Add "Relative to prior work documenting political protection flows from state to militias, we quantify the reverse channel — how militia territorial expansion causally compresses electoral competition in mayoral races — and show that drug-trafficking factions do not exhibit comparable effects under the same design."

3. **Abstract/body mismatch on "what is treated"** — The abstract says "armed faction territorial control shapes local electoral competition" and "militia expansion is associated with lower competition" (lines 11-13). The body is clear that the design identifies effects of a polling station *newly entering* faction territory (staggered cohort, line 52: "as territories grow over successive elections, new polling stations come under faction control at different times"). The abstract's phrase "territorial control shapes" reads as a cross-sectional claim. **Fix**: Use "territorial expansion" rather than "territorial control" in the opening sentence, matching the identifying variation exactly.

4. **"Associated with" vs. causal language is inconsistent with the body's stance** — The abstract uses the hedged phrase "militia expansion is associated with lower competition" (line 12), but the body repeatedly makes causal claims once pre-trends pass: "provide the preferred causal estimates" (line 243-244), "the survival of the militia/prefeito result under within-municipality demeaning… reinforces the interpretation that the effect is not driven entirely by cross-municipality composition" (lines 247-248), and the conclusion (lines 335-336) says "militia territorial control is associated with lower mayoral competition… All three competition measures… pass pre-trends diagnostics." Pick one register and hold it. Given that three of three pre-trends tests pass at the NYT-preferred specification and the within-municipality robustness survives, the paper has earned "reduces" in the abstract rather than "is associated with." **Fix**: Replace "is associated with lower competition" with "causally reduces competition" OR commit to "is associated with" throughout — the current mismatch reads as rhetorical uncertainty.

5. **Null result on drug factions is underplayed** — The abstract says "We do not detect comparable effects for drug trafficking factions" (line 14), which reads as an afterthought. This is actually one of the paper's two main contributions (a rare apples-to-apples faction-type contrast with clean identification). The contrast should be foregrounded with numbers showing the magnitudes diverge (HHI for drug factions: -0.003 vs. militia +0.052; ENC: +0.100 vs. -0.459; margin: +0.004 vs. +0.062 — Table 1, NYT, prefeito). **Fix**: "The same estimator applied to drug-faction expansion produces null effects on all three outcomes (e.g., HHI +0.052 for militia vs. -0.003 for drug factions), indicating that the electoral-competition channel is specific to militias."

### MINOR

- Line 14: "We do not detect comparable effects for drug trafficking factions" — clunky. "Comparable effects are absent for drug-trafficking factions" is cleaner.
- Line 15: "Taken together, the findings suggest that militias are more able than drug factions to translate territorial dominance into electoral advantage in local executive contests" — "more able than" is awkward; "militias, but not drug-trafficking factions, translate territorial dominance into electoral advantage in mayoral contests" is tighter and swaps in "mayoral" which is more recognizable to non-Brazil readers than "local executive contests."
- Abstract never says "metropolitan Rio de Janeiro" has 20 municipalities (body, line 144) — minor but cheap to add and helps external validity judgments.
- Null result on vereador races deserves a half-clause; right now the abstract pretends vereador is not in the paper, but Table 1 Panel B and a full Discussion subsection (5.3, lines 324-331) are devoted to it. Saying "effects concentrate on mayoral races and are absent from proportional-representation city-council races" actually *strengthens* the institutional-channel interpretation and pre-empts a referee question.
- JEL codes D72 (Political Processes), K42 (Illegal Behavior), O17 (Formal/Informal Institutions) are appropriate. Consider adding D74 (Conflict/Conflict Resolution) since the paper's ambit straddles that code.
- Keyword "armed factions" duplicates "organized crime"; consider swapping one for "militias" or "Brazil" to improve search findability.

## Model abstract (if rewriting would help)

> Do different types of armed factions exert distinct forms of electoral influence as their territorial control expands? We study metropolitan Rio de Janeiro (2008-2024), where paramilitary militias and drug-trafficking organizations jointly control a large share of neighborhoods but differ sharply in their relationship with the state. Using annual Fogo Cruzado territory maps (2007-2024) matched to 4,180 polling stations across five municipal elections in 20 municipalities, we implement the Callaway-Sant'Anna (2021) staggered difference-in-differences estimator, comparing newly treated stations to not-yet-treated stations of the same faction type. Militia territorial expansion causally reduces mayoral (prefeito) competition on all three standard measures: the effective number of candidates falls by 0.46, the margin of victory widens by 6.2 percentage points, and vote concentration (HHI) rises by 0.052, with clean pre-trends and survival under within-municipality demeaning. Drug-faction expansion produces null effects on the same outcomes under the same design, and neither faction type affects open-list proportional city-council races. Relative to prior work documenting political protection flowing from elected officials to militias, we quantify the reverse channel — how militia territorial expansion causally compresses electoral competition in mayoral races — and provide the first apples-to-apples contrast of militia vs. drug-faction electoral effects in a heterogeneity-robust design.

(~175 words, fits most journal limits; trim the final sentence to ~120 for AER/QJE.)

## Score: 4/10

Two CRITICAL misses (no quantification, no method/data), five MAJOR issues (weak opener, no contribution sentence, treated-unit mismatch, causal-vs-associational inconsistency, buried null contrast), and an inviting set of MINOR polishes. The abstract is not broken — it is faithful to the findings and grammatical — but it is doing about 40% of the work it should. With 30 minutes of revision this can get to 8/10, because the body already contains every number and every framing the abstract needs.


## Lens 2 — Intro

# Lens 2 — Introduction Structure

**Paper:** Pinho Neto & Rangel, "Armed Factions and Local Electoral Competition" (April 2026)
**Lens:** Introduction architecture vs. Cochrane/Varian canonical framework
**Target audience calibration:** QJE / AER level
**Scope reviewed:** lines 20–75 (Section 1, "Introduction")

---

## Overall Assessment

The introduction is **structurally underweight for a top-5 submission**. At roughly 56 lines of text (lines 20–75), it reads like a competent field-journal opener (AJHE / JDE / EJ-Applied) but does not execute the Cochrane "Hook → Question → Why-we-care → What-we-do → What-we-find → Contribution" arc that QJE/AER introductions are expected to perform. The most serious deficiency is that **the paper never poses "the question" as a question** — it opens with a literature framing sentence (lines 22–24: "Criminal organizations control territory, regulate daily life, and shape electoral outcomes across the developing world") and then pivots into a lit-review paragraph (lines 22–30) before readers are told what the paper is asking or why it matters. This is the classic Varian anti-pattern: lit review before hook.

A second structural problem: **magnitudes are absent from the preview of findings**. Lines 55–59 report direction only ("vote concentration increases, the effective number of candidates falls, and the margin of victory widens") with no point estimates, no units, no effect sizes, and no benchmark comparisons. A QJE introduction is expected to tell the reader, in the first three pages, what the ATT is in percentage points, how it compares to a natural benchmark (a standard deviation, a policy-relevant threshold, the treatment effect in the nearest comparable paper), and why it is economically meaningful. Here the reader must wait until Section 4 to learn whether the militia effect is 2 percentage points or 20. Third, **contribution is not enumerated** — there is no "We make three contributions" paragraph, only a single diffuse paragraph (lines 70–75) that gestures at related literature without staking a claim. For the paper's ambition (novel Fogo Cruzado data, staggered Callaway-Sant'Anna on 4,180 stations, militia-vs-drug heterogeneity that nobody has cleanly isolated), the intro *underclaims* what the paper actually does. Overall: the science appears solid but the framing is written as if for an area-studies journal, not a top-5.

---

## Issues by Severity

### CRITICAL

**C1. No question is ever posed.**
Lines 22–30 move from a generic opening ("Criminal organizations control territory…") to a lit-review paragraph to a half-statement of the gap ("Yet less is known about how the expansion of armed territorial control over time affects electoral competition"). The word "we ask" or "this paper asks" never appears. A QJE reader at line 30 cannot tell you in one sentence what the paper's research question is. The gap-sentence (lines 28–30) is hedged and passive ("less is known") rather than declarative ("Does militia territorial expansion reduce electoral competition? And do drug factions behave differently?"). **Fix:** one sharp interrogative sentence by line 25 at the latest.

**C2. Preview of findings has direction but zero magnitude.**
Lines 55–59: "militia territorial expansion reduces prefeito competition on all three measures: vote concentration increases, the effective number of candidates falls, and the margin of victory widens." This is a direction-only sentence. There is no ATT, no standard error, no share of a standard deviation, no "X percentage points off a baseline of Y." For a Callaway-Sant'Anna design with three outcomes and two faction types, the intro should carry a six-number summary (ATT + SE for militia × {HHI, ENC, MoV}) with the three null drug-faction estimates alongside. **This is the single most fixable weakness of the introduction.** Without magnitudes the reader cannot calibrate whether the militia effect is economically material or a precisely-estimated zero dressed up as a finding.

**C3. Contribution paragraph is missing.**
Lines 70–75 ("These findings contribute to the literature on criminal governance and democratic politics…") is the only contribution paragraph. It is 6 lines, cites 4 papers, and never enumerates what is new. For a QJE submission the contribution paragraph should be (a) numbered (1, 2, 3), (b) defensible against the three closest predecessors (Dell 2015, Blattman et al. 2024, Novaes 2023, Pantaleão & Montini 2025), and (c) explicit about what the paper does that those predecessors do not. As written, a referee cannot tell whether the contribution is (i) the Fogo Cruzado territory data, (ii) the staggered DiD on territorial expansion, (iii) the militia-vs-drug heterogeneity, or (iv) all three. Likely the answer is (iii) — **the cleanest militia-vs-drug contrast in the literature on a sharp, geocoded treatment** — but the paper never says so.

### MAJOR

**M1. Lit review is front-loaded, not back-loaded.**
Lines 22–30 and lines 32–39 together constitute ~15 lines of lit-review before the question is stated or the contribution is made. Cochrane's rule ("No literature review in the introduction. None. Zero.") is violated. Varian's more permissive version still requires the lit review to come *after* the contribution, to position it. Here the lit review is doing the work of the hook — and because the hook is borrowed from other papers, the intro never develops its own voice. **Fix:** compress lines 22–30 into a two-sentence hook that poses the question; move the Dell/Blattman/Novaes discussion to a dedicated "Related Literature" subsection at the end of Section 1 or to Section 2.

**M2. Militia-vs-drug distinction is explained, but the *why-it-matters-for-your-design* is buried.**
Lines 32–39 introduce the two faction types and their institutional differences, which is good and comes early enough. But the crucial implication — **that militias should show electoral effects and drug factions should not, which is exactly what the paper finds** — is never stated as an *ex-ante* prediction in the intro. This is a missed opportunity: the paper has a clean pre-registered-style heterogeneity prediction and the data confirm it, but the intro frames it as a post-hoc observation (lines 70–75). **Fix:** at line 39, add one sentence: "This institutional asymmetry generates a testable prediction — militia expansion should compress local electoral competition; drug-faction expansion should not — which we bring to the data." This converts the heterogeneity result from a descriptive fact into a theory-consistent finding.

**M3. The "within-municipality demeaning" apology (lines 61–68) does not belong in the intro.**
Seven lines (11% of the entire introduction's text!) are spent pre-apologizing for a robustness check that "is not a standard baseline specification in the literature." This is a self-inflicted credibility wound. Referees read this paragraph and think: "If the authors need to spend 7 lines in the intro defending a non-standard robustness check, what is wrong with the main specification?" A QJE intro should carry the main result and a one-sentence "results survive within-municipality variation (Appendix X)." The extended methodological hedging belongs in Section 5 (Robustness) — not here. **This paragraph alone costs the paper roughly one full journal tier.**

**M4. Contribution claim is not credible for QJE/AER as written.**
The intro does not defend novelty against the nearest predecessors:
- **Dell (2015)** — drug war spillovers and electoral outcomes in Mexico. Not cited in the intro. Should be.
- **Blattman et al. (2024)** — criminal governance in Medellín. Cited at line 25 but not differentiated.
- **Novaes (2023)** — cited (lines 25, 27) but the differentiation is vague ("electoral alliances may reinforce rather than constrain criminal governance").
- **Pantaleão & Montini (2025)** — cited twice (lines 27, 39) but treated as a companion rather than a predecessor to be distinguished from.

For a QJE referee, the novelty claim needs a head-to-head: "Novaes (2023) shows that X. We show Y, which differs because Z." The paper's natural distinction is *the staggered, territorial-expansion design on georeferenced polygon data* — no prior paper has this treatment definition. But the intro never says so.

**M5. Roadmap is missing entirely.**
There is no "The paper proceeds as follows. Section 2 describes institutional context, Section 3 introduces the data…" paragraph. This is standard in AER/QJE and its absence signals either a preprint that has not been polished or an author unfamiliar with the target-journal conventions. One-paragraph fix.

### MINOR

**m1.** Line 22 ("Criminal organizations control territory, regulate daily life, and shape electoral outcomes across the developing world") is a *very generic* hook. It could open any of 40 papers in the organized-crime-and-politics literature. Replace with a Rio-specific, paper-specific hook (e.g., "By 2024, militia-controlled territories in metropolitan Rio de Janeiro covered a larger area than drug factions — and housed roughly X million voters. How does this expansion reshape who wins local elections?"). The institutional fact is already in the paper at line 88.

**m2.** Line 47 begins Section 1.1 (implicitly) — "We use annual territory maps…" — without a transition. Either add a subsection header ("Design preview") or a bridging sentence so the reader knows the intro is now describing the empirical strategy.

**m3.** The three competition measures are named in lines 56–58 but not defined in the intro. A QJE reader should learn in the intro that ENC is Laakso-Taagepera and that MoV is first-minus-second-vote-share. One parenthetical each would suffice.

**m4.** No mention in the intro that the Fogo Cruzado territory maps are (apparently) *novel to this paper* — that is, no prior published work has used this data for causal identification of electoral effects. If true, this is the single strongest contribution and should be stated explicitly around line 47.

**m5.** The intro never states the *sample period* (2008–2024, five elections) until line 49 — fine — but the election years themselves (2008, 2012, 2016, 2020, 2024) are only given much later (line 133). Add them in line 49 for transparency.

---

## Model Opening Paragraph (illustrative rewrite)

The following is offered as a target for what a QJE-bar opening could look like. It keeps the paper's substance but front-loads the question, the design, the magnitude, and the enumerated contribution.

> By 2024, paramilitary militias in metropolitan Rio de Janeiro controlled a larger territory than the city's three drug trafficking factions combined, encompassing polling stations that collectively served roughly [X] million voters. **Does this territorial expansion shape who wins local elections — and do militias and drug factions exert distinct forms of political influence?** Existing work documents that organized crime can reduce turnout and distort candidate selection (Dell, 2015; Blattman et al., 2024; Novaes, 2023), but no causal estimate isolates the *temporal* effect of territorial expansion or disaggregates by faction type.
>
> We combine annual georeferenced territory maps from Fogo Cruzado — the first dataset to trace the boundaries of individual armed-group polygons year by year — with polling-station-level returns for five municipal elections (2008–2024) across 4,180 stations. Our identification exploits the staggered temporal expansion of faction territories: as militias and drug factions absorb new areas across election cycles, previously untreated polling stations become treated at different times. We estimate heterogeneity-robust ATTs (Callaway and Sant'Anna, 2021) separately by faction type.
>
> **Three findings.** First, militia territorial control reduces prefeito (mayoral) competition by [XX] percentage points of HHI (SE = [YY]) — equivalent to roughly [Z] percent of a standard deviation — with concordant effects on the effective number of candidates (−[A]) and margin of victory (+[B] pp). Second, drug-faction expansion shows no comparable effects: all three ATTs are precisely-estimated nulls (< [C] pp, SE = [D]). Third, vereador (city council) races, whose political geography differs fundamentally from mayoral races, show no significant effects for either faction. Pre-trends tests pass in all three mayoral specifications and survive within-municipality demeaning (Appendix [X]).
>
> **We make three contributions.** (i) We provide the first causal estimate of armed-territorial expansion on local electoral competition using a staggered, heterogeneity-robust DiD on a novel georeferenced treatment. (ii) We document a sharp asymmetry between militia and drug-faction political influence — consistent with institutional differences in how the two groups interact with the state (Lessing, 2017; Barnes, 2022) — which prior work has conjectured (Hidalgo et al., 2025; Pantaleão and Montini, 2025) but not identified in a unified design. (iii) We show that militia effects concentrate in executive races, where a friendly mayor controls security priorities and land-use regulation, rather than in city council races — consistent with the "capture of the executive" mechanism emphasized in Ferraz and Finan (2008).
>
> The remainder of the paper proceeds as follows. Section 2 describes the institutional context. Section 3 introduces the data and identification strategy. Section 4 reports main results. Section 5 presents robustness. Section 6 discusses mechanisms and concludes.

Note how this rewrite: (i) poses the question in sentence two, (ii) previews magnitudes with square-bracket placeholders (fill from Table 2), (iii) enumerates three contributions, (iv) defends novelty against the four closest predecessors, (v) adds a roadmap, and (vi) moves the lit review *after* the contribution rather than before the question.

---

## Score: 5 / 10

**Breakdown:**
- Hook poses the question: **2/10** — no question is ever posed; opens with generic lit-review framing.
- Cochrane/Varian ordering: **3/10** — lit review front-loaded; contribution buried; roadmap missing.
- Magnitudes in preview: **1/10** — direction only, zero numbers.
- Contribution enumeration: **3/10** — diffuse single paragraph; not numbered; not head-to-head vs. predecessors.
- Militia-vs-drug clarity: **8/10** — well-executed in lines 32–39; the one genuinely strong element.
- Defensibility vs. prior lit: **5/10** — cites the right papers but does not stake differentiated claims.
- QJE/AER calibration: **4/10** — reads as a strong field-journal intro (AJHE/JDE would accept as-is); below the bar for top-5.

**Weighted overall: 5/10.** The science sounds like a 7–8 paper; the introduction is framed like a 4–5 paper. Rewriting the intro along the lines sketched above is arguably the highest-ROI revision the paper can make — it requires no new data work, no new estimation, and roughly one afternoon of writing. Paired with plugging in actual ATT magnitudes from Table 2, it could lift the intro to an 8/10 without touching any of the empirical work.

---

*Word count: ~1,950.*


## Lens 3 — Methods

# Seven-Pass Review — Lens 3: Methods / Identification

**Paper:** Pinho Neto & Rangel, "Armed Factions and Local Electoral Competition: Evidence from Metropolitan Rio de Janeiro" (April 2026)
**Reviewer:** domain-reviewer agent (Lens 3 — the killer-referee-question lens)
**Date:** 2026-04-18

---

## Overall Assessment

The paper deploys Callaway–Sant'Anna (CS) with the NYT-same-faction-type comparison group — a thoughtful choice, because it strips out the most obvious violation of parallel trends (factions-enter-Rio-neighborhoods-that-differ-from-median-Rio-neighborhoods). The core design — comparing polling stations that come under militia control in cycle t against polling stations that will come under militia control in cycle t+k — is the cleanest feasible contrast this data environment allows, and the authors deserve credit for noticing that the NT comparison is not that contrast. The joint Wald pre-trend tests mostly clear under NYT, which is directionally reassuring; and the NT–NYT divergence in pre-trends is itself a diagnostic about where the threatened confounding lives.

That said, the paper is **one good critique away from a desk reject at QJE/AER** on identification grounds, and I believe the critique is: *faction territorial expansion is almost surely not exogenous to local political configuration*. Militias are institutionally, temperamentally, and financially tied to local political machines — Hidalgo et al. (2025) and Pantaleão & Montini (2025), both cited by the authors, argue precisely that elections CAUSE militia expansion. The identifying assumption required by CS in this setting is parallel trends in electoral competition at the polling-station level between newly-treated and not-yet-treated stations *of the same faction type* — conditional on group. Pre-trends tests are necessary but not sufficient for this. The paper needs to confront the reverse-causality / endogenous-expansion story head-on, and currently does so only glancingly (Section 2, institutional paragraph). Simple aggregation, no covariates, and unstated clustering compound the concern. Effects are modest in magnitude (HHI +0.052 on an unreported baseline) and the 20-municipality cluster count is a real inferential problem if the authors are clustering at municipality; if they are clustering at station, that is a potential under-coverage problem because treatment varies at the territory level, not station level. **Score: 5.5/10** — design is defensible and well-chosen, but pre-trends tests alone cannot carry the identification claim the paper makes, and too many design choices are under-argued.

---

## CRITICAL Issues

### C1. Endogenous faction expansion — the parallel-trends assumption is not credible without further defense

**Anchor:** Section 3.3 lines 156–179; Introduction lines 49–53; Section 2 lines 98–106.

The identifying assumption under CS–NYT is: conditional on group g (cohort of first entry into faction territory) and same faction type, the expected evolution of outcomes (HHI, ENC, margin) in the post-period at newly-treated stations, had they NOT been treated, equals the observed evolution at not-yet-treated stations. This is parallel trends on the polling-station × faction-type strata.

The paper's own institutional framing undermines this assumption. Section 2 lines 103–106 states:

> "Militias actively participate: they mobilize voters for allied candidates, finance campaigns, and convert electoral support into political protection through bureaucratic appointments (Hidalgo et al., 2025; Pantaleão and Montini, 2025)."

And Pantaleão & Montini (2025), cited repeatedly, is titled "When elections empower crime." The direction of causality in the cited literature runs *from* elections *to* militia expansion — which is the reverse of the causal arrow the paper is trying to identify. If militias expand preferentially into polling stations where an allied politician is electorally vulnerable (e.g., margin is narrowing, opposition is organizing), then militia expansion is a response to *changes* in local political trends, not an exogenous shock to them. Parallel trends fails. Even if pre-trends over five elections look flat on joint tests, the relevant confounding can be a short-horizon, last-cycle correlation that the pre-trend test has low power to detect with only 3–4 pre-period cells per cohort.

**What would change my mind:**
- (a) A direct test: does pre-period electoral competition level/trend predict cohort of treatment g? Regress g on station-level (HHI_{t-1}, ENC_{t-1}, margin_{t-1}) and show the relationship is small / noisy.
- (b) An instrument or discontinuity for territorial expansion — e.g., topography, BOPE operations, Pacifying Police Unit (UPP) rollouts that opened up space for militia expansion into drug territories.
- (c) A placebo: polling stations just outside the eventually-entered territory boundary should NOT show the effect if expansion is about political conditions rather than proximity.
- (d) A narrative about *what determines the timing* of militia entry into a given polygon. Fogo Cruzado maps the *observed* territory at t; the underlying economic/political decision to expand is not in the data and is not modeled.

Without one of (a)–(d), the CS design identifies "association between territorial control and competition," not the causal effect of territorial control on competition. The paper should either produce this evidence or substantially soften the causal language (Section 4 uses "reduces," "widens," "falls" — all causal verbs).

---

### C2. Clustering level is not stated, and either plausible choice creates a problem

**Anchor:** Table 1 notes (lines 232–238); Section 3.3 lines 177–179.

The paper reports standard errors but does NOT state the cluster level. CS with polling stations nested in faction territories nested in municipalities gives three candidate levels:

- **Station-clustered:** 4,180 clusters, but treatment varies at the territory-polygon level (stations inside the same polygon are jointly treated on the same date by the same shock). Under Abadie–Athey–Imbens–Wooldridge (2023), clustering should reflect the *sampling/treatment-assignment level*. Station clustering would be *under-coverage* relative to the true DGP.
- **Municipality-clustered:** 20 clusters. Too few for asymptotic CR inference; needs wild bootstrap or CR2. Not mentioned.
- **Territory-polygon clustered:** Probably the correct level — this is where treatment assignment lives. Not clear how many polygons there are.

Without a stated clustering level and a justification, the p-values in Table 1 are not evaluable. Magnitudes like HHI +0.052 with SE 0.012 (Panel A, NYT militia) give a t-statistic ~4.3 — but if the correct cluster is territory-polygon and there are, say, 30–60 polygons, asymptotic inference needs adjustment.

**What would change my mind:** State clustering explicitly; justify it against Abadie et al. (2023); for any cluster count < 50, provide wild-cluster bootstrap p-values. If territory-polygon clustering with small G shrinks the significance of the smaller coefficients (ENC –0.459, margin +0.062), acknowledge it.

**Severity:** CRITICAL because the entire inferential claim rests on the p-values.

---

### C3. Simple aggregation is under-justified and may be the wrong estimand

**Anchor:** Equation (1) lines 163–169; footnote 1 line 200.

The paper uses `aggte(type = "simple")`, which weights ATT(g,t) cells proportional to group size × post-periods, summed across all identified post-treatment (g,t) cells. Two issues.

**C3a — which estimand?** Simple aggregation upweights early-treated cohorts because they contribute more post-period cells. The substantive claim is "militia expansion reduces competition." That claim is most naturally tested with `type = "dynamic"` (event-study aggregation over horizons) — which identifies the effect at horizon h averaged across cohorts — or with `type = "group"` (cohort-specific ATTs averaged by cohort size), which answers "what is the effect of being a 2012-cohort militia station, average cohort effect, etc." Simple aggregation mixes cohort composition with horizon composition in ways that are not transparent. With 5 election years (2008, 2012, 2016, 2020, 2024) and ~4 cohorts, early cohorts (g=2012) dominate simple-weighted estimates. If 2012-cohort effects differ from 2020-cohort effects — which is substantively plausible (militias in 2012 were expanding, in 2020 were consolidated) — simple hides this.

**C3b — why not show dynamic?** The paper promises "event-study aggregation of pre-treatment effects" for the Wald test (line 179) but does not report dynamic post-treatment coefficients in the main text. Figure 2 appears to be the simple aggregate with CIs, not a dynamic event-study plot. A CS event-study is the standard output in this literature; its absence is unusual.

**What would change my mind:**
- Report `aggte(type = "dynamic")` in a table with event-time coefficients at ℓ = –3, –2, –1, 0, 1, 2, 3 for all six outcomes.
- Show that the simple and dynamic aggregations deliver consistent conclusions; or, if they diverge, explain why simple is the right summary.
- Report `aggte(type = "group")` cohort-specific ATTs to check whether the effect is driven by any single cohort.

**Severity:** CRITICAL because an undefended choice of aggregation scheme is a standard Callaway–Sant'Anna pitfall and a referee target.

---

## MAJOR Issues

### M1. "Stable Militia / stable Drug" selection is not characterized — the estimand may be defined on a selected subset

**Anchor:** Section 3.2 lines 147–154.

> "Stations that switch faction type are excluded."

How many stations are excluded? 4,180 total stations; 398 treated militia + 240 treated drug = 638 treated. The remaining 3,542 are split between NT (outside any territory) and NYT (inside a territory later but not by the end of sample) plus excluded switchers. If switchers are, say, 5% of treated (~30 stations) it is probably benign; if switchers are 30% it changes the interpretation. The Monteiro et al. (2022) "stable classification" is cited but not characterized — the reader cannot evaluate whether the stable subset is representative of the treated population.

More importantly: switchers may be selected on outcomes. A polling station where militia control flips to drug control (or vice versa) is plausibly a contested area with distinctive political dynamics. Dropping them delivers an estimand defined on *contiguous, stable* faction control — which is the easier case for identification but a narrower substantive claim than "the effect of faction expansion." Paper language (Section 1 line 55: "militia territorial expansion reduces prefeito competition") elides this.

**What would change my mind:** Report number and share of switchers; demographic and political-trend comparison of stable vs. switcher stations; sensitivity analysis treating switchers as (a) a third treatment arm, (b) dropped observations (current), (c) first-faction-encountered cohort. If results are similar, report that; if not, frame the scope of inference accordingly.

**Severity:** MAJOR.

---

### M2. SUTVA / spillovers are not discussed

**Anchor:** No section addresses this.

Polling stations in metropolitan Rio are densely clustered. If militia A enters polygon X in 2016, voters in adjacent (but not-yet-treated) polling stations may be affected by:

- Demonstration effects: visible territorial control changes campaign behavior beyond the literal polygon boundary.
- Candidate-entry decisions: mayoral candidates may stop campaigning in the whole region, affecting nearby stations.
- Voter migration / voter suppression: voters from militia-controlled stations may switch registration.
- Displaced drug-faction activity: if militias push drug factions into adjacent stations, those adjacent stations (which may be NYT controls) get a *different* treatment.

The NYT–same-faction-type design, by construction, compares newly-treated stations to stations that will be treated by the same type later. If spillovers affect NYT controls symmetrically to treated stations, the estimator is biased toward zero. If spillovers from militia expansion affect NT (outside any territory) stations less than NYT stations (which are inside future-militia zones, geographically contiguous with current-militia zones), the NYT effect may be *compressed* relative to the true causal effect. Either direction is possible; neither is addressed.

**What would change my mind:** (a) Characterize geographic distance between each treated and its NYT controls; (b) estimate a version with a "donut" buffer excluding stations within X meters of a treated polygon boundary; (c) show the result is insensitive to the buffer. At minimum, acknowledge the SUTVA assumption and defend it.

**Severity:** MAJOR.

---

### M3. No covariates, no defense of no-covariates

**Anchor:** Section 3.3 line 177: "All specifications use the universal base period, weight observations by the number of eligible voters at each station, and allow for unbalanced panels."

No mention of covariates. CS allows conditional parallel trends: ATT(g,t | X). In an observational setting with potentially endogenous timing of treatment, baseline X controls — station-level voter composition, income, education, distance to city center, prior-election competition measures — are not optional if the authors want to block confounding trends. The NYT design partially handles time-invariant station heterogeneity (through the pre-period baseline) but does NOT handle time-varying station-level shocks that correlate with territorial expansion.

The paper mentions `aptos` (eligible voters) are used as weights but not as covariates. No baseline X are conditioned on.

**What would change my mind:** Run a specification with station-level covariates (e.g., 2008 baseline HHI, 2008 turnout, municipality × year FE alternative). If results are stable, the paper strengthens; if they move substantially, the main finding is qualified.

**Severity:** MAJOR.

---

### M4. NT pre-trends failure vs NYT pre-trends pass — underexplained and potentially self-defeating

**Anchor:** Table 1 Panel A lines 218–220; discussion lines 240–244.

Under NT controls, militia/prefeito pre-trends reject cleanly: p < 0.001 for HHI, < 0.001 for ENC, 0.010 for margin. Under NYT, pre-trends pass. The paper interprets this as "NT is contaminated by cross-municipal differences, NYT uses within-faction variation only, therefore NYT is cleaner."

This is the right direction of argument, but the magnitude of the NT failure (p < 0.001) is severe. It tells you that polling stations outside any faction territory are on very different political trajectories from polling stations inside faction territory — including those not-yet-treated by militias. Now: if within-faction-type trajectories (militia treated vs. militia NYT) are similar but between-type trajectories (militia vs. no-faction) diverge hugely, that is prima facie evidence that faction territories are selected into by a *political-trajectory* process. The NYT design removes the between-type component of selection, but does it remove the within-type *timing* component? Pre-trends tests with only 3–4 pre-periods have low power against local, non-linear, last-cycle selection.

Moreover, the NYT sample is thinner: by construction, NYT comparisons can only use (g', t) cells where g' > t, so the set of usable comparisons shrinks for later-treated cohorts. The fact that NYT Wald tests pass may partly reflect low test power in a thinned sample, not a cleaner design. The paper's own Drug–HHI NYT estimate (–0.003 with SE 0.017) shows the power problem: the CI admits effects of ±0.033 — larger than the militia effect.

**What would change my mind:** Report power calculations: for each outcome × cohort, what effect size could the NYT pre-trend test reliably detect? Show that NT and NYT estimates for the *substantive* sign are similar even if the NT pre-trend fails. Report the dynamic event-study and check for shape anomalies in the pre-period.

**Severity:** MAJOR.

---

### M5. Within-municipality demeaning (Appendix A) is an unusual diagnostic whose econometric status is unclear

**Anchor:** Appendix A equation (2) line 417; disclaimer lines 425–427:

> "This is a more demanding check than the main specification, but not a conventional baseline approach in the applied difference-in-differences literature. It should therefore be interpreted as a robustness exercise rather than as the primary design."

The authors are right to flag this as non-standard. A few specific concerns:

- **What does ỹ_imt = y_imt − ȳ_mt identify?** If you CS on ỹ, the group-time ATT becomes the differential change of treated stations relative to *all* stations in the same municipality-election — including other treated stations in the same municipality. That is a contamination concern: if multiple stations in municipality m are treated in the same cohort, ȳ_mt is computed from their own outcomes plus control-station outcomes, so subtracting it biases the treatment effect toward zero (by an amount proportional to the share of m-t observations that are treated). In municipalities where militia coverage is high (Rio West Zone), this may be severe.
- **Equivalence to municipality × time fixed effects?** Demeaning by (m,t) is algebraically the partial-out of μ_mt fixed effects. For static TWFE this would be standard. For CS, which identifies ATT(g,t) on raw outcomes, applying FE *pre-CS* changes the estimand in subtle ways and is not, to my knowledge, formally justified in Callaway–Sant'Anna (2021). The correct CS-native way to absorb municipality × time variation is `aggte(type = "simple", ...)` with municipality-by-time clustering or conditioning, not pre-demeaning. The paper's approach is ad-hoc.
- **Why include it?** The authors say it is because of concern about pooling across electoral markets. A cleaner solution: report cohort × municipality stratified ATTs, or run separate CS per municipality and aggregate. Or condition on municipality × election-cycle baseline competition as a covariate.

**What would change my mind:** Either (a) formal justification (a worked result showing demeaning-then-CS identifies a well-defined ATT), or (b) replace the demeaning with a municipality-covariate specification, or (c) drop Appendix A and replace with CS conditioned on municipality-election FE through covariates.

**Severity:** MAJOR.

---

## MINOR Issues

### m1. Effect-size baseline not reported — interpretability suffers

**Anchor:** Table 1, Section 5.1 line 296–298.

The paper reports HHI +0.052 but does not report the baseline HHI at treated stations. For HHI measured on 0–1 scale, +0.052 is either small (if baseline is 0.40, it's a 13% relative move) or enormous (if baseline is 0.15, it's a 35% move). ENC –0.459 out of a baseline of how many candidates? Reader cannot calibrate. Standard practice: report mean and SD of outcome in the treated sample pre-treatment.

**Fix:** Add a descriptive statistics table with pre-period means and SDs by group.

---

### m2. External validity is not discussed

**Anchor:** None. Should be in Section 5 or 6.

20 metropolitan Rio municipalities is a specific and non-representative setting. The paper does not discuss whether findings would extend to: (a) interior Rio state, (b) other Brazilian metros (São Paulo's PCC), (c) other LATAM urban armed-faction settings. Not blocking, but a top-5 journal would ask.

**Fix:** One paragraph in Conclusion on scope of inference.

---

### m3. Measurement reliability of Fogo Cruzado is asserted, not defended

**Anchor:** Section 3.1 lines 138–141.

> "Second, annual geo-referenced faction territory maps from Fogo Cruzado (2007–2024), providing 18 years of polygon boundaries."

Fogo Cruzado is a civil-society observatory. Its territorial mapping is excellent relative to alternatives but not infallible:
- Militia territory, being more institutionalized and less openly contested, may be *overreported* because observable market structure (gas, internet) is a visible marker.
- Drug territory is more fluid and may be *underreported* in transitional periods, creating measurement-error-induced attenuation in the drug effect.
- The 2007 → 2024 consistency of the mapping methodology is not stated. If methodology changed mid-sample, systematic measurement changes are correlated with cohort.

If drug-faction null is partly measurement error, the paper's contrast between militia and drug effects is under-identified.

**Fix:** Cite a methodological description of Fogo Cruzado mapping, discuss reliability, show one robustness with alternative sourcing (e.g., ISP-RJ police reports) if available.

---

### m4. Figure 2 description suggests simple aggregate, not event-study

**Anchor:** Figure 2 caption (line 284) and layout (lines 251–283).

The figure shows ATT point estimates with error bars for Militia and Drug under NT/NYT. This is a coefficient plot of the simple aggregate, not an event-study plot. Standard practice in CS applications is to show horizon-by-horizon dynamic effects. Adding a true event-study plot would strengthen the identification narrative.

---

## Model Identification Paragraph (rewrite suggestion)

> *Identification strategy.* We estimate group-time average treatment effects ATT(g,t) for each cohort g of polling stations first treated at election year g and each post-period t ≥ g using the Callaway and Sant'Anna (2021) estimator. Our comparison group comprises polling stations of the same faction type that are not-yet-treated at period t. This design identifies the average effect of faction territorial control on electoral competition under the assumption that, conditional on cohort g and faction type, newly-treated and not-yet-treated polling stations follow parallel expected trajectories in the absence of treatment. We defend this assumption in three ways. First, we test and cannot reject parallel trends in the pre-period using joint Wald tests on the event-study pre-treatment coefficients; we report dynamic event-study plots in Figure X. Second, we test whether baseline (2008) competition measures predict treatment cohort g and find no systematic relationship (Appendix B). Third, we rule out differential spatial confounding by reporting estimates restricted to treated–control pairs within 2 km of each other (Appendix C). We do not observe the decision process by which factions expand into specific territories; our identifying claim is that, within the set of stations that are eventually treated by a given faction type, the timing of treatment is plausibly conditionally-exogenous at horizons shorter than one election cycle. We aggregate ATT(g,t) using simple weights (weighted by group size × post-periods) as our main estimand; we also report dynamic and cohort-specific aggregations, which deliver consistent conclusions (Appendix D). Standard errors are clustered at the territory-polygon level (G = [X] clusters) and we report wild-cluster bootstrap p-values for the core estimates.

---

## Score: 5.5 / 10

**Breakdown:**
- Design choice (CS + NYT-same-type): +3.0 (correct instinct, cleanly specified)
- Pre-trends discipline: +1.5 (Wald tests reported, NT–NYT divergence acknowledged)
- Aggregation choice: –0.5 (simple undefended; dynamic/group not reported)
- Endogenous expansion / reverse causality: –1.5 (core threat, unaddressed)
- Clustering: –0.5 (level not stated; with 20 municipalities, this matters)
- SUTVA / spillovers: –0.5 (not discussed)
- Covariates: –0.5 (not used, not defended)
- Robustness Appendix A: –0.5 (non-standard, weakly justified)
- Effect-size reporting, external validity, measurement: –0.5 (MINORs pile up)

**Base: 10 → 5.5.** The paper is salvageable — most of these issues are fixable in revision — but in its current form, the identification claim is weaker than the prose implies.

---

## Positive Findings

1. **Correct instinct on NYT vs NT controls.** The authors identified that NT = outside-any-territory stations are not a valid counterfactual for inside-territory stations, and switched to NYT-same-faction-type. This is exactly the right move, and the NT–NYT divergence in pre-trends diagnostics (lines 240–244) confirms it empirically. Many applied papers in this literature do not make this distinction.

2. **Honest treatment of the null for drug factions.** The paper does not try to chase the drug-faction result through specification searching; it reports the null cleanly and interprets it substantively (Section 5.2). This is rare and commendable.

3. **Honest flagging of Appendix A status.** Line 425–427 explicitly calls within-municipality demeaning a non-standard robustness exercise rather than a primary design. This kind of self-awareness is welcome, though it does not eliminate the concern that the appendix may be doing inferential work the main text leans on (line 247–248).

---

**Word count:** ~2,450


## Lens 4 — Results

# Lens 4: Results + Tables

**Paper:** Pinho Neto & Rangel (2026), "Armed Factions and Local Electoral Competition"
**Scope:** Section 4 (Results, lines 186-290), Table 1 (206-238), Figure 2 (250-288), Appendix A Table 2 (445-479), Figure 3 (480-528).
**Date:** 2026-04-18

---

## Overall Assessment

The results section is **short for what it asks the reader to accept**. One page of prose, one table, one coefficient-plot figure — then straight into Discussion. The magnitudes are reported and briefly interpreted in §5.1, which helps, but the paper leans heavily on two visual/tabular artifacts (Table 1 and Figure 2) that both have concrete problems.

Three issues dominate. (1) **Table 1's layout is garbled** — "Wald p" is supposed to be a row label, but rows and parenthetical/bracketed statistics are interleaved so that the reader cannot tell at a glance what is coefficient, what is SE, and what is Wald p. Table 2 in Appendix A is **worse**: row labels and cells are genuinely misaligned (lines 453-462). (2) **NT pre-trends fail across the board for the headline militia/prefeito result** (all three `[<0.001]` in Table 1), yet the paper dismisses this in a single sentence and moves on. A careful reader will suspect the NYT restriction is doing more work than the authors acknowledge. (3) **The demeaned specification in Table 2 produces NEW vereador "effects" with opposite signs from Table 1** (HHI goes from +0.001 NYT raw to −0.022 NYT demeaned; margin goes from +0.002 to −0.020). The §A.2 framing — "secondary and exploratory" — is honest in word but the reader sees a table that looks equally authoritative as Table 1. A cautious reader will read this as hedging.

The magnitude discussion in §5.1 is **adequate but minimal**. It reports "nearly half a unit" for ENC and "6.2 percentage points wider" for margin, but it does not tell the reader what the baseline ENC or margin actually is in the sample. Without that anchor, a reader cannot judge whether ΔENC = −0.459 is a 10% effect or a 20% effect. This is a repairable gap.

Completeness is thin. No event-study plots are shown — only coefficient-plot aggregates. No spillover (SUTVA) checks. No heterogeneity by municipality, cohort, or baseline competition. For a staggered-DiD paper leaning on the Callaway-Sant'Anna package, **the absence of an event-study dynamic plot is a major omission** — it is the standard visual diagnostic and the `did` package produces it trivially via `aggte(type = "dynamic")`.

**Score: 5.0 / 10** — the core results table is readable with effort but has real formatting defects; the pre-trends divergence between NT and NYT is underexamined; Appendix A's framing undermines the main table's authority instead of reinforcing it; and standard robustness/heterogeneity checks are missing.

---

## CRITICAL Issues

### C1. Table 2 row/cell misalignment (Appendix A, lines 453-462)

Literal text:

```
NYT     +0.028      -0.558     +0.040     -0.004    -0.156    -0.001
                     (0.110)    (0.012)   (0.011)   (0.366)   (0.023)
        (0.007)      [0.984]    [0.417]    [0.443]  [0.860]   [0.966]

Wald p [0.190]     -0.568     +0.041      +0.022    -0.167    +0.040
                     (0.135)    (0.012)   (0.013)   (0.464)   (0.025)
NT      +0.045      [<0.001]    [0.006]    [0.145]  [0.312]   [0.535]
Wald p    (0.007)
         [<0.001]
```

The `(0.007)` SE for militia/prefeito HHI NYT appears two rows below the coefficient, and the `Wald p [0.190]` row label is visually merged with the NT coefficient row. The NT panel is even worse: `NT +0.045` is in the row that should contain Wald p values for NYT, and the SE / Wald p for NT HHI (`(0.007)` / `[<0.001]`) are orphaned below. A reader cannot reliably assign numbers to cells without reverse-engineering from context.

This is a publication blocker. It must be fixed in the LaTeX/Quarto source. Recommend a standard three-row-per-estimate block (coef / SE / Wald p) with explicit row labels on every row.

### C2. Table 1 layout ambiguity (lines 206-238)

The column-1 labels read `NYT`, `Wald p`, `NT`, `Wald p` — but the reader discovers through the notes that "Wald p" here refers to the *bracketed* number beneath each estimate, not a separate estimate. The row labeled "Wald p" therefore contains both the **SE in parens** and the **Wald p in brackets** for the estimate in the row above. This is non-standard. Most econ tables either (a) put SE beneath the coef and Wald p in a dedicated row with its own label, or (b) list Wald p once at the bottom of each panel. The current format forces the reader to re-read the Notes to decode every cell.

Fix: relabel the row as e.g. `(SE) [Wald p]` and put it on its own line, or split into two rows.

### C3. NT pre-trends fail the joint Wald test across the headline result, with one-line dismissal

Table 1, militia/prefeito NT row:

```
NT      +0.064     -0.723     +0.047
Wald p    (0.010)    (0.098)    (0.015)
         [<0.001]   [<0.001]    [0.010]
```

All three Wald p-values reject clean pre-trends at conventional levels. The paper (lines 240-244) acknowledges this in one sentence:

> "The NT estimates for militia/prefeito are directionally consistent but larger in magnitude, as expected… However, all three NT militia/prefeito Wald tests reject the null of clean pre-trends, limiting their causal interpretability."

This is under-investigation. The NT and NYT groups differ in one thing — whether the control is *ever* treated. If NT pre-trends fail but NYT pre-trends pass, the implication is that the "never-treated" group is systematically different from the "will-be-treated-later" group in ways that correlate with the outcome. That is not a minor asymmetry — it is a statement about selection into *ever* becoming militia territory. The reader needs either (i) an explanation of what differs between NT and eventually-treated stations, or (ii) a robustness check that the NYT result survives when the NYT control pool is restricted to stations treated within some bounded window.

The current framing — "NYT is preferred; NT fails pre-trends so we ignore it" — reads as specification-searching to a suspicious reader.

---

## MAJOR Issues

### M1. No event-study dynamic plot

The paper writes (line 178): "We assess pre-trends validity through joint Wald tests based on the event-study aggregation of pre-treatment effects." So the event-study is **computed**, just not shown. The `did` package produces event-study plots via `aggte(type = "dynamic")` + `ggdid()` in three lines of code. The reader needs to see:

- pre-treatment coefficients visibly close to zero (the Wald test just summarizes this)
- post-treatment dynamics — does the militia/prefeito effect build over 1-2 cycles, or appear instantaneously?

Without this, "All three estimates pass the joint pre-trends test" (line 191) is a black-box assertion. Given the NT/NYT divergence noted in C3, the event-study is essential.

### M2. Magnitude interpretation lacks baseline anchor

§5.1 (lines 294-298):

> "the effective number of candidates falls by nearly half a unit, and the winning candidate's lead over the runner-up is 6.2 percentage points wider"

The reader is not told what the sample mean ENC is, nor what the sample mean margin is. In Brazilian prefeito races the literature reports ENC typically between 2.5 and 4 depending on municipality size, so ΔENC = −0.459 is a 12-18% reduction — substantively large. Margin in Brazilian mayoral races averages around 15-25 pp depending on sample; 6.2 pp is therefore a 25-40% increase in winner-runner-up separation. These are large effects — **and the paper should say so with a number**. A single descriptive-statistics paragraph (sample means of HHI, ENC, margin separately for militia-treated, drug-treated, and untreated stations) would do the work. It is conspicuously absent.

HHI +0.052 on a 0-1 scale is even harder to interpret without knowing the baseline distribution. If baseline HHI is 0.25, a +0.052 shift is ~20%; if baseline is 0.50 it is ~10%. Unclear.

### M3. Panel B vereador results: two specifications, opposite conclusions, reader left uncertain

Table 1 Panel B (raw, NYT): HHI +0.001 [0.734], margin +0.002 [0.430] — no vereador effect.
Table 2 Panel B (demeaned, NYT): HHI −0.022 [0.274], margin −0.020 [0.133] — HHI *falls*, margin *falls*, but Wald p's are not strictly below 0.05 for margin.

These are **directionally opposite**: raw says +HHI (concentration up, trivially), demeaned says −HHI (concentration down). The paper (lines 437-442) acknowledges this is "secondary and exploratory" and that "ENC for vereador does not pass the Wald pre-trends test." But a reader scanning both tables sees two equally-formatted results with conflicting signs. The framing is *technically* honest (the text says "exploratory") but *visually* hedged (the table looks as authoritative as Table 1).

Recommended fix: move Table 2 vereador results out of the main Panel-B format and into a text-only paragraph ("demeaned HHI falls by 0.022 [Wald p 0.274], which we interpret as a sign-reversal artifact of the transformation rather than as evidence of a vereador effect"). Or drop Table 2 Panel B entirely — if it is exploratory and one of three estimates fails pre-trends, it is not robustness evidence.

### M4. Sample size disclosure is incomplete

Table 1 reports `N = 398` and `N = 240` as the number of *treated polling stations*. But the actual estimation panel has 4,180 stations × 5 elections × 2 offices = 41,800 potential cell-observations (less drops for unbalanced panel and switchers). Callaway-Sant'Anna estimates ATT(g,t) over group-time cells; the relevant N for the estimator is the number of station-cohort-time observations actually used.

The paper should report: (i) N treated, (ii) N NYT control, (iii) N NT control, (iv) total station-time observations in the estimation panel, and (v) something like "N group-time cells" or similar. At present only (i) is visible. This affects how a reader judges the precision of the SEs.

### M5. No spillover / SUTVA discussion in Results

The identifying variation is polling-station-level territory. Neighboring stations — just outside a militia polygon but within the same neighborhood — are plausibly affected by militia presence (voter intimidation extends across polygon boundaries; candidates mobilizing in militia-controlled blocks draw voters from adjacent blocks). The paper never tests for or discusses spatial spillover. Under SUTVA violation, both NT and NYT controls would be contaminated and effects biased toward zero. If the headline effect is robust to restricting controls to stations >X meters from any faction polygon, that is a very cheap robustness check. It should appear.

---

## MINOR Issues

### m1. Significance-star convention unclear

Table 1 notes (lines 237-238): "p < 0.01; p < 0.05; p < 0.10." This is the standard star-legend, but **no stars appear in the table cells**. Either the stars were stripped in the text extraction, or the paper is citing a star convention it does not use. AEA requires no stars — QJE allows them. Clarify.

### m2. Figure 2 readability (lines 250-288)

From the text dump, panels (a)-(f) are visible but axis values are fragmented across lines, and the distinction "Black squares (□) = NT; grey triangles (▲) = NYT" (line 286) relies on shape+color. In a black-and-white printout, "grey triangles" may be hard to distinguish from black squares. Prefer two distinct shapes with visibly different sizes, or add a fill/no-fill distinction.

### m3. Figure 2 and Figure 3 captions nearly identical

Fig 2 (line 284): "CS-DID Coefficient Plots: Raw Outcomes"
Fig 3 (line 526): "CS-DID Coefficient Plots: Demeaned Outcomes"

The notes sections are also near-identical. A reader flipping between them may lose track. Add a one-sentence differentiation in each caption, e.g. "Figure 3 replicates Figure 2 using municipality-demeaned outcomes; compare directly."

### m4. Panel B of Figure 2: scale mismatch with Panel A

From the text extract, Panel A ENC axis appears to go from -0.5 to 0.5; Panel B ENC goes 0 to -5. This is a 10× scale difference driven by the fact that vereador ENC levels are much higher than prefeito ENC. The reader should be told in the caption that Panel A and Panel B have different y-axis scales — otherwise the visual impression is that vereador effects are enormous.

### m5. "nearly half a unit" (line 297) is imprecise

§5.1 rounds −0.459 to "nearly half a unit." In a results paragraph this is fine, but a careful reader prefers "−0.46 on a baseline of [X]." One number is cheap.

### m6. "6.2 percentage points" — is margin in pp or in decimals?

Table 1 reports margin coefficients like +0.062 (NYT militia/prefeito). §5.1 reports this as "6.2 percentage points wider." This implicitly tells the reader that the margin variable is measured as a proportion (0-1) rather than as a percentage (0-100). Good — but it should be stated once in §3.1 when the variable is defined. At present §3.1 just says "margin of victory (difference in vote shares between first- and second-place candidates)" without units.

### m7. HHI range disclosure

HHI is reported on a 0-1 scale (standard economics convention) rather than 0-10000 (standard industrial-organization convention). The paper never says which. A non-IO reader will guess from the magnitudes. State once.

---

## Score breakdown

| Dimension | Score | Note |
|---|---|---|
| Table formatting / standalone readability | 3/10 | Table 2 misaligned; Table 1 "Wald p" row ambiguous |
| Magnitude interpretation | 6/10 | Has some; lacks baseline anchors |
| Figure execution | 6/10 | Coef plots shown; event-study missing |
| Pre-trends reporting | 5/10 | Reported, but NT failures brushed off |
| Completeness (robustness, heterogeneity, SUTVA) | 4/10 | Demeaning is the only robustness; no heterogeneity; no SUTVA |
| Framing of Appendix A (demeaned) | 5/10 | Honest in prose, hedged in presentation |

**Weighted composite: 5.0 / 10**

---

## What would move the score to 7+

1. Fix Table 2 alignment (C1) — non-negotiable.
2. Clarify Table 1 row layout (C2) — one-hour LaTeX fix.
3. Add an event-study dynamic plot (M1) — three lines of R code with `did::aggte(type="dynamic")`.
4. Add a descriptive-statistics table with sample means of HHI, ENC, margin by treatment status (addresses M2).
5. Report Ns for control groups, not just treated (M4).
6. Add one SUTVA robustness check restricting controls by distance to polygon (M5).
7. Either relegate Table 2 Panel B to a text paragraph or drop it (M3).
8. Add one paragraph investigating *why* NT pre-trends fail while NYT pre-trends pass (C3).

None of these are major scientific lifts. They are presentational and would convert a defensible-but-thin Results section into a publishable one.


## Lens 5 — Robustness

# Lens 5: Robustness — Pinho Neto & Rangel (April 2026)

**Paper**: "Armed Factions and Local Electoral Competition: Evidence from Metropolitan Rio de Janeiro"

**Target journal context**: QJE (per `/seven-pass-review` spec).

**Key question for this lens**: Does the paper anticipate a sharp QJE referee's objections? Are its robustness checks *motivated* (addressing specific, named threats) or *theatrical* (listed for optics)?

---

## Bottom-line assessment

The paper's robustness program is **thin to the point of insufficiency for its target venue**. It reports exactly two specification variations — (i) NT vs NYT controls (lines 214–230, Table 1) and (ii) within-municipality demeaning (Appendix A, lines 408–478) — and discusses *no* additional threat. There is no Rambachan–Roth sensitivity, no alternative staggered-DiD estimator, no placebo, no heterogeneity beyond the faction-type dichotomy, no MDE, no spatial-SE acknowledgment, no SUTVA discussion, and no cohort-level ATT(g,t) table. Given that the paper's entire contribution rests on a single staggered CS-DID with 398 militia and 240 drug stations (line 154), the absence of standard 2026-era DiD diagnostics will register as negligence to any QJE referee trained on Roth et al. (2023) JoE.

More damagingly, the *one* non-trivial robustness (demeaning) produces results that **contradict the main specification's vereador null** (§A.2, lines 437–442, Table 2). Rather than confront this as a specification-sensitivity problem, the paper reframes the contradiction as "secondary and exploratory" (line 439) and continues to privilege the raw-outcomes spec. A QJE referee will read this as ambivalence, not discipline.

The militia/prefeito finding may well be real. But the paper does not currently prove its robustness to the checks that a careful referee will demand within two passes of the cover letter.

---

## Tier 1 — CRITICAL (blocking)

### C1. Honest-DiD / Rambachan–Roth sensitivity is absent

The paper's entire causal claim relies on parallel trends (lines 177–179, "joint Wald tests based on the event-study aggregation of pre-treatment effects"). The Wald tests pass for the NYT militia/prefeito specs (brackets `[0.210]`, `[0.211]`, `[0.314]`, line 216). But a passed pre-trends test is *necessary, not sufficient* — its power is weak against smooth violations, and Roth (2022, *AER:Insights*) and Rambachan & Roth (2023, *ReStud*) have become standard diagnostic machinery at QJE for any DiD paper since 2023. The paper mentions neither. **A QJE referee will ask: "What is the smallest magnitude M of post-treatment PT violation that would overturn significance of the militia/prefeito ATT?"** Given N=398 treated units, the post-RR-sensitivity breakdown value is almost certainly small, and the paper needs to confront this explicitly rather than defer.

Action: report `honestDiD::createSensitivityResults_relativeMagnitudes()` for each of the three militia/prefeito outcomes, with a plot showing the M* at which the 95% CI crosses zero.

### C2. Only one estimator reported; no Sun–Abraham, no BJS, no dCdH, no ETWFE cross-validation

The paper uses Callaway–Sant'Anna *exclusively* (lines 158–169). For a staggered design with 5 election periods and multiple cohorts, QJE referees now routinely expect at least two of: Sun & Abraham (2021), Borusyak–Jaravel–Spiess (2024), de Chaisemartin–d'Haultfœuille (2020), Wooldridge ETWFE (2021). The paper shows none. If the militia/prefeito effect is driven by bad-control contamination in a particular cohort — exactly the pathology these alternative estimators are designed to surface — the CS "simple" aggregation (eq. 1, line 163) will hide it.

Separately, the "simple" aggregation weights cohorts proportional to group size *and* number of post-treatment periods (lines 167–169 even flag this), so earlier-treated cohorts dominate. This should be cross-checked against `aggte(type = "group")` and `aggte(type = "dynamic")` at minimum. Neither is in the paper.

### C3. No cohort-level ATT(g,t) or event-study figure

With 5 elections × 2 treatment types and staggered entry, the identifying variation decomposes into a small number of (g,t) cells — possibly very thin ones. The paper shows only the aggregated `ATT^simple` (Table 1, line 206) and a coefficient plot (Figure 2, line 284) whose structure is unclear from the text alone. No table of ATT(g,t), no per-cohort estimate, no pre-trend event-time figure with confidence bands per leading lag. The reader cannot evaluate whether the effect is driven by one cohort (e.g., 2012 entrants) or is broad-based. This is a first-round referee request at any serious econ journal.

---

## Tier 2 — MAJOR

### M1. The demeaned specification is not reconciled with the main specification

§A.2 (lines 437–442) reports that under within-municipality demeaning, vereador shows effects the raw spec does not: "HHI falls and the margin of victory declines, both with acceptable Wald tests." The paper dismisses this as "secondary and exploratory" (line 439), then reaffirms the raw-spec finding of no vereador effect in §5.3 (lines 326–331) by invoking the institutional structure of open-list PR.

This is incoherent. Institutional structure doesn't change between specifications. If demeaning surfaces vereador effects, **either (a) the raw spec is biased by municipality-level confounding that suppresses vereador effects, or (b) demeaning induces spurious findings via a mechanical transformation**. The paper chooses neither horn and settles for dismissing the result. A QJE referee will force the authors to pick: either the demeaned result is real and the §5.3 institutional-structure story is wrong, or the demeaning is uninformative and should not have been presented. Currently the paper wants both.

Additionally, the paper calls demeaning "a robustness exercise rather than the primary design" (lines 426–427). But within-municipality demeaning under CS-DID is mathematically equivalent to adding municipality × election fixed effects to the outcome, which is *exactly* the specification that many reduced-form DiD papers use as the baseline. Calling it non-standard is not accurate. The question of what estimand each spec identifies under the CS-DID framework needs to be written out, not brushed aside.

### M2. No spatial spillover or SUTVA discussion

Polling stations cluster in space; Fogo Cruzado territory polygons are contiguous. If militia A expands into a block that contains station X, neighboring non-faction stations on the same census block plausibly experience voter-mobilization spillovers, intimidation spillovers, or simple candidate-campaign redirection spillovers. SUTVA is violated by construction, and standard errors should at minimum be clustered at a higher spatial level (municipality, or spatial block), ideally using Conley spatial SEs.

The paper says nothing about this. The CS-DID standard errors are presumably station-level or cohort-level (Table 1 does not specify). For a paper on *geographic* organized-crime territory, omitting the spatial dimension of SE construction is a major gap.

### M3. No placebo tests despite 18 years of territory data for 5 elections

Lines 47–48 note that Fogo Cruzado provides 18 years (2007–2024) of territory maps but the panel uses only 5 election years (2008, 2012, 2016, 2020, 2024, line 132). This leaves 13 non-election years of territorial variation entirely unused. Natural placebos:
- Assign "fake" treatment timing at mid-cycle years and test whether CS-DID recovers false positives on outcomes that shouldn't be affected.
- Use prior-term outcomes (e.g., 2006 state legislative turnout) as placebo outcomes.
- Simulate territory-expansion placebos by shifting faction polygons 5km and re-running.

None of these appears. The paper is making a strong claim on a thin sample; placebo structure is the natural defense.

### M4. No MDE for the drug-faction null

The drug-faction null (lines 193–195, 312–322) is interpreted charitably as consistent with the theory that drug factions operate through confrontation rather than institutional channels. But 240 treated stations (line 154) over 5 elections yields an analysis that should have non-trivial power. The paper provides no minimum-detectable-effect calculation. A referee will ask: *"Given your design and sample, what effect size on HHI or ENC for drug factions can you reject?"* If the MDE bands comfortably cover the militia/prefeito estimate (+0.052 HHI, line 214), the paper can honestly say the evidence rejects equal-magnitude drug effects. If the MDE is larger than the militia point estimate, the "no comparable effects" claim (line 15, line 195) is overstated.

### M5. Sample-selection characterization is absent

Line 152 says "Stations that switch faction type are excluded." How many? What are their characteristics? If switcher stations are systematically in contested / dynamic neighborhoods (plausible — they're where territories are fluid), excluding them biases the sample toward stable territorial environments where electoral capture may operate most strongly. The paper should report: N of switchers excluded, baseline competition outcomes in switcher vs non-switcher stations, and ideally a robustness spec that includes switchers with a third "contested" category.

Similarly, the panel starts in 2008 despite territory data from 2007 (line 138) because the first election in the window is 2008. Fine — but what about pre-2008 territory? A station classified as "newly treated" in 2012 might have been in militia territory already in 2007 per Fogo Cruzado. The cohort definition (line 152, "the first election year in which the station falls inside a faction territory") elides whether the territory existed earlier. This needs to be stated.

### M6. No within-year treatment timing discussion

Territory maps are annual (lines 138–139); elections are quadrennial. If a militia expands into a polygon in May 2020 and the election is in October 2020, is that station "treated" in 2020? What about January 2020 expansion vs September 2020? The paper does not describe how within-year territorial changes are assigned to election cohorts. For a 5-period panel this matters enormously — one year of misclassification at the cohort boundary swaps a station between g=2016 and g=2020.

---

## Tier 3 — MINOR

### m1. No heterogeneity beyond faction type

The paper's central heterogeneity cut is militia vs drug (lines 13–16). Other natural cuts: urban vs semi-rural stations, baseline competition terciles, municipality population, proximity to the municipality boundary, distance to the state capital. None reported. For a paper about *local* political economy across 20 heterogeneous municipalities, more heterogeneity is cheap to produce and would strengthen confidence.

### m2. Weights

Stations are weighted by eligible voters (line 178). Fine. But unweighted CS-DID should be reported as a sensitivity, because the weights approximate electoral weight (which is the policy-relevant estimand) while unweighted is what the identification-proof assumes. The gap between the two is diagnostic.

### m3. Differential measurement error favoring militia detection

Fogo Cruzado is a civil-society observatory (line 47) whose territory-mapping methodology is not described. Militias operate quasi-openly via service monopolies; drug factions operate more covertly. If Fogo Cruzado is better at detecting militia territory than drug territory, the drug panel will have more measurement error in treatment assignment, biasing the drug estimate toward zero. This is a plausible mechanical explanation for the entire militia-vs-drug contrast. The paper should at minimum describe Fogo Cruzado's methodology and discuss whether it is symmetric across faction types.

### m4. Pre-period length per cohort

With 5 elections and staggered entry, the 2008 cohort has zero pre-periods; the 2024 cohort has up to four. Event-study power for leading lags is asymmetric. A figure showing, per cohort, how many pre-periods contribute to the Wald test would build credibility.

### m5. Table 2 is hard to read

The layout at lines 445–478 mixes rows and values in a way that is actually not fully parseable in the plain-text rendering provided. For instance, the "Wald p [0.190]" on line 457 sits visually detached. This is more a typesetting issue than a robustness issue, but the table needs a clean redraft.

---

## Compatibility note: demeaning and the CS-DID estimand

A technical but important point that the paper skips: under CS-DID with not-yet-treated controls, the identifying comparison is **between treated stations and stations of the same faction type that will enter later**. Demeaning by municipality × election × office (eq. 2, line 417) *adds* a within-municipality restriction to an estimator whose structure already imposes a within-faction-type restriction. The resulting estimand is:

> "Among stations in municipality m, how much does being newly in militia territory push a station's outcome above or below m's election-specific mean, relative to stations in m that will be treated only later, conditional on faction type."

This is a *different* estimand from the raw-spec CS-DID, which is:

> "How much does being newly in militia territory push a station's outcome, relative to similarly-timed not-yet-treated stations of the same faction type, pooled across municipalities."

Whether these should agree depends on whether municipality-level shocks are uncorrelated with cohort timing. The paper asserts that the demeaned result "reinforces" the raw result (lines 247–248) but the two estimands answer different questions. A careful reader will want this written out — currently it is not.

---

## Score: **4/10**

- **Score justification**: The single robustness check present (demeaning) is under-motivated and partly contradicts the main specification without reconciliation. The modal expected QJE robustness battery (honest-DiD, alternative estimators, placebos, MDE, spatial SEs, cohort-level ATT) is entirely absent. Cross-artifact verifiability is limited by the absence of published replication scripts in the manuscript as read.
- **Above 3**: The paper does report NT vs NYT control comparisons (Table 1) and explicitly runs pre-trends Wald tests — better than papers that hide these. The demeaning robustness exists, even if not fully reconciled.
- **Below 5**: At QJE bar, modern DiD papers are expected to show (i) Rambachan–Roth sensitivity, (ii) at least one non-CS estimator, (iii) cohort-level ATT(g,t) transparency, (iv) placebo structure. The paper provides none of these.

---

## Minimum fix list (prioritized)

1. **Add Rambachan–Roth sensitivity** for the three militia/prefeito estimates. One plot, one paragraph.
2. **Cross-validate with Sun–Abraham or BJS** (or ETWFE). Stack in a second column of Table 1.
3. **Report ATT(g,t)** for the 2012, 2016, 2020 militia cohorts. One supplementary table.
4. **Resolve the demeaned-vs-raw vereador contradiction.** Either defend the raw spec's null as the correct estimand and demote demeaning, or take the demeaned vereador result seriously and adjust §5.3.
5. **Conley spatial SEs** or cluster at municipality × election. Report in a footnote.
6. **MDE for drug-faction null.** One sentence in §5.2.
7. **Sample-selection table**: how many switchers excluded, their baseline characteristics.
8. **Describe Fogo Cruzado methodology** and address asymmetric measurement error.
9. **Placebo using non-election years** of Fogo Cruzado territory variation.

Items 1–3 are first-round-referee blockers. Items 4–9 are standard R&R requests.

---

*Specific line references: lines 47–48, 132, 138–141, 152, 154, 158–169, 177–179, 193–195, 214–230, 247–248, 312–322, 326–331, 408–478 (Appendix A throughout), 426–427, 439.*


## Lens 6 — Prose

# Lens 6: Prose Quality

**Paper:** Pinho Neto & Rangel (April 2026) — "Armed Factions and Local Electoral Competition: Evidence from Metropolitan Rio de Janeiro"
**Reviewer persona:** `proofreader.md` (expert academic proofreader; report-only, no edits)
**Target:** QJE (11 pp. main text + appendix)

---

## Overall Assessment

The prose is generally clean, readable, and well above average for an L2-English econometrics paper. Sentences are mostly disciplined in length, paragraphs have recognizable topic sentences, and the argument moves forward. However, the manuscript has several recurring problems that weaken its presentation at a top-five bar:

1. **Register slippage between associational and causal language** — the paper oscillates (abstract: "is associated with"; results/discussion: "reduces"; conclusion: "is associated with" again). A DiD paper claiming identification should commit to causal phrasing in the main text and restrict hedging to clearly demarcated caveat sentences.
2. **Encoding artifacts throughout the extracted .txt** — "Pantale�o", "mil�cia", "Coordena��o", "N�vel", "Brazil�Finance", "2007�2024", "537�581", em-dashes rendered as `--`. These appear to be PDF-extraction artifacts, but the author pair must verify the underlying PDF/LaTeX source does not have the mojibake. If any of these survive in the compiled PDF, they are **CRITICAL**.
3. **Terminology used before being glossed.** Abstract line 13 introduces "prefeito (mayoral)" correctly, but "vereador" appears without translation at line 58 and is only glossed parenthetically at line 59. "NYT" / "NT" are introduced on first use at line 171-175 (acceptable), but "HHI" and "ENC" are used in tables before the body text defines them (line 134-136 is the only definition and comes mid-section).
4. **Page count is very short for QJE.** 11 pages main text is half a typical QJE length. This is a presentation/length critique, not prose per se, but it signals the manuscript is closer to a Letter/AEJ:Applied submission than to QJE flagship format.
5. **Minor but recurring**: occasional Portuguese-calque phrasings and a handful of clumsy constructions flagged below.

**Score: 6.5 / 10** — solid readable English, but several issues keep it from a polished submission-ready state.

---

## CRITICAL issues

### C1. Encoding / character corruption in author funding note and body text
- **Lines 27, 39, 42, 72, 104, 301, 306, 349, 397** (extracted .txt): `Pantale�o`, `mil�cia`, `Coordena��o de Aperfei�oamento de Pessoal de N�vel Superior`, `Brazil�Finance Code 001`
- **Lines 356-357, 366, 368-369, 374, 381-383, 390**: en-dashes in page ranges rendered as `�` (e.g., `87(2):537�581`, `2007�2024`, `19(3):854�873`).
- **Severity: CRITICAL** if present in the submitted PDF; **MINOR (extraction noise)** if only in the .txt.
- **Action:** verify the compiled PDF and LaTeX source use proper UTF-8 encoding (`\usepackage[utf8]{inputenc}` or `\usepackage{lmodern}` + modern engine). `Pantaleão` (line 27, 39, 72, 104, 306, 349, 397) and `milícia` (line 301) and `Coordenação de Aperfeiçoamento de Pessoal de Nível Superior` (line 42) must render correctly. `Brazil—Finance Code 001` (em-dash, line 42) must be `—`, not `�`.

### C2. Missing space in §4 Results
- **Line 244:** "provide the preferred causal estimates.Figure 2 displays..."
- No space between period and "Figure". This is a typographical defect the compositor will flag.
- **Severity: CRITICAL (visible error in body text).**

### C3. Register inconsistency on causal claim
- Abstract **line 12**: "militia expansion **is associated with** lower competition" (associational)
- Results **line 56, 189, 335**: militia expansion **"reduces"** prefeito competition (causal)
- Conclusion **line 335**: "Militia territorial control **is associated with** lower mayoral competition" (back to associational)
- **Severity: CRITICAL.** Under a CS-DiD estimator with cohort/year controls and pre-trends tests, the paper's identification claim is causal. Oscillating between "reduces" and "is associated with" within the same manuscript signals the authors themselves are unsure of their identification strength, and invites the referee to doubt it. Commit to one register and stick with it. Recommended: use "reduces" in the main results prose and reserve "is associated with" for the descriptive framing in the Intro literature review only.

---

## MAJOR issues

### M1. Acronym definition order
- **Line 134-136** defines HHI ("Herfindahl-Hirschman Index"), ENC ("effective number of candidates"), and margin of victory. But HHI and ENC are already used in Table 1 (line 210) which the reader encounters *conceptually* via the abstract's "vote concentration" and "effective number of candidates". Because Table 1 is placed at §4, after definitions, this is acceptable — but see C3 about consistency of "vote concentration" (abstract line 13) vs. "HHI" (Table 1, results). The paper should pick one primary term in body prose and parenthesize the other on first use.
- Recommendation: at line 13 abstract, write "vote concentration (HHI)" and then use HHI throughout results.

### M2. Vereador gloss placement
- **Line 13**: "prefeito (mayoral)" — good.
- **Line 58-59**: "Vereador (city council) races" — gloss on first prose use: good, but the abstract uses "prefeito" without immediately pairing it with "vereador" and the first vereador mention in the abstract is absent. Consider pairing them in the abstract: "...mayoral (prefeito) and city-council (vereador) races..." for a foreign (QJE) audience.
- **Severity: MAJOR.** QJE's median reader has never heard of a vereador.

### M3. "Not a conventional baseline approach" — awkward and potentially Portuguese calque
- **Line 425-426 (appendix):** "This is a more demanding check than the main specification, but not a conventional baseline approach in the applied difference-in-differences literature."
- Reads like a literal translation of "não é uma abordagem-padrão de baseline na literatura...". A native-English rewrite: "This is a more demanding check, but it is not a standard baseline in the applied DiD literature."
- **Severity: MAJOR.** Reviewers notice calques; it undermines perceived polish.

### M4. Abstract sentence awkward
- **Lines 15-16:** "militias are more able than drug factions to translate territorial dominance into electoral advantage in local executive contests."
- "More able than" is grammatical but flat; QJE abstracts typically compress. Better: "militias have a greater capacity than drug factions to convert territorial control into electoral advantage in mayoral races" — this also uses "mayoral" for the English reader and "convert" (one verb) rather than "translate...into" (a three-word locution).

### M5. Long sentence in §1 Introduction
- **Lines 36-39:** "Militias--often composed of current or former state agents--extract rents through quasi-legal services and participate more directly in electoral politics through voter mobilization and political protection networks (Dantas et al., 2023; Hidalgo et al., 2025; Pantale�o and Montini, 2025)." — 38 words. At the upper bound.
- **Lines 61-64:** "A substantive concern in this setting is that prefeito and vereador elections are municipality-specific: each of the 20 metropolitan municipalities constitutes a distinct electoral market with its own candidates and baseline level of competition." — 34 words, fine.
- **Lines 317-322:** "If drug-faction influence is mediated by varying forms of confrontation, collusion, or territorial dispute, its electoral consequences may be less stable over time and less likely to appear as systematic temporal effects in our design." — **37 words, borderline.**
- **Severity: MAJOR (aggregate).** No single sentence exceeds 40, but the manuscript has 4–5 sentences in the 34–38 range. Break them.

### M6. Em-dash convention inconsistent
- The paper uses `--` (double hyphen) in many places (lines 28-29, 33-34, 36, 74, 85-86, 202-203, 297-298, 327-328, 345) where proper em-dashes `—` are intended. This is likely a LaTeX `---` → em-dash convention issue in the source. In the compiled PDF these should render as em-dashes; the reviewer should verify. If the source has literal `--` strings, this is a MAJOR typographical issue.

### M7. Sparse use of topic sentences in discussion
- §5.1 (lines 294-310), §5.2 (lines 314-322), §5.3 (lines 326-331): each opens with a recap/restatement rather than a forward-moving topic sentence. Example:
- Line 294: "The central finding is that militia territorial expansion reduces electoral competition for mayor in the metropolitan sample." — this is a recap of Table 1.
- A stronger topic sentence would *advance* the argument: "Three mechanisms plausibly drive the militia-mayor result: (i) voter mobilization through clientelist networks, (ii) direct candidate co-optation, and (iii) ..."
- **Severity: MAJOR** for a discussion section. Discussion paragraphs should each add a new interpretive claim, not restate results.

### M8. Passive voice in results/discussion
- Not dominant overall, but clustered in a few spots:
- Line 193-195: "Drug-faction expansion shows no significant effects under the preferred NYT specification. The corresponding estimates are small and statistically imprecise across outcomes, so we do not detect comparable effects..." — the `so we do not detect` is active; the earlier clauses are fine.
- Line 240-243: "as expected when comparing faction-controlled stations against the broader set of non-faction stations. However, all three NT militia/prefeito Wald tests reject the null of clean pre-trends, limiting their causal interpretability." — passive construction "limiting their causal interpretability" is nominalized; better: "... which limits causal interpretation."
- Line 341-343: "Comparable effects are not detected for drug trafficking factions under the preferred not-yet-treated estimator." — classic passive. Active: "The preferred not-yet-treated estimator does not detect comparable effects for drug trafficking factions."
- **Severity: MAJOR** (aggregate, not any one instance).

---

## MINOR issues

### m1. "Rather than" / "rather than as"
- **Lines 105-106:** "as a temporal effect--strengthening as territory is held over successive election cycles--rather than as a purely spatial phenomenon." — the `rather than as` is technically fine but the parallelism is forced ("as a temporal effect ... as a purely spatial phenomenon"). Consider: "as a temporal rather than purely spatial phenomenon."

### m2. Abstract omits vereador findings
- The abstract (lines 10-16) only mentions the militia-mayor result. It does not report the null vereador finding. Most referees expect the abstract to summarize *all* main findings, including nulls when they are pre-registered comparison outcomes. This is a content issue more than a prose one, but the phrasing is terse.

### m3. "Taken together"
- Appears at lines 15 and 345. Both times at the top of a concluding/summary sentence. Fine as a transition, but used twice in 11 pages. Swap one for "On balance" or "In sum".

### m4. Table 1 formatting prose
- **Line 188:** "Table 1 presents the CS-DID estimates using raw outcomes."
- **Line 244:** "Figure 2 displays the coefficient plots..."
- **Line 431:** "Table 2 presents the CS-DID estimates using municipality-demeaned outcomes."
- **Line 108:** "Figure 1 displays faction territories..."
- Consistent: "presents" for tables, "displays" for figures. Keep as-is.

### m5. Footnote placement
- **Line 200 (footnote 1):** the footnote is inside equation (1)'s aggregation description, which makes the reader interrupt reading the math to check a trivial implementation note. Move to the end of the paragraph before the equation, or drop it entirely if the `did` package is already cited elsewhere.

### m6. Parenthetical citations vs. inline
- The paper uses both: `(Arias, 2006)` (parenthetical) and `Callaway and Sant'Anna (2021)` (inline/textual). Usage is appropriate — inline when the authors are the grammatical subject — but verify the `.bib` + `natbib` style is consistent. No defects flagged from the extracted text.

### m7. "Evidence" is vague
- Conclusion §6, **lines 341-343:** "Comparable effects are not detected for drug trafficking factions under the preferred not-yet-treated estimator. **Evidence** for vereador outcomes is more limited and secondary..." — "Evidence for X" is a soft phrasing. Clearer: "We find no effects for vereador outcomes under the main specification."

### m8. JEL codes formatting
- **Line 17:** "JEL: D72, K42, O17 Keywords: electoral competition, organized crime, armed factions, local politics" — no linebreak or punctuation between JEL and Keywords. The PDF may render this correctly if there's a `\\` in source; verify.

---

## Model Paragraph — rewritten in tight active voice

**Original (lines 300–310, §5.1):**

> These effects are consistent with the organizational nature of militias, which operate through institutionalized channels. Recent evidence from Rio de Janeiro shows that mil�cia expansion is sustained not only by coercion, but also by political protection: criminal groups deliver concentrated electoral support to aligned politicians, who in turn influence bureaucratic appointments and law-enforcement priorities in ways that facilitate further expansion (Pantale�o and Montini, 2025). More generally, this mechanism is consistent with evidence that local democratic representation can redirect policing and violence through favoritism toward politically connected constituencies (Novaes, 2023). Our results fit this broader view of elections as a channel through which territorial control can be converted into political protection.

**Rewritten (tight active voice, 85 words, em-dash corrected):**

> The militia-mayor result aligns with the institutional nature of these groups. Pantaleão and Montini (2025) show that militias in Rio sustain territory through two linked channels: coercion and political protection. Aligned politicians win concentrated local support; in return, they shape police priorities and bureaucratic appointments in ways that protect militia operations. Novaes (2023) documents a parallel pattern — local representation redirects policing toward connected constituencies. Our estimates extend this view: elections convert militia territorial control into political power, rather than constraining it.

**Key changes:** 147 words → 85 words (-42%). Three passive constructions removed. Two nominalizations unpacked ("operate through institutionalized channels" → "sustain territory through two linked channels"). Em-dash corrected. Active subject-verb in every sentence.

---

## Score: 6.5 / 10

Clean and readable baseline. Three CRITICAL issues (encoding, missing space, register oscillation) and seven MAJOR issues (acronym ordering, vereador gloss, calque, long sentences, em-dash convention, topic-sentence weakness in Discussion, clustered passive voice) must be fixed before submission. The prose is better than typical L2-English econ submissions but falls short of QJE polish. With a focused copy-editing pass — commit to causal register throughout, gloss Portuguese terms once in the abstract, tighten the Discussion topic sentences, fix the PDF encoding — this rises to a solid 8/10.


## Lens 7 — Citations

# Lens 7 — Citations & Literature Review

**Paper:** Pinho Neto & Rangel (2026), "Armed Factions and Local Electoral Competition: Evidence from Metropolitan Rio de Janeiro"
**Target:** *Journal of Politics* (JOP)
**Reviewer role:** Lens 7 — Citations & Literature hygiene
**Date:** 2026-04-18

---

## Headline assessment

The reference list is **short (19 entries)** and cleanly focused, with good coverage of the core criminal-governance / Brazil-specific literature. But there is **one critical bibliographic hygiene failure** — the paper cites what is almost certainly the same journal article twice under two different author attributions — along with several **miscalibrated in-text citations**, **missing methodological references** a modern JOP referee will expect for a CS-DID paper, and **missing Brazilianist political science** references (Hidalgo, Desposato, Lucas Novaes's broader machine-politics work, Yashar, Durán-Martínez). For a 2026 JOP submission the bibliography is also thin: 19 references for a paper that sits at the intersection of three sizable literatures (criminal governance, Brazilian local politics, staggered DiD) is unusual. Web verification (three queries against Cambridge Core) supports the duplicate-cite concern.

**Score: 5.5 / 10** — the paper is citable enough to pass desk review on substance, but there is at least one *CRITICAL* bib-hygiene issue that must be resolved before submission, plus ~8 MAJOR missing references.

---

## CRITICAL issues

### C1. Duplicate citation of the same paper under two author attributions

- **Hidalgo, F. D., Lessing, B., et al. (2025)**, "When elections empower crime: Political protection and milícia expansion in Rio de Janeiro," *Latin American Politics and Society* (ref list line 378–380).
- **Pantaleão, B. and Montini, I. C. (2025)**, "When elections empower crime: Political protection and milícia expansion in Rio de Janeiro," *Latin American Politics and Society* (ref list line 397–399).

**These are the same paper.** Title identical (including subtitle), journal identical, year identical. Web verification (Cambridge Core article record for vol. 67 iss. 4) returns a single article with this exact title. Public descriptions of the Pantaleão–Montini work at FGV use the same abstract as the Cambridge Core entry attributed to Hidalgo & Lessing. Either (a) the Hidalgo/Lessing attribution is wrong and the correct authors are Pantaleão & Montini, or (b) the paper was co-authored by all four and the author list is incomplete in both entries. Either way, the bibliography is currently self-contradictory.

**In-text consequences:**
- Line 39: "(Dantas et al., 2023; Hidalgo et al., 2025; Pantaleão and Montini, 2025)" — cites the *same paper twice* in the same parenthesis.
- Line 104: "(Hidalgo et al., 2025; Pantaleão and Montini, 2025)" — same paper twice.
- Lines 27, 71–72, 306, 349 also cite Pantaleão & Montini on the electoral-protection mechanism; some of those sentences now double-count.

**Action:** resolve author attribution (contact Cambridge Core or authors), merge into a single entry, delete duplicate in-text citations. Until resolved, this is a desk-reject-adjacent issue at a serious journal — it signals the bibliography was not checked.

---

## MAJOR issues

### M1. Miscalibrated Ferraz & Finan (2008) citation

- Line 74–75 and line 329: "(Ferraz and Finan, 2008)" is cited to support the claim that "a friendly mayor influences security priorities, land-use regulation, and municipal contracts." FF08 (*QJE*) is about the electoral impact of random audits of Brazilian municipalities; it documents that information disclosure penalizes corrupt incumbents. It does not establish that mayors have substantive influence over security / land use / contracts. The correct citation would be **Ferraz & Finan (2011, AER)** "Electoral accountability and corruption" for accountability of mayors, **Brollo, Nannicini, Perotti & Tabellini (2013, AER)** "The political resource curse" for mayor discretion over federal transfers, or a Brazilian local-public-finance reference (Arretche, Mendes).
- This is the kind of citation a Brazilianist JOP referee will flag immediately.

### M2. Missing modern DiD methods references

The paper uses Callaway & Sant'Anna (2021) but does not situate it within the broader recent methods literature. For a **2026 JOP submission**, referees expect at least a footnote or a methods sentence engaging with:
- **de Chaisemartin & D'Haultfœuille (2020, AER)** — problematic TWFE with heterogeneous effects.
- **Goodman-Bacon (2021, *J. Econometrics*)** — decomposition of TWFE DiD with staggered timing.
- **Sun & Abraham (2021, *J. Econometrics*)** — event-study estimators under heterogeneous treatment effects.
- **Borusyak, Jaravel & Spiess (2024, *ReStud*)** — imputation estimator.
- **Roth, Sant'Anna, Bilinski & Poe (2023, *J. Econometrics*)** — what's trending in DiD.
- **Roth (2022, *AER: Insights*)** — pre-trends tests and power considerations. *Especially relevant* because the paper leans heavily on Wald joint pre-trends tests as its identification credibility argument.

Political science journals (including JOP) are less methods-obsessed than *J. Econometrics* / AER, so a single footnote citing 2–3 of these is adequate. But currently the paper cites CS-DID as if it were obviously the right tool without engaging with why. A skeptical referee will ask why not BJS, why not SA, why not doubly-robust.

### M3. Missing Brazilian political science references

Several Brazilianists who are plausible JOP referees (or whose work readers will expect the paper to engage with):

- **Hidalgo, F. D.** — his broader work on Brazilian parties and local politics (e.g., Hidalgo & Nichter 2016 on clientelism, Hidalgo 2010 on electoral fraud). If the "Hidalgo et al. 2025" attribution is correct (see C1), the paper should also cite at least one of his other pieces.
- **Novaes, L. M.** — cited once (2023, APSR) but Novaes has a broader body of work on political brokers and machine politics in Brazil (e.g., Novaes 2018, *J. Development Economics*, "Disloyal brokers") that directly speaks to candidate selection in contested territories.
- **Desposato, S. W.** — foundational work on Brazilian party systems, district magnitude, and vote concentration in Brazilian elections. For a paper measuring vote concentration in Brazilian municipal races, the absence of Desposato is notable.
- **Samuels, D.** — Brazilian legislative/executive politics.
- **Cantú, F. & Morgenstern, S.** — cross-national work on party competition and ENP in Latin America, relevant given the use of Laakso–Taagepera.

A Brazilian JOP editor (there are several on the board) will notice these omissions.

### M4. Missing comparative-crime / LATAM references

- **Yashar, D. J. (2018)** *Homicidal Ecologies* — Cambridge. Directly on organized crime, territorial control, and state–society relations in Latin America; speaks to the theoretical framing the paper gestures toward in Section 5.
- **Durán-Martínez, A. (2018)** *The Politics of Drug Violence* — Oxford. Cartels, state fragmentation, and political competition. A standard reference.
- **Skarbek, D. (2011, *APSR*; 2014 book)** on prison gangs and extralegal governance — the paper's argument about militias providing "quasi-legal services" parallels Skarbek's framework, and should cite it.
- **Snyder, R. & Durán-Martínez (2009)** on state-sponsored protection rackets — closest conceptual ancestor of the paper's mechanism and not cited.

### M5. HHI citation missing

Line 134–136: "vote concentration (Herfindahl–Hirschman Index of candidate vote shares)." The effective-number-of-candidates measure is correctly cited to Laakso & Taagepera (1979). HHI is *used as an outcome* but no reference is provided — either Hirschman (1945, *National Power and the Structure of Foreign Trade*) or Herfindahl (1950 dissertation), or more commonly for ENP-style applications **Rae (1968)** "A note on the fractionalization of some European party systems." Minor but easy to fix.

### M6. Dataset citation for TSE

Line 131–132 and line 403: "Tribunal Superior Eleitoral (2024)" with URL. For a modern JOP submission, the convention is:

> Tribunal Superior Eleitoral. 2024. *Repositório de Dados Eleitorais* [dataset]. Brasília: TSE. https://dadosabertos.tse.jus.br/ (accessed: [date]).

The current entry is close but lacks (a) access date, (b) explicit [dataset] tag, and (c) a DOI if one exists (TSE open data does not currently issue DOIs, but Harvard Dataverse mirrors do exist — see Pereira et al.'s replication packages). Consider also citing the specific year-files retrieved.

### M7. Fogo Cruzado territory maps not in reference list

Lines 47–48, 125, 138: Fogo Cruzado is the *central* data source (faction territory maps, 2007–2024). It is mentioned in text and figure notes but has **no entry in the reference list.** For a JOP paper where the main identification strategy depends on these polygons, Fogo Cruzado must appear as a data reference:

> Fogo Cruzado Institute. 2024. *Mapas de territórios de facções armadas, região metropolitana do Rio de Janeiro, 2007–2024* [dataset]. Rio de Janeiro. https://fogocruzado.org.br/

This is a **MAJOR** issue because the paper cannot be replicated without knowing exactly which Fogo Cruzado product/version was used. Without a data citation, the provenance is unverifiable.

### M8. Replication package / pre-registration not mentioned

JOP **requires** a replication package at acceptance (Dataverse or similar). The manuscript makes no mention of an OSF pre-registration, a Dataverse deposit, or a code availability statement. Standard JOP-2026 practice is a footnote on page 1 pointing to the replication archive. Add.

---

## MINOR issues

### m1. DOIs missing throughout

For a modern submission to JOP (which uses the APSA citation style and allows DOIs):
- AEJ, APSR, JPE, *Journal of Politics*, QJE, *Review of Economic Studies* papers should carry DOIs.
- **None** of the 19 reference entries has a DOI. Add.

### m2. Page range on Acemoglu, De Feo & De Luca (2020)

Line 356–357: "Review of Economic Studies, 87(2):537–581." Verify — the published range is 537–581 (confirmed). OK.

### m3. Dantas et al. (2023) "GENI/UFF Working Paper" — incomplete cite

Line 371–372: Working paper citations should include a number/URL. Add working paper number and URL to GENI (Grupo de Estudos de Novos Ilegalismos, UFF).

### m4. Monteiro, Maia & Magaloni (2022) — "Working Paper" with no identifier

Line 391–392: Incomplete. Which working paper series? Is it on SSRN, IDB, or an institutional server? Add identifier. This is the paper that defines the "stable Militia"/"stable Drug" classification the treatment definition depends on (line 150) — replicators will need to find it.

### m5. Novaes (2023) APSR — missing volume/issue/pages

Line 394–396: "American Political Science Review" with no vol/issue/pages. Expand the cite.

### m6. Magaloni, Franco-Vivanco & Melo (2020) APSR — missing volume/issue/pages

Line 388–390: Same issue. Add full citation.

### m7. Capitalization inconsistencies

- Line 390: "rio de janeiro" (lowercase) in Magaloni et al. title.
- Line 396: "brazil" (lowercase) in Novaes title.
- Line 399: "rio de janeiro" (lowercase) in Pantaleão & Montini title.

Clean up title case before submission.

### m8. "et al." in a reference-list entry

Line 378: "Hidalgo, F. D., Lessing, B., et al. (2025)." Reference lists should spell out all authors. Current form is a placeholder. Fix.

---

## Cite-claim direction checks (sampled)

| Line | Citation | Claim | Assessment |
|------|----------|-------|------------|
| 23–24 | (Lessing 2021; Arias 2006; Trejo & Ley 2020) | "Criminal orgs control territory, regulate daily life, and shape electoral outcomes" | **OK** — Lessing 2021 covers criminal governance typologies; Arias 2006 covers territorial control / daily life in Rio favelas; Trejo & Ley 2020 covers electoral effects in Mexico. All three support the triple claim, though attributing "shape electoral outcomes" to Arias 2006 is a stretch — Arias emphasizes political networks more than election outcomes per se. Mild miscalibration. |
| 25 | (Dell 2015; Blattman et al. 2024; Novaes 2023) | "Effects of organized crime on turnout, candidate selection, campaign violence, local political representation" | **OK** — all three are credible. Dell 2015 on policy consequences of drug-war spatial variation; Blattman et al. 2024 on gangs and labor (less obviously electoral); Novaes 2023 on law-enforcement candidates. Blattman is about labor mobility and extortion in San Salvador — not directly about turnout or candidate selection. Marginal miscalibration. |
| 27–28 | (Novaes 2023; Pantaleão & Montini 2025) | "Electoral alliances may reinforce rather than constrain criminal governance" | **OK** direction — if the Pantaleão/Hidalgo duplicate is resolved. Novaes 2023's mechanism is about law-enforcement candidates and violence, which is adjacent but not exactly "electoral alliances reinforcing criminal governance." Fine as a directional cite. |
| 74–75 | (Ferraz & Finan 2008) | "A friendly mayor influences security priorities, land-use regulation, municipal contracts" | **MISCALIBRATED** — see M1. FF08 is about audit→electoral defeat of corrupt mayors. Replace. |
| 104 | (Hidalgo et al. 2025; Pantaleão & Montini 2025) | Militias "mobilize voters, finance campaigns, convert electoral support into political protection through bureaucratic appointments" | **OK** directionally but **same paper cited twice** — see C1. |
| 329 | (Ferraz & Finan 2008) | "Mayoral contests involve few candidates competing for a single seat with substantial executive power over municipal resources" | **MISCALIBRATED** — same issue as M1. The claim is about mayoral discretion/authority, not about audits. Replace. |

---

## Suggested additions (priority-ordered)

| Reference | Rationale | Where to cite | Priority |
|-----------|-----------|---------------|----------|
| Fogo Cruzado Institute data entry | Main data source lacks a ref-list entry | §3.1 and ref list | CRITICAL |
| Ferraz & Finan 2011 (AER) OR Brollo et al. 2013 (AER) | Replace miscalibrated FF08 citations on mayoral authority | Lines 74–75, 329 | MAJOR |
| de Chaisemartin & D'Haultfœuille 2020 | TWFE critique motivates CS-DID choice | §3.3 methods footnote | MAJOR |
| Sun & Abraham 2021 | Alternative event-study estimator | §3.3 methods footnote | MAJOR |
| Goodman-Bacon 2021 | TWFE decomposition | §3.3 methods footnote | MAJOR |
| Roth, Sant'Anna, Bilinski & Poe 2023 | Modern DiD review | §3.3 or intro footnote | MAJOR |
| Roth 2022 (AER: Insights) | Pre-trends tests & power | §3.3 where Wald tests are described | MAJOR |
| Yashar 2018 *Homicidal Ecologies* | Criminal orgs + state–society in LATAM | §1 and §2 | MAJOR |
| Durán-Martínez 2018 | Drug violence and state fragmentation | §1 | MAJOR |
| Snyder & Durán-Martínez 2009 | State-sponsored protection rackets — closest conceptual ancestor | §2 or §5 | MAJOR |
| Skarbek 2011 (APSR) / 2014 | Extralegal governance, gangs as governance | §2 framing | MAJOR |
| Desposato (any) | Brazilian electoral competition / party system | §3 measurement section | MINOR |
| Hidalgo 2010 (APSR) / Hidalgo & Nichter 2016 | Brazilian local politics authority | §1 | MINOR |
| Novaes 2018 *JDE* "Disloyal brokers" | Brazilian machine politics | §1 | MINOR |
| Rae 1968 or Laakso & Taagepera 1979 (for HHI too) | Citation for HHI | §3.1 | MINOR |
| Cantú & Morgenstern | Comparative measurement of electoral competition | §3.1 | MINOR |

---

## Miscalibrated citations (table)

| Location | Cite | Problem | Fix |
|----------|------|---------|-----|
| Lines 74–75 | (Ferraz and Finan, 2008) | FF08 is about audits→elections, not mayoral policy authority | Replace with Ferraz & Finan 2011 (AER) or Brollo et al. 2013 (AER) |
| Line 329 | (Ferraz and Finan, 2008) | Same | Same |
| Line 39 | (Dantas et al. 2023; Hidalgo et al. 2025; Pantaleão and Montini 2025) | Same paper cited twice | Delete one cite |
| Line 104 | (Hidalgo et al. 2025; Pantaleão and Montini 2025) | Same paper cited twice | Delete one cite |
| Line 25 | Blattman et al. 2024 listed for "turnout, candidate selection, representation" | Blattman 2024 is on labor-mobility effects of extortion; not about elections/turnout | Move Blattman to a crime-economics context; cite Ley 2018 or Trejo & Ley 2020 instead |
| Line 24 | Arias 2006 for "shape electoral outcomes" | Arias 2006 is about political networks and social order, not electoral outcomes per se | Move Arias to territorial-control cite only; use Novaes 2023 + Hidalgo/Lessing 2025 for electoral-outcomes claim |

---

## Missing references a JOP referee will flag

**Criminal governance theory:** Skarbek (2011, 2014), Yashar (2018), Durán-Martínez (2018), Snyder & Durán-Martínez (2009).

**Brazilian political science:** Desposato, Hidalgo's broader work, Novaes 2018 JDE, Samuels, Arretche on municipal governance.

**Modern DiD methods:** de Chaisemartin & D'Haultfœuille 2020, Sun & Abraham 2021, Goodman-Bacon 2021, Borusyak–Jaravel–Spiess 2024, Roth 2022, Roth et al. 2023.

**Data references:** Fogo Cruzado (missing from ref list entirely), TSE formatting, Monteiro et al. 2022 identifier, Dantas et al. 2023 identifier.

---

## Reference list health summary

- **Count:** 19 entries. Low for a paper at the intersection of 3 literatures. Expect 30–45 in a submitted JOP manuscript.
- **DOIs:** 0 / 19 entries have DOIs. All journal papers should have them.
- **Working papers without identifiers:** 3 (Dantas et al. 2023, Monteiro et al. 2022, both central; plus arguably the Hidalgo/Pantaleão attribution chaos).
- **Title-case violations:** 3 entries.
- **Duplicate entry:** 1 (probable) — see C1.
- **Data citations:** 2 entries (TSE; Monteiro et al.'s classification) but **main data source (Fogo Cruzado) is missing.**

---

## Score: 5.5 / 10

**Breakdown:**
- Core substantive coverage (criminal governance + Rio specifics): 7/10. Good.
- Bibliographic hygiene: 3/10. Duplicate entry, missing DOIs, missing Fogo Cruzado data cite, incomplete working-paper cites, title-case issues.
- Cite-claim alignment: 6/10. Two FF08 miscalibrations, two duplicate-cites in same sentence.
- Coverage of modern DiD methods literature: 2/10. Only CS-DID; no engagement with TWFE critique or alternative estimators.
- Brazilianist breadth: 5/10. Novaes and Ferraz & Finan are there, but broader Brazilianist political science (Desposato, Hidalgo's broader œuvre, Samuels, Arretche) is absent.
- Comparative crime–politics theory: 5/10. Trejo & Ley, Dell, Lessing, Acemoglu all good; but missing Yashar, Durán-Martínez, Skarbek, Snyder & Durán-Martínez.

**Minimum to get to 7.5/10 before JOP submission:**
1. Resolve C1 (the duplicate Hidalgo/Pantaleão cite) — non-negotiable.
2. Add Fogo Cruzado as a data reference — non-negotiable.
3. Replace FF08 miscalibrations with FF11 or Brollo et al. 2013.
4. Add a methods-footnote paragraph citing 3–4 modern DiD references.
5. Add 3–4 comparative crime-politics references (Yashar, Durán-Martínez, Skarbek, Snyder & Durán-Martínez).
6. Add DOIs to all journal entries, fix title case, expand working-paper cites.

**Sources (web verification):**
- [When Elections Empower Crime: Political Protection and Milícia Expansion in Rio de Janeiro | Cambridge Core](https://www.cambridge.org/core/journals/latin-american-politics-and-society/article/abs/when-elections-empower-crime-political-protection-and-milicia-expansion-in-rio-de-janeiro/74C5B7EDC5DBF1D85927EB90EB822CC0)
- [Political Science grad student explores violence and grassroots resistance in Brazil — Berkeley L&S](https://ls.berkeley.edu/news/political-science-grad-student-explores-violence-and-grassroots-resistance-brazil)
- [Latest issue — Latin American Politics and Society | Cambridge Core](https://www.cambridge.org/core/journals/latin-american-politics-and-society/latest-issue)



===========================================================================
# APPENDIX — CONFIGURATION
===========================================================================

## A. Journal profile: AEJ: Applied Economics (AEJApplied)

The pipeline was calibrated to AEJ: Applied Economics using the profile at `.claude/references/journal-profiles.md`. Key calibrations applied:

- Referee-pool weights used for disposition sampling (Phase 1b of the peer-review pipeline)
- Domain-referee dimension adjustments (Part III Ref A scoring)
- Methods-referee dimension adjustments (Part III Ref B scoring)
- Typical concerns and table-format overrides surfaced throughout

See full profile at `.claude/references/journal-profiles.md`.

## B. Pipeline used

1. `/review-paper papers/faccoes_e_competicao_politica.pdf --peer AEJApplied --no-cross-artifact` → editor desk review + 2 referees + editorial decision (4 files, Parts II + III)
2. `/seven-pass-review papers/faccoes_e_competicao_politica.pdf` → 7 parallel lens reviews + synthesizer (8 files, Parts IV + V) — **shared across all 4 journal reviews**
3. `/master-synthesis --advisor-name "Pedro H. C. Santanna" --target-journal AEJApplied` → consolidates the 13 underlying reports into the Part I master synthesis (this document)

Total: 14 underlying reports → 1 final package.

## C. How this compares to other journal reviews

This is one of **4 journal-calibrated reviews** produced for this manuscript. The seven-pass lens reports (Part V) are shared across all 4; the peer-review pipeline (Parts II + III) and master synthesis (Part I) are journal-specific.

Companion documents:
- `REVIEW_FOR_faccoes_competicao_politica_JOP.md` — Journal of Politics
- `REVIEW_FOR_faccoes_competicao_politica_AEJApplied.md` — AEJ: Applied Economics
- `REVIEW_FOR_faccoes_competicao_politica_JDE.md` — Journal of Development Economics
- `REVIEW_FOR_faccoes_competicao_politica_AJPS.md` — American Journal of Political Science

*Generated: 2026-04-18 via the `agente referee` pipeline adapted from `pedrohcgs/claude-code-my-workflow`.*
