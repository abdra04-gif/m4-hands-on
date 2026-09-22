# Session 4A: AI-assisted debugging

Repository: https://github.com/abdra04-gif/m4-hands-on

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
