-- cleanup.sql
-- Drops all tables from the Equity Market Intelligence & Portfolio Analysis Database
-- Tables are dropped in reverse dependency order to avoid FK violations.

DROP TABLE IF EXISTS Corporate_Action;
DROP TABLE IF EXISTS Financial_Snapshot;
DROP TABLE IF EXISTS Price;
DROP TABLE IF EXISTS Holding;
DROP TABLE IF EXISTS Option_Contract;
DROP TABLE IF EXISTS ETF;
DROP TABLE IF EXISTS Stock;
DROP TABLE IF EXISTS Portfolio;
DROP TABLE IF EXISTS Security;
DROP TABLE IF EXISTS Exchange;
DROP TABLE IF EXISTS Company;
DROP TABLE IF EXISTS Industry;
DROP TABLE IF EXISTS Sector;
