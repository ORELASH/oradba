# Bank Manager Queries — Source Tables & Output Spec

## Overview

Two API queries that serve the Bank Manager (BM) application:
1. **Detailed Deposit Accounts** — denormalized view of all deposit accounts (44 columns)
2. **Detailed Deposit Transactions** — transactions joined with account context (39 columns)

Currently implemented as Postgres functions (`dwh.bm_get_all_detailed_deposit_accounts()`, `dwh.bm_get_all_detailed_deposit_transactions()`) that run twice daily via double-buffering into staging tables.

---

## 1. Detailed Deposit Accounts

### Source Tables

| Source Table | Schema | Purpose |
|-------------|--------|---------|
| `deposit.v_deposit_account_detail` | deposit | Main account view (joins deposit_account + params + computed_params + evaluation) |
| `product.proposal` | product | Proposal reference, name, version |
| `product.template` | product | Template ID (product type) |
| `applicative.financial_request` | applicative | Channel, method, banker info (for OPEN requests) |
| `applicative.channel` | applicative | Channel name lookup |
| `deposit.v_deposit_account_detail_evaluation` | deposit | Premature balance calculations |
| `migration.migrated_accounts` | migration | Legacy migration date |

### Output Columns (44)

| # | Column | Type | Source | Description |
|---|--------|------|--------|-------------|
| 1 | tm_account_id | UUID | deposit_account_detail | Unique account identifier |
| 2 | branch_number | CHAR(4) | customer_id substring(1,3) | Branch code |
| 3 | account_type | CHAR(4) | linked_account_id substring(5,3) | Account type code |
| 4 | account_number | TEXT | linked_account_id substring(9+) | Account number |
| 5 | customer_id | TEXT | deposit_account_detail | Full customer ID |
| 6 | proposal_number | TEXT | proposal.reference | Proposal reference |
| 7 | deposit_serial_number | TEXT | deposit_account_detail.account_serial | Serial number |
| 8 | proposal_name | TEXT | proposal.name->>'he' | Hebrew proposal name |
| 9 | opened_value_date | DATE | deposit_account_detail | Opening date |
| 10 | created_at | TIMESTAMPTZ | deposit_account_detail | Creation timestamp |
| 11 | maturity_date | DATE | deposit_account_detail | Maturity date |
| 12 | deposit_period | TEXT | deposit_account_detail.period_override | Period term |
| 13 | booked_principal_balance | NUMERIC(15,2) | deposit_account_detail | Principal balance |
| 14 | initial_balance | NUMERIC(15,2) | deposit_account_detail | Initial deposit amount |
| 15 | interests_periods_rates | TEXT | period_term JSON (aggregated) | Pipe-delimited rates per period |
| 16 | total_benefit_rate | TEXT | financial_request pricing JSON | Pipe-delimited benefit rates |
| 17 | booked_total_balance | NUMERIC(15,2) | deposit_account_detail | Total balance (principal + interest) |
| 18 | total_balance_maturity_adjusted | NUMERIC(15,2) | deposit_account_detail | Maturity-adjusted balance |
| 19 | total_balance_at_maturity | NUMERIC(15,2) | deposit_account_detail | Expected balance at maturity |
| 20 | total_balance_at_next_exit_point | NUMERIC(15,2) | deposit_account_detail | Balance at next exit |
| 21 | total_balance_at_premature | NUMERIC(15,2) | evaluation | Balance if broken early |
| 22 | principal_balance_at_premature | NUMERIC(15,2) | evaluation | Principal if broken early |
| 23 | interest_balance_at_premature | TEXT | evaluation | Interest if broken early |
| 24 | tax_and_penalty_at_premature | NUMERIC(15,2) | evaluation (tax + penalty) | Tax + penalty for early break |
| 25 | channel | TEXT | channel.channel_name | Opening channel name |
| 26 | method | TEXT | financial_request.initiation_method | Initiation method |
| 27 | is_lien | BOOLEAN | deposit_account_detail | Lien flag |
| 28 | is_foreclosed | BOOLEAN | deposit_account_detail | Foreclosure flag |
| 29 | interest_type | TEXT | deposit_account_detail | Fixed/variable |
| 30 | funds_transfer_price_rate | TEXT | period_term JSON (aggregated) | FTP rate per period |
| 31 | margin_rate | TEXT | period_term JSON (aggregated) | Margin rate per period |
| 32 | template_id | TEXT | template.id | Product template ID |
| 33 | banker_branch_code | TEXT | financial_request | Banker's branch |
| 34 | banker_id | TEXT | financial_request | Banker ID |
| 35 | next_exit_point | DATE | deposit_account_detail | Next exit date |
| 36 | deposit_status | TEXT | deposit_account_detail.status | Account status |
| 37 | allowed_currency | CHAR(4) | deposit_account_detail.currency | Currency (ILS/USD/EUR) |
| 38 | orig_tm_account_id | TEXT | self-join on orig_tm_account_id | Original account (for renewals) |
| 39 | orig_deposit_serial_number | TEXT | self-join | Original serial |
| 40 | orig_proposal_number | TEXT | self-join | Original proposal |
| 41 | migration_date | TIMESTAMPTZ | migrated_accounts | Legacy system migration date |

### Filter/Join Logic

- Only accounts from `v_deposit_account_detail` (active view)
- INNER JOIN to `proposal` (every account has a proposal)
- INNER JOIN to `template` (matched by proposal.template_id + version)
- LEFT JOIN to `financial_request` where type='OPEN' AND status='committed'
- LEFT JOIN to `channel` by channel number
- LEFT JOIN to `evaluation` for premature calculations
- LEFT JOIN to `migrated_accounts` for legacy data
- Period rates extracted from JSONB array (`period_term`) via `JSONB_ARRAY_ELEMENTS`
- Benefit rates from `financial_request.data->'pricing'->'amounts'->0->'periods'` JSONB

---

## 2. Detailed Deposit Transactions

### Source Tables

| Source Table | Schema | Purpose |
|-------------|--------|---------|
| `deposit.v_deposit_transaction_detail` | deposit | Transaction view (joins deposit_transaction + details) |
| `dwh.bm_deposit_accounts_staging` | dwh | Pre-computed accounts staging (from query #1) |

### Output Columns (39)

| # | Column | Type | Source | Description |
|---|--------|------|--------|-------------|
| 1 | tm_account_id | UUID | accounts staging | Account ID |
| 2 | transaction_id | UUID | transaction.batch_transaction_id | Transaction ID |
| 3 | total_amount | NUMERIC(15,2) | transaction | Total transaction amount |
| 4 | tax_amount | NUMERIC(15,2) | withdrawal_report->>'tax' | Tax portion |
| 5 | penalty_amount | NUMERIC(15,2) | withdrawal_report->>'penalty' | Penalty portion |
| 6 | interest | NUMERIC(15,2) | withdrawal_report->>'interest' | Interest portion |
| 7 | principal | NUMERIC(15,2) | withdrawal_report->>'principal' | Principal portion |
| 8 | total_revenue | NUMERIC(15,2) | withdrawal_report->>'total_revenue' | Revenue portion |
| 9 | total_remaining_principal | NUMERIC(15,2) | withdrawal_report->>'total_remaining_principal' | Remaining after transaction |
| 10 | opened_value_date | DATE | accounts staging | Account opening date |
| 11 | value_date | DATE | transaction | Transaction value date |
| 12 | booking_date | DATE | transaction | Transaction booking date |
| 13 | maturity_date | DATE | accounts staging | Account maturity |
| 14 | reference_number | INTEGER | transaction | Reference number |
| 15 | account_type | CHAR(4) | accounts staging | Account type code |
| 16 | branch_number | CHAR(4) | accounts staging | Branch code |
| 17 | allowed_currency | CHAR(4) | accounts staging | Currency |
| 18 | banker_branch_code | CHAR(4) | transaction | Banker's branch |
| 19 | customer_id | TEXT | accounts staging | Customer ID |
| 20 | account_number | TEXT | accounts staging | Account number |
| 21 | deposit_status | TEXT | accounts staging | Account status |
| 22 | transaction_code_domain | TEXT | transaction_code JSON->>'domain' | ISO20022 domain |
| 23 | transaction_code_family | TEXT | transaction_code JSON->>'family' | ISO20022 family |
| 24 | transaction_code_subfamily | TEXT | transaction_code JSON->>'subfamily' | ISO20022 subfamily |
| 25 | transaction_type | TEXT | transaction | Transaction type |
| 26 | transaction_status | TEXT | transaction.status | Transaction status |
| 27 | channel | TEXT | transaction | Channel used |
| 28 | initiator | TEXT | transaction | Who initiated |
| 29 | performer | TEXT | transaction | Who performed |
| 30 | initiation_method | TEXT | transaction | Method (online/branch) |
| 31 | banker_id | TEXT | transaction | Banker ID |
| 32 | phase | TEXT | transaction | Transaction phase |
| 33 | currency | TEXT | transaction | Transaction currency |
| 34 | user_id | TEXT | transaction | User ID |
| 35 | created_at | TIMESTAMPTZ | transaction | Transaction creation time |
| 36 | is_reversal | BOOLEAN | transaction | Reversal flag |
| 37 | margin_rate | TEXT | accounts staging | Margin rate (from account) |
| 38 | proposal_number | TEXT | accounts staging | Proposal reference |
| 39 | deposit_serial_number | TEXT | accounts staging | Deposit serial |

### Filter/Join Logic

- INNER JOIN transactions to accounts (by tm_account_id)
- Transactions come from `v_deposit_transaction_detail` (view on deposit_transaction)
- Account context comes from pre-computed staging (`bm_deposit_accounts_staging`)
- `withdrawal_report` is a JSONB column on transactions — extracted for tax/penalty/interest breakdown
- `transaction_code` is a JSONB column — extracted for ISO20022 categorization
- Ordered by tm_account_id, batch_transaction_id

---

## Key Considerations for Redshift Implementation

### JSONB Handling
Both queries rely heavily on Postgres JSONB:
- `period_term` → array of period objects with rates
- `financial_request.data` → nested pricing structure
- `withdrawal_report` → transaction breakdown
- `transaction_code` → ISO20022 codes

Redshift equivalent: `JSON_EXTRACT_PATH_TEXT()` or `SUPER` type.

### Aggregation Patterns
- `STRING_AGG(..., ' | ' ORDER BY ...)` — pipe-delimited multi-period rates
- `JSONB_ARRAY_ELEMENTS` — explode JSON arrays for aggregation

Redshift equivalent: `LISTAGG()`, `JSON_PARSE()` + `UNNEST`.

### Data Volume
- Accounts: ~26K active accounts (growing)
- Transactions: ~5M rows
- Runs twice daily (double-buffered staging tables)

### Dependencies Between Queries
Query #2 (transactions) depends on Query #1 (accounts) — it reads from `bm_deposit_accounts_staging` which is populated by the accounts query. Must run in sequence.
