-- setup.sql
-- Equity Market Intelligence & Portfolio Analysis Database
-- Creates all tables in the database
-- Run on db.cs.jhu.edu

CREATE TABLE Sector (
    sector_id       INT AUTO_INCREMENT,
    sector_name     VARCHAR(100) NOT NULL UNIQUE,
    PRIMARY KEY (sector_id)
);

CREATE TABLE Industry (
    industry_id     INT AUTO_INCREMENT,
    industry_name   VARCHAR(100) NOT NULL,
    sector_id       INT NOT NULL,
    PRIMARY KEY (industry_id),
    FOREIGN KEY (sector_id) REFERENCES Sector(sector_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Company (
    company_id      INT AUTO_INCREMENT,
    company_name    VARCHAR(200) NOT NULL,
    industry_id     INT NOT NULL,
    country         VARCHAR(100) NOT NULL DEFAULT 'US',
    PRIMARY KEY (company_id),
    FOREIGN KEY (industry_id) REFERENCES Industry(industry_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Exchange (
    exchange_id     INT AUTO_INCREMENT,
    exchange_name   VARCHAR(100) NOT NULL,
    country         VARCHAR(100) NOT NULL,
    timezone        VARCHAR(50) NOT NULL,
    PRIMARY KEY (exchange_id)
);

CREATE TABLE Security (
    security_id     INT AUTO_INCREMENT,
    ticker          VARCHAR(20) NOT NULL,
    exchange_id     INT NOT NULL,
    currency        VARCHAR(10) NOT NULL DEFAULT 'USD',
    security_type   ENUM('stock', 'etf', 'option') NOT NULL,
    PRIMARY KEY (security_id),
    UNIQUE (ticker, exchange_id),
    FOREIGN KEY (exchange_id) REFERENCES Exchange(exchange_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Stock (
    security_id     INT,
    company_id      INT NOT NULL,
    PRIMARY KEY (security_id),
    FOREIGN KEY (security_id) REFERENCES Security(security_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (company_id) REFERENCES Company(company_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE ETF (
    security_id     INT,
    fund_name       VARCHAR(200) NOT NULL,
    expense_ratio   DECIMAL(6,4),
    PRIMARY KEY (security_id),
    FOREIGN KEY (security_id) REFERENCES Security(security_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (expense_ratio >= 0)
);

CREATE TABLE Option_Contract (
    option_id       INT AUTO_INCREMENT,
    security_id     INT NOT NULL,
    expiration_date DATE NOT NULL,
    strike_price    DECIMAL(12,2) NOT NULL,
    option_type     ENUM('call', 'put') NOT NULL,
    implied_volatility DECIMAL(8,4),
    open_interest   INT DEFAULT 0,
    PRIMARY KEY (option_id),
    UNIQUE (security_id, expiration_date, strike_price, option_type),
    FOREIGN KEY (security_id) REFERENCES Security(security_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (strike_price > 0),
    CHECK (open_interest >= 0)
);

CREATE TABLE Portfolio (
    portfolio_id    INT AUTO_INCREMENT,
    portfolio_name  VARCHAR(100) NOT NULL,
    owner_name      VARCHAR(100) NOT NULL,
    PRIMARY KEY (portfolio_id)
);

CREATE TABLE Holding (
    portfolio_id    INT,
    security_id     INT,
    shares          DECIMAL(14,4) NOT NULL,
    average_cost    DECIMAL(12,4) NOT NULL,
    PRIMARY KEY (portfolio_id, security_id),
    FOREIGN KEY (portfolio_id) REFERENCES Portfolio(portfolio_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (security_id) REFERENCES Security(security_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (shares > 0),
    CHECK (average_cost >= 0)
);

CREATE TABLE Price (
    security_id     INT,
    trade_date      DATE,
    open            DECIMAL(12,4),
    high            DECIMAL(12,4),
    low             DECIMAL(12,4),
    close           DECIMAL(12,4) NOT NULL,
    volume          BIGINT DEFAULT 0,
    PRIMARY KEY (security_id, trade_date),
    FOREIGN KEY (security_id) REFERENCES Security(security_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (volume >= 0)
);

CREATE TABLE Financial_Snapshot (
    snapshot_id     INT AUTO_INCREMENT,
    security_id     INT NOT NULL,
    snapshot_date   DATE NOT NULL,
    market_cap      BIGINT,
    pe_ratio        DECIMAL(10,2),
    eps             DECIMAL(10,4),
    beta            DECIMAL(6,4),
    PRIMARY KEY (snapshot_id),
    UNIQUE (security_id, snapshot_date),
    FOREIGN KEY (security_id) REFERENCES Security(security_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Corporate_Action (
    action_id       INT AUTO_INCREMENT,
    security_id     INT NOT NULL,
    action_date     DATE NOT NULL,
    action_type     ENUM('dividend', 'split', 'reverse_split', 'spinoff') NOT NULL,
    amount          DECIMAL(14,6),
    PRIMARY KEY (action_id),
    FOREIGN KEY (security_id) REFERENCES Security(security_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);
