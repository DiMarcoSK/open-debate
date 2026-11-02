# Backlog - Fixture

Capacity: 2 x 8 x 5 x 0.7 = 56 working days; backlog sums 29 days; fits.

## Phase 0 - Foundation (week 1)

- [ ] B01 [P] Provision staging with deploy. Acceptance: deploy in 5 min (ADR-0001) {E01, est M, #docs}
- [ ] B02 Publish the secret in a vault. Acceptance: 0 secrets in the repo (ADR-0002) {E01, est S, dep B01, #security}
- [ ] B03 Restore a backup end to end. Acceptance: restore in 1 h (ADR-0003) {E01, est M, dep B01, #data}

## Phase 1 - Walking skeleton (week 2)

- [ ] B04 [P] Receive an alert up to the screen. Acceptance: 1 alert in 2 s (spec 01:T001) {E01, est L, dep B02 B03, #observability}
- [ ] B05 Triage an alert from the queue. Acceptance: triage in 30 s (spec 02:T001) {E01, est L, dep B04, #states}
- [ ] B06 Send the daily report. Acceptance: 1 PDF per day (spec 03:T001) {E01, est M, dep B05, #analytics}

## Phase 2 - Polish (week 3)

- [ ] B07 Audit design-system on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #design-system}
- [ ] B08 Audit a11y on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #a11y}
- [ ] B09 Audit responsive on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #responsive}
- [ ] B10 Audit motion on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #motion}
- [ ] B11 Audit copy on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #copy}
- [ ] B12 Audit perf on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #perf}
- [ ] B13 Audit onboarding on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #onboarding}
- [ ] B14 Audit signature on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #signature #brand}
- [ ] B15 Audit visual-qa on the screens. Acceptance: 0 findings on 3 screens (SDD-5) {E02, est S, dep B06, #visual-qa}

## Phase 3 - Launch (week 4)

- [ ] B16 [P] Open the beta to users. Acceptance: 5 active users (SDD-1) {E03, est M, dep B15, #launch}

## Post-launch

- [ ] B17 Export to BI. Acceptance: 1 export per day (SDD-6) {E03, est S, dep B16, #docs}

## Definition of Done

- acceptance verified
