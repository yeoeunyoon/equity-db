-- load.sql
-- Loads data from TSV files into the Equity Market Intelligence database.
-- Assumes setup.sql has been run and tables exist.
-- TSV files are in the ./data/ directory relative to this script.
--
-- Usage on db.cs.jhu.edu:
--   mysql -u <username> -p <dbname> < load.sql
--
-- NOTE: If LOAD DATA LOCAL INFILE is disabled on the server, use
--       mysqlimport or replace with INSERT statements (see below).

-- Disable FK checks during bulk load for performance
SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA LOCAL INFILE 'data/sector.tsv'
INTO TABLE Sector
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(sector_id, sector_name);

LOAD DATA LOCAL INFILE 'data/industry.tsv'
INTO TABLE Industry
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(industry_id, industry_name, sector_id);

LOAD DATA LOCAL INFILE 'data/company.tsv'
INTO TABLE Company
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(company_id, company_name, industry_id, country);

LOAD DATA LOCAL INFILE 'data/exchange.tsv'
INTO TABLE Exchange
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(exchange_id, exchange_name, country, timezone);

LOAD DATA LOCAL INFILE 'data/security.tsv'
INTO TABLE Security
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, ticker, exchange_id, currency, security_type);

LOAD DATA LOCAL INFILE 'data/stock.tsv'
INTO TABLE Stock
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, company_id);

LOAD DATA LOCAL INFILE 'data/etf.tsv'
INTO TABLE ETF
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, fund_name, expense_ratio);

LOAD DATA LOCAL INFILE 'data/option_contract.tsv'
INTO TABLE Option_Contract
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(option_id, security_id, expiration_date, strike_price,
 option_type, implied_volatility, open_interest);

LOAD DATA LOCAL INFILE 'data/portfolio.tsv'
INTO TABLE Portfolio
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(portfolio_id, portfolio_name, owner_name);

LOAD DATA LOCAL INFILE 'data/holding.tsv'
INTO TABLE Holding
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(portfolio_id, security_id, shares, average_cost);

LOAD DATA LOCAL INFILE 'data/price.tsv'
INTO TABLE Price
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, trade_date, open, high, low, close, volume);

LOAD DATA LOCAL INFILE 'data/financial_snapshot.tsv'
INTO TABLE Financial_Snapshot
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(snapshot_id, security_id, snapshot_date, market_cap,
 pe_ratio, eps, beta);

LOAD DATA LOCAL INFILE 'data/corporate_action.tsv'
INTO TABLE Corporate_Action
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(action_id, security_id, action_date, action_type, amount);

-- Re-enable FK checks
SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Data load complete.' AS status;
