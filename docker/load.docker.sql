-- load.docker.sql
-- Server-side bulk load for the Equity Market Intelligence database, run by the
-- MySQL container's init process (after 01-setup.sql creates the tables).
--
-- Uses LOAD DATA INFILE (NOT LOCAL): the TSVs are read from the server's
-- secure_file_priv directory. docker-compose.yml mounts ./data at
-- /var/lib/mysql-files/data (which is under secure_file_priv), and initdb
-- scripts run as root, so they have the FILE privilege required here.

USE equity_db;

SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA INFILE '/var/lib/mysql-files/data/sector.tsv'
INTO TABLE Sector
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(sector_id, sector_name);

LOAD DATA INFILE '/var/lib/mysql-files/data/industry.tsv'
INTO TABLE Industry
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(industry_id, industry_name, sector_id);

LOAD DATA INFILE '/var/lib/mysql-files/data/company.tsv'
INTO TABLE Company
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(company_id, company_name, industry_id, country);

LOAD DATA INFILE '/var/lib/mysql-files/data/exchange.tsv'
INTO TABLE Exchange
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(exchange_id, exchange_name, country, timezone);

LOAD DATA INFILE '/var/lib/mysql-files/data/security.tsv'
INTO TABLE Security
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, ticker, exchange_id, currency, security_type);

LOAD DATA INFILE '/var/lib/mysql-files/data/stock.tsv'
INTO TABLE Stock
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, company_id);

LOAD DATA INFILE '/var/lib/mysql-files/data/etf.tsv'
INTO TABLE ETF
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, fund_name, expense_ratio);

LOAD DATA INFILE '/var/lib/mysql-files/data/option_contract.tsv'
INTO TABLE Option_Contract
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(option_id, security_id, expiration_date, strike_price,
 option_type, implied_volatility, open_interest);

LOAD DATA INFILE '/var/lib/mysql-files/data/portfolio.tsv'
INTO TABLE Portfolio
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(portfolio_id, portfolio_name, owner_name);

LOAD DATA INFILE '/var/lib/mysql-files/data/holding.tsv'
INTO TABLE Holding
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(portfolio_id, security_id, shares, average_cost);

LOAD DATA INFILE '/var/lib/mysql-files/data/price.tsv'
INTO TABLE Price
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(security_id, trade_date, open, high, low, close, volume);

LOAD DATA INFILE '/var/lib/mysql-files/data/financial_snapshot.tsv'
INTO TABLE Financial_Snapshot
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(snapshot_id, security_id, snapshot_date, market_cap,
 pe_ratio, eps, beta);

LOAD DATA INFILE '/var/lib/mysql-files/data/corporate_action.tsv'
INTO TABLE Corporate_Action
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(action_id, security_id, action_date, action_type, amount);

SET FOREIGN_KEY_CHECKS = 1;
