# Equity Market Intelligence & Portfolio Analysis Database — Phase II

## (1) Draft Schema

Below are the relations converted directly from the ER diagram. Primary keys are **underlined**, foreign keys are in *italic*.

1. **Sector**(<u>sector_id</u>, sector_name)

2. **Industry**(<u>industry_id</u>, industry_name, *sector_id*)

3. **Company**(<u>company_id</u>, company_name, *industry_id*, country)

4. **Exchange**(<u>exchange_id</u>, exchange_name, country, timezone)

5. **Security**(<u>security_id</u>, ticker, *exchange_id*, currency, security_type)

6. **Stock**(<u>*security_id*</u>, *company_id*)

7. **ETF**(<u>*security_id*</u>, fund_name, expense_ratio)

8. **Option_Contract**(<u>*security_id*</u>, <u>expiration_date</u>, <u>strike_price</u>, <u>option_type</u>, implied_volatility, open_interest)

9. **Portfolio**(<u>portfolio_id</u>, portfolio_name, owner_name)

10. **Holding**(<u>*portfolio_id*</u>, <u>*security_id*</u>, shares, average_cost)

11. **Price**(<u>*security_id*</u>, <u>trade_date</u>, open, high, low, close, volume)

12. **Financial_Snapshot**(<u>snapshot_id</u>, *security_id*, snapshot_date, market_cap, pe_ratio, eps, beta)

13. **Corporate_Action**(<u>action_id</u>, *security_id*, action_date, action_type, amount)

### Conversion Decisions

The ER diagram uses an ISA (is-a) hierarchy for Security, with Stock, ETF, and Option Contract as subtypes. We converted this using the separate-table approach: the parent entity Security stores shared attributes, and each subtype (Stock, ETF, Option_Contract) has its own table whose primary key is a foreign key referencing Security. This avoids NULLs that would arise from merging all subtypes into a single table and allows subtype-specific constraints (e.g., Option_Contract's composite key). The `security_type` discriminator column in Security indicates which subtype table holds the additional data.

The Holding relation is derived from the many-to-many relationship between Portfolio and Security, with `shares` and `average_cost` as relationship attributes.

Option_Contract retains a composite primary key (security_id, expiration_date, strike_price, option_type) as shown in the ER diagram, since these four attributes together uniquely identify each option contract in real-world financial markets.

---

## (3) Final Schema — Normalization & Refinements

### (b) Functional Dependencies and 3NF Analysis

We define the set **F** of functional dependencies for each relation and verify 3NF compliance. A relation is in 3NF if for every non-trivial FD X → A, either X is a superkey or A is part of a candidate key.

---

#### Sector(<u>sector_id</u>, sector_name)

**FDs:**
- sector_id → sector_name

**Candidate key:** {sector_id}

**3NF check:** The only non-trivial FD has sector_id (a superkey) on the LHS. Already in 3NF.

---

#### Industry(<u>industry_id</u>, industry_name, *sector_id*)

**FDs:**
- industry_id → industry_name, sector_id

**Candidate key:** {industry_id}

**3NF check:** LHS is a superkey. Already in 3NF.

---

#### Company(<u>company_id</u>, company_name, *industry_id*, country)

**FDs:**
- company_id → company_name, industry_id, country

**Candidate key:** {company_id}

**Discussion:** One might argue company_name → company_id (companies have unique names). However, in practice, company names are not globally unique (e.g., "Apple" in different countries), so we do not include this FD. No transitive dependencies exist — `country` describes the company's domicile, not the industry.

**3NF check:** Already in 3NF.

---

#### Exchange(<u>exchange_id</u>, exchange_name, country, timezone)

**FDs:**
- exchange_id → exchange_name, country, timezone

**Candidate key:** {exchange_id}

**Discussion:** Country does not determine timezone (a country can span multiple timezones), and timezone does not determine country. No transitive dependency.

**3NF check:** Already in 3NF.

---

#### Security(<u>security_id</u>, ticker, *exchange_id*, currency, security_type)

**FDs:**
- security_id → ticker, exchange_id, currency, security_type
- (ticker, exchange_id) → security_id, currency, security_type *(a ticker is unique within an exchange)*

**Candidate keys:** {security_id}, {ticker, exchange_id}

**Discussion:** We could argue exchange_id → currency (an exchange operates in one currency), but exchanges like the London Stock Exchange list securities in multiple currencies (GBP, USD, EUR). Thus we keep currency as a per-security attribute with no transitive dependency through exchange_id.

**3NF check:** Already in 3NF.

---

#### Stock(<u>*security_id*</u>, *company_id*)

**FDs:**
- security_id → company_id

**Candidate key:** {security_id}

**3NF check:** Already in 3NF.

---

#### ETF(<u>*security_id*</u>, fund_name, expense_ratio)

**FDs:**
- security_id → fund_name, expense_ratio

**Candidate key:** {security_id}

**3NF check:** Already in 3NF.

---

#### Option_Contract(<u>*security_id*</u>, <u>expiration_date</u>, <u>strike_price</u>, <u>option_type</u>, implied_volatility, open_interest)

**FDs:**
- (security_id, expiration_date, strike_price, option_type) → implied_volatility, open_interest

**Candidate key:** {security_id, expiration_date, strike_price, option_type}

**Discussion:** In the draft schema, this relation has a 4-attribute composite key. For practical purposes in SQL (especially for foreign key references from other tables), we introduce a surrogate key `option_id` in the final schema. The natural composite key is preserved as a UNIQUE constraint.

**3NF check:** Already in 3NF. (All non-key attributes depend on the full candidate key with no partial or transitive dependencies.)

---

#### Portfolio(<u>portfolio_id</u>, portfolio_name, owner_name)

**FDs:**
- portfolio_id → portfolio_name, owner_name

**Candidate key:** {portfolio_id}

**3NF check:** Already in 3NF.

---

#### Holding(<u>*portfolio_id*</u>, <u>*security_id*</u>, shares, average_cost)

**FDs:**
- (portfolio_id, security_id) → shares, average_cost

**Candidate key:** {portfolio_id, security_id}

**3NF check:** No partial dependencies (shares and average_cost both require the full composite key). No transitive dependencies. Already in 3NF.

---

#### Price(<u>*security_id*</u>, <u>trade_date</u>, open, high, low, close, volume)

**FDs:**
- (security_id, trade_date) → open, high, low, close, volume

**Candidate key:** {security_id, trade_date}

**3NF check:** All non-key attributes depend on the full composite key. No partial or transitive dependencies. Already in 3NF.

---

#### Financial_Snapshot(<u>snapshot_id</u>, *security_id*, snapshot_date, market_cap, pe_ratio, eps, beta)

**FDs:**
- snapshot_id → security_id, snapshot_date, market_cap, pe_ratio, eps, beta
- (security_id, snapshot_date) → snapshot_id, market_cap, pe_ratio, eps, beta *(one snapshot per security per date)*

**Candidate keys:** {snapshot_id}, {security_id, snapshot_date}

**3NF check:** Already in 3NF. (All non-trivial FDs have a superkey on the LHS.)

---

#### Corporate_Action(<u>action_id</u>, *security_id*, action_date, action_type, amount)

**FDs:**
- action_id → security_id, action_date, action_type, amount

**Candidate key:** {action_id}

**3NF check:** Already in 3NF.

---

### (c) Revisions from Draft to Final Schema

1. **Option_Contract surrogate key:** We introduce `option_id` (auto-increment) as the primary key for Option_Contract. The natural composite key (security_id, expiration_date, strike_price, option_type) is retained as a UNIQUE constraint. This simplifies any future foreign key references and JOINs.

2. **UNIQUE constraint on (ticker, exchange_id):** Since (ticker, exchange_id) is a candidate key for Security, we add a UNIQUE constraint to enforce this in the database.

3. **UNIQUE constraint on (security_id, snapshot_date):** Since this is a candidate key for Financial_Snapshot, we enforce it.

4. **CHECK constraints:** We add domain constraints such as `security_type IN ('stock', 'etf', 'option')`, `option_type IN ('call', 'put')`, `shares > 0`, `volume >= 0`, non-negative prices, etc.

5. **ON DELETE behavior:** We use `CASCADE` for subtype tables (Stock, ETF, Option_Contract) since deleting a Security should remove its subtype row. For Holding, Price, Financial_Snapshot, and Corporate_Action we also use CASCADE since these are existence-dependent on their parent. Industry references Sector with RESTRICT (don't allow deleting a sector that has industries).

---

## Final Relational Schema

1. **Sector**(<u>sector_id</u>, sector_name)

2. **Industry**(<u>industry_id</u>, industry_name, *sector_id*)

3. **Company**(<u>company_id</u>, company_name, *industry_id*, country)

4. **Exchange**(<u>exchange_id</u>, exchange_name, country, timezone)

5. **Security**(<u>security_id</u>, ticker, *exchange_id*, currency, security_type)
   - UNIQUE(ticker, exchange_id)
   - CHECK(security_type IN ('stock', 'etf', 'option'))

6. **Stock**(<u>*security_id*</u>, *company_id*)

7. **ETF**(<u>*security_id*</u>, fund_name, expense_ratio)
   - CHECK(expense_ratio >= 0)

8. **Option_Contract**(<u>option_id</u>, *security_id*, expiration_date, strike_price, option_type, implied_volatility, open_interest)
   - UNIQUE(security_id, expiration_date, strike_price, option_type)
   - CHECK(option_type IN ('call', 'put'))
   - CHECK(strike_price > 0)

9. **Portfolio**(<u>portfolio_id</u>, portfolio_name, owner_name)

10. **Holding**(<u>*portfolio_id*</u>, <u>*security_id*</u>, shares, average_cost)
    - CHECK(shares > 0), CHECK(average_cost >= 0)

11. **Price**(<u>*security_id*</u>, <u>trade_date</u>, open, high, low, close, volume)
    - CHECK(volume >= 0)

12. **Financial_Snapshot**(<u>snapshot_id</u>, *security_id*, snapshot_date, market_cap, pe_ratio, eps, beta)
    - UNIQUE(security_id, snapshot_date)

13. **Corporate_Action**(<u>action_id</u>, *security_id*, action_date, action_type, amount)
    - CHECK(action_type IN ('dividend', 'split', 'reverse_split', 'spinoff'))
