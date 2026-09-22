# Session 4A: AI-assisted debugging

Repository: https://github.com/abdra04-gif/m4-hands-on
Pull request (Session 4B commits): https://github.com/abdra04-gif/m4-hands-on/pull/1

## Part A: Explain the stack trace

### Prompt

> Explain this Java stack trace in plain English. What is
> the most likely root cause? Do NOT propose a patch yet.

### AI reply

The test `quotesDiscountForLoyalCustomer` failed because it expected a final amount of `90.0`, but `PriceEngine.quote` returned `95.0`. The assertion was made in `PriceEngineTest` at line 92. The likely root cause is in the loyalty-tier calculation in `PriceEngine.quote`: a customer with exactly 5 loyalty years is being treated as a tier-2 customer with a 5% discount instead of a tier-3 customer with a 10% discount. The boundary condition for the tier-3 branch is probably off by one.

### My note

I agree: the expected and actual values identify the loyalty discount boundary, and the source confirms the condition uses `years > 5`.
The full stack trace is useful for locating the failing test and source line, but the first assertion-failure line plus the test name would have been enough to form this diagnosis.

## Part B: Propose and verify the patch

### Prompt

> Given root cause X (paste the diagnosis from previous Part),
> write the smallest patch that fixes the bug without
> changing behaviour on any other test. Show only the diff.

Root cause X: The loyalty-tier calculation uses `years > 5` for the 10% tier, so a customer with exactly 5 years receives the 5% tier. The 10% tier should apply for 5 or more years.

### AI reply

```diff
--- a/src/PriceEngine.java
+++ b/src/PriceEngine.java
@@
-        if (years > 5) {
+        if (years >= 5) {
```

This changes only the boundary case of exactly 5 loyalty years and leaves all other tested behaviour unchanged.

### Verification

Before fix: `make test` → 9 tests successful, 1 test failed (`quotesDiscountForLoyalCustomer`, expected `90.0` but got `95.0`).

Applied the one-line patch and ran `make test` again.

After fix: `make test` → 10 tests started, 10 tests successful, 0 tests failed.

## Part C: Reflection

The patch reply was the most useful because it identified the exact one-character boundary change and constrained the behaviour change to the failing case. The explanation reply was also useful because it connected the assertion values to the loyalty-tier branch without guessing about unrelated code. The full stack trace is helpful for confirming the failing test and source location, but a concise assertion failure containing the expected value, actual value, test name, and source line would usually be sufficient. Pasting only one or two unrelated stack-trace lines would make the diagnosis less reliable because they might omit the assertion message and the application frame.

# Session 4B: Reducing cyclomatic complexity

## Setup

Continued on `main` (same branch as Session 4A, with the loyalty-discount bug already fixed and committed).

Installed PMD 7.27.0 and SpotBugs 4.10.4 by wiring `make pmd` and `make spotbugs` targets into the Makefile (binaries download into `libs/`, which is already gitignored, so nothing large gets committed).

`make pmd` on `PriceEngine.quote`: **cyclomatic complexity = 23**.

Manual count (McCabe: start at 1, +1 per `if`/`else if`/`for`/`&&`/`||`): I counted 20 decision points → estimate of **21**. Close to PMD's 23 but not an exact match — PMD's internal decision-point bookkeeping differs slightly from a hand count, which is expected; the point of the exercise was to see whether they're in the same ballpark, and they are.

`make spotbugs` on the built classes: **2 findings**, both on `Order` — `EI_EXPOSE_REP2` (constructor stores the caller's mutable `lines` list by reference) and `EI_EXPOSE_REP` (the `lines()` accessor returns that same mutable reference).

## Part A: Rank refactor targets

### Prompt

> Rank the methods in this file by refactoring priority.
> For each, give: (a) current cyclomatic complexity estimate,
> (b) the single refactor move you would apply first
> (extract-method, flatten-guard-clauses, replace-loop-
> with-pipeline, or rename), (c) one sentence on the expected
> complexity reduction. Do not propose code yet.

### Ranking

`PriceEngine.java` has exactly one method, so the ranking is a single entry:

1. **`quote(Order, Customer)`** — (a) CC = 23 (PMD-measured). (b) `extract-method` on the loyalty-tier discount block first: it is self-contained (reads only `customer.loyaltyYears()` and `subtotal`, writes only `running`) and none of the other blocks (promo code, tax) depend on its intermediate `years`/`loyaltyRate` variables. (c) Extracting it removes the three tier `if`/`else if` branches plus the `if (loyaltyRate > 0.0)` guard from `quote`, an expected drop of about 4 complexity points.

## Part B: Apply one extract-method refactor

### Prompt

> Extract the loyalty-tier discount block into a private
> helper method `applyLoyaltyDiscount(...)`. Do NOT change
> public method signatures. Show the diff.

### AI reply (diff)

```diff
--- a/src/PriceEngine.java
+++ b/src/PriceEngine.java
@@
-        // 4. Loyalty-tier discount
-        //    tier 1 (1-2 years):  2% off
-        //    tier 2 (3-4 years):  5% off
-        //    tier 3 (5+ years):  10% off
-        int years = customer.loyaltyYears();
-        double loyaltyRate;
-        if (years >= 5) {
-            loyaltyRate = 0.10;
-        } else if (years >= 3) {
-            loyaltyRate = 0.05;
-        } else if (years >= 1) {
-            loyaltyRate = 0.02;
-        } else {
-            loyaltyRate = 0.0;
-        }
-        if (loyaltyRate > 0.0) {
-            running = running.subtract(subtotal.times(loyaltyRate));
-        }
+        // 4. Loyalty-tier discount
+        running = applyLoyaltyDiscount(running, subtotal, customer);
@@
+    private static Money applyLoyaltyDiscount(Money running, Money subtotal, Customer customer) {
+        int years = customer.loyaltyYears();
+        double loyaltyRate;
+        if (years >= 5) {
+            loyaltyRate = 0.10;
+        } else if (years >= 3) {
+            loyaltyRate = 0.05;
+        } else if (years >= 1) {
+            loyaltyRate = 0.02;
+        } else {
+            loyaltyRate = 0.0;
+        }
+        if (loyaltyRate > 0.0) {
+            return running.subtract(subtotal.times(loyaltyRate));
+        }
+        return running;
+    }
```

### Review before applying

Public signature `quote(Order, Customer): Money` is unchanged. The new helper is `private static`, uses the same types (`Money`, `Money`, `Customer`) already in scope, has no `final` parameters to lose (none were `final` in the original either), and no early return was silently dropped — the original block never returned early, it only assigned `loyaltyRate` and fell through, and the helper preserves that by returning explicitly on both exit paths.

### Verification

`make test` → 10/10 still pass.
`make pmd` → `quote` complexity dropped from **23 to 19** (−4), matching the Part A estimate.

Commit: `ea5d0e7 Extract loyalty-tier discount into applyLoyaltyDiscount helper` (atomic — Makefile tooling changes were committed separately in `e245cc8`).

## Part C: Fix a SpotBugs finding with AI

Finding picked: **`EI_EXPOSE_REP2`** on `Order`'s constructor (`Order.java:4`) — "may expose internal representation by storing an externally mutable object into lines".

### Prompt

> SpotBugs reports the finding EI_EXPOSE_REP2 on the following
> code. Explain what the rule requires and show the smallest
> patch that satisfies it without changing behaviour. Show the
> diff.

### AI reply

The rule requires that a class never keep a caller-supplied mutable reference (such as a `List`) as its own internal state, because the caller could mutate it after construction and silently change the "immutable" record. The smallest fix is a defensive copy in the record's compact constructor.

```diff
--- a/src/Order.java
+++ b/src/Order.java
@@
 public record Order(long id, List<Line> lines, boolean expedited,
                     String promoCode) {
+
+    public Order {
+        lines = List.copyOf(lines);
+    }
```

### Verification

Applied. Re-ran `make spotbugs`: both `EI_EXPOSE_REP2` and its paired finding `EI_EXPOSE_REP` (on the `lines()` accessor) are gone — `List.copyOf` fixes the root cause for both, since the stored and returned list is now immutable either way.
Re-ran `make test`: 10/10 still pass (no test mutates the `lines` list after constructing an `Order`).

Commit: `2684293 Fix SpotBugs EI_EXPOSE_REP2 / EI_EXPOSE_REP on Order`.

## Part D: Reflection

Cyclomatic complexity of `quote` dropped from 23 to 19 (PMD-measured), a reduction of 4 — exactly the four decision points (`years>=5`, `years>=3`, `years>=1`, `loyaltyRate>0.0`) that moved into `applyLoyaltyDiscount`. The SpotBugs fix needed a mix of both: the AI's explanation of `EI_EXPOSE_REP2`/`EI_EXPOSE_REP` was enough to know *what* to change (add a defensive copy), but confirming it was *safe* — that no test or caller mutates the `lines` list after construction — required reading the surrounding code myself rather than trusting the explanation alone. One rejected refactor: the AI also suggested replacing the promo-code `if`/`else if` chain (step 3 of `quote`) with a `Map<String, Double>` lookup from code to discount rate. I rejected it because `VIP20` is not a pure code-to-rate mapping — it only applies when `customer.loyaltyYears() >= 3` — so a flat map would either drop that eligibility check (a real behaviour change) or need an ugly special case bolted back on next to the map, which ends up no simpler than the existing `if` chain.

## Deliverables

- Branch: `main` (same branch as Session 4A), pushed to https://github.com/abdra04-gif/m4-hands-on.
- Pull request with the two additional commits (extract-method refactor `ea5d0e7` + SpotBugs fix `2684293`, plus the supporting Makefile/PMD-SpotBugs wiring `e245cc8` and this PROMPTS.md update): https://github.com/abdra04-gif/m4-hands-on/pull/1 (base branch `session-4a-baseline` = state at the end of Session 4A, head `main`).
- PROMPTS.md (this file) containing the ranking, the applied refactor, and the reflection.
