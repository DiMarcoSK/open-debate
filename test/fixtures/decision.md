# Decision

## 1. Weights
speed=40 cost=30 deadline=30

## 2. Scores

### D1 Monolith or services

| Option | speed | cost | deadline | Total |
|---|---|---|---|---|
| Monolith | 4 | 4 | 5 | 430 |
| Services | 3 | 2 | 4 | 300 |

### D2 Visual direction

| Option | speed | cost | deadline | Total |
|---|---|---|---|---|
| Dense | 5 | 3 | 3 | 380 |
| Light | 3 | 3 | 3 | 300 |

### D3 Database

| Option | speed | cost | deadline | Total |
|---|---|---|---|---|
| Cloud SQL | 4 | 4 | 4 | 400 |
| Firestore | 4 | 3 | 3 | 340 |

## 3. ADRs

## ADR-0001 Use a modular monolith

- Status: accepted

### Context and problem

Driver and number.

### Considered options

- A
- B

### Decision outcome

Chosen: "A", because 80 x 60.

### Consequences

- Good: simple

### Confirmation

Test in CI.

### Dissent

none

## ADR-0002 Use Cloud Run

- Status: accepted

### Context and problem

Driver and number.

### Considered options

- A
- B

### Decision outcome

Chosen: "A", because 80 x 60.

### Consequences

- Good: simple

### Confirmation

Test in CI.

### Dissent

none

## ADR-0003 Use Cloud SQL

- Status: accepted

### Context and problem

Driver and number.

### Considered options

- A
- B

### Decision outcome

Chosen: "A", because 80 x 60.

### Consequences

- Good: simple

### Confirmation

Test in CI.

### Dissent

none

## 7. Specs

`01 ingestion` - receives alerts
`02 triage` - triage queue
`03 report` - daily report

## 8. Dissent

debate-k8s: portability; reopens if > 10 services

## 9. Vetoes

| Target | Veto | Ruling | Reason |
|---|---|---|---|
| debate-gcp | budget | upheld | cost |
| debate-gcp | budget | upheld | cost |
| debate-design | budget | rejected | outside the role |
| debate-arch | budget | rejected | outside the role |
| debate-x0 | budget | rejected | outside the role |
| debate-x1 | budget | rejected | outside the role |
| debate-x2 | budget | rejected | outside the role |
| debate-x3 | budget | rejected | outside the role |
| debate-x4 | budget | rejected | outside the role |
