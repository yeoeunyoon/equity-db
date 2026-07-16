#!/usr/bin/env python3
import os, csv

import yfinance as yf
import pandas as pd

OUTPUT_DIR = "data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

PRICE_START = "2025-01-02"
PRICE_END = "2025-03-28"
SNAPSHOT_DATE = "2025-03-28"

def write_tsv(filename, rows, header):
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", newline="\n") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)

sectors = [
    (1, "Technology"), (2, "Healthcare"), (3, "Financial Services"),
    (4, "Consumer Discretionary"), (5, "Energy"), (6, "Industrials"),
    (7, "Communication Services"), (8, "Consumer Staples"),
    (9, "Utilities"), (10, "Real Estate"), (11, "Materials"),
]
write_tsv("sector.tsv", sectors, ["sector_id", "sector_name"])

industries = [
    (1, "Software - Infrastructure", 1), (2, "Semiconductors", 1),
    (3, "Consumer Electronics", 1), (4, "Software - Application", 1),
    (5, "Drug Manufacturers", 2), (6, "Biotechnology", 2),
    (7, "Banks - Diversified", 3), (8, "Financial Data & Exchanges", 3),
    (9, "Internet Retail", 4), (10, "Auto Manufacturers", 4),
    (11, "Oil & Gas Integrated", 5), (12, "Oil & Gas E&P", 5),
    (13, "Aerospace & Defense", 6), (14, "Internet Content & Info", 7),
    (15, "Household & Personal Products", 8), (16, "Beverages - Non-Alcoholic", 8),
    (17, "Utilities - Regulated Electric", 9), (18, "REIT - Diversified", 10),
    (19, "Specialty Chemicals", 11), (20, "Restaurants", 4),
]
write_tsv("industry.tsv", industries, ["industry_id", "industry_name", "sector_id"])

companies = [
    (1, "Apple Inc.", 3, "US"), (2, "Microsoft Corporation", 1, "US"),
    (3, "NVIDIA Corporation", 2, "US"), (4, "Alphabet Inc.", 14, "US"),
    (5, "Amazon.com Inc.", 9, "US"), (6, "Meta Platforms Inc.", 14, "US"),
    (7, "Tesla Inc.", 10, "US"), (8, "Johnson & Johnson", 5, "US"),
    (9, "JPMorgan Chase & Co.", 7, "US"), (10, "Exxon Mobil Corporation", 11, "US"),
    (11, "UnitedHealth Group Inc.", 5, "US"), (12, "Visa Inc.", 8, "US"),
    (13, "Procter & Gamble Co.", 15, "US"), (14, "Coca-Cola Company", 16, "US"),
    (15, "Pfizer Inc.", 5, "US"), (16, "Boeing Company", 13, "US"),
    (17, "Intel Corporation", 2, "US"), (18, "Salesforce Inc.", 4, "US"),
    (19, "McDonald's Corporation", 20, "US"), (20, "Netflix Inc.", 14, "US"),
    (21, "Advanced Micro Devices Inc.", 2, "US"), (22, "Broadcom Inc.", 2, "US"),
    (23, "Adobe Inc.", 4, "US"), (24, "Costco Wholesale Corp.", 9, "US"),
    (25, "Berkshire Hathaway Inc.", 7, "US"),
]
write_tsv("company.tsv", companies, ["company_id", "company_name", "industry_id", "country"])

exchanges = [
    (1, "New York Stock Exchange", "US", "America/New_York"),
    (2, "NASDAQ", "US", "America/New_York"),
    (3, "Chicago Board Options Exchange", "US", "America/Chicago"),
]
write_tsv("exchange.tsv", exchanges, ["exchange_id", "exchange_name", "country", "timezone"])

stock_tickers = [
    (1, "AAPL", 2), (2, "MSFT", 2), (3, "NVDA", 2),
    (4, "GOOGL", 2), (5, "AMZN", 2), (6, "META", 2),
    (7, "TSLA", 2), (8, "JNJ", 1), (9, "JPM", 1),
    (10, "XOM", 1), (11, "UNH", 1), (12, "V", 1),
    (13, "PG", 1), (14, "KO", 1), (15, "PFE", 1),
    (16, "BA", 1), (17, "INTC", 2), (18, "CRM", 2),
    (19, "MCD", 1), (20, "NFLX", 2), (21, "AMD", 2),
    (22, "AVGO", 2), (23, "ADBE", 2), (24, "COST", 2),
    (25, "BRK-B", 1),
]
etf_tickers = [
    (26, "SPY", 2), (27, "QQQ", 2), (28, "IWM", 2),
    (29, "VTI", 2), (30, "XLK", 2),
]
option_tickers = [
    (31, "AAPL250418C00200000", 3), (32, "AAPL250418P00200000", 3),
    (33, "MSFT250418C00400000", 3), (34, "TSLA250418C00250000", 3),
    (35, "SPY250418P00550000", 3),
]

all_securities = []
for sid, ticker, eid in stock_tickers:
    all_securities.append((sid, ticker, eid, "USD", "stock"))
for sid, ticker, eid in etf_tickers:
    all_securities.append((sid, ticker, eid, "USD", "etf"))
for sid, ticker, eid in option_tickers:
    all_securities.append((sid, ticker, eid, "USD", "option"))
write_tsv("security.tsv", all_securities,
          ["security_id", "ticker", "exchange_id", "currency", "security_type"])

write_tsv("stock.tsv", [(sid, sid) for sid, _, _ in stock_tickers],
          ["security_id", "company_id"])

portfolios = [
    (1, "Growth Portfolio", "Alice Chen"), (2, "Value Portfolio", "Bob Martinez"),
    (3, "Tech Focus", "Charlie Kim"), (4, "Dividend Income", "Diana Patel"),
    (5, "Balanced Fund", "Ethan Brooks"),
]
write_tsv("portfolio.tsv", portfolios, ["portfolio_id", "portfolio_name", "owner_name"])

holdings = [
    (1, 1, 100, 178.50), (1, 3, 50, 480.25), (1, 5, 30, 185.00),
    (1, 7, 40, 245.80), (1, 20, 25, 620.00),
    (2, 8, 80, 155.20), (2, 9, 60, 195.00), (2, 14, 200, 58.50),
    (2, 25, 20, 410.00), (2, 13, 90, 165.40),
    (3, 2, 70, 380.00), (3, 3, 40, 490.00), (3, 21, 120, 155.60),
    (3, 22, 30, 170.00), (3, 27, 100, 480.50),
    (4, 10, 150, 105.30), (4, 14, 300, 57.90), (4, 13, 120, 162.00),
    (4, 19, 50, 290.00), (4, 29, 200, 250.00),
    (5, 1, 50, 180.00), (5, 9, 40, 200.00), (5, 26, 150, 540.00),
    (5, 14, 100, 59.00), (5, 30, 80, 200.00),
]
write_tsv("holding.tsv", holdings, ["portfolio_id", "security_id", "shares", "average_cost"])

# --- yfinance data ---

ticker_to_sid = {t: sid for sid, t, _ in stock_tickers + etf_tickers}
all_equity_syms = [t for _, t, _ in stock_tickers] + [t for _, t, _ in etf_tickers]

# price data
try:
    price_df = yf.download(all_equity_syms, start=PRICE_START, end=PRICE_END,
                           group_by="ticker", auto_adjust=False, progress=False)
except Exception:
    price_df = pd.DataFrame()

prices = []
if not price_df.empty:
    for sym in all_equity_syms:
        sid = ticker_to_sid[sym]
        try:
            df = price_df[sym][["Open", "High", "Low", "Close", "Volume"]].dropna(subset=["Close"])
            for idx, row in df.iterrows():
                prices.append((sid, idx.strftime("%Y-%m-%d"),
                    round(float(row["Open"]), 4), round(float(row["High"]), 4),
                    round(float(row["Low"]), 4), round(float(row["Close"]), 4),
                    int(row["Volume"]) if pd.notna(row["Volume"]) else 0))
        except Exception:
            pass
write_tsv("price.tsv", prices, ["security_id", "trade_date", "open", "high", "low", "close", "volume"])

# etf info
etf_name_fb = {"SPY": "SPDR S&P 500 ETF Trust", "QQQ": "Invesco QQQ Trust",
               "IWM": "iShares Russell 2000 ETF", "VTI": "Vanguard Total Stock Market ETF",
               "XLK": "Technology Select Sector SPDR Fund"}
etf_er_fb = {"SPY": 0.0945, "QQQ": 0.2000, "IWM": 0.1900, "VTI": 0.0300, "XLK": 0.0900}

etfs = []
for sid, sym, _ in etf_tickers:
    try:
        info = yf.Ticker(sym).info
        name = info.get("longName") or info.get("shortName") or etf_name_fb[sym]
        er = info.get("annualReportExpenseRatio") or info.get("totalExpenseRatio")
        er = round(float(er) * 100, 4) if er else etf_er_fb[sym]
    except Exception:
        name, er = etf_name_fb[sym], etf_er_fb[sym]
    etfs.append((sid, name, er))
write_tsv("etf.tsv", etfs, ["security_id", "fund_name", "expense_ratio"])

# option contracts
option_defs = [
    (1, 31, "AAPL", "2025-04-18", 200.00, "call"),
    (2, 32, "AAPL", "2025-04-18", 200.00, "put"),
    (3, 33, "MSFT", "2025-04-18", 400.00, "call"),
    (4, 34, "TSLA", "2025-04-18", 250.00, "call"),
    (5, 35, "SPY", "2025-04-18", 550.00, "put"),
]
iv_fb = {31: 0.2850, 32: 0.2910, 33: 0.2650, 34: 0.5200, 35: 0.1820}
oi_fb = {31: 45230, 32: 32100, 33: 28400, 34: 19800, 35: 61200}

options = []
for opt_id, sec_id, underlying, exp, strike, opt_type in option_defs:
    iv, oi = None, None
    try:
        chain = yf.Ticker(underlying).option_chain(exp)
        df = chain.calls if opt_type == "call" else chain.puts
        match = df.iloc[(df["strike"] - strike).abs().argsort()[:1]]
        if not match.empty:
            iv = round(float(match["impliedVolatility"].values[0]), 4)
            oi_val = match["openInterest"].values[0]
            oi = int(oi_val) if pd.notna(oi_val) else 0
    except Exception:
        pass
    iv = iv if iv is not None else iv_fb[sec_id]
    oi = oi if oi is not None else oi_fb[sec_id]
    options.append((opt_id, sec_id, exp, strike, opt_type, iv, oi))
write_tsv("option_contract.tsv", options,
          ["option_id", "security_id", "expiration_date", "strike_price",
           "option_type", "implied_volatility", "open_interest"])

# financial snapshots
snapshots = []
for i, (sid, sym, _) in enumerate(stock_tickers, 1):
    try:
        info = yf.Ticker(sym).info
        mcap = info.get("marketCap")
        pe = round(float(info["trailingPE"]), 2) if info.get("trailingPE") else None
        eps = round(float(info["trailingEps"]), 4) if info.get("trailingEps") else None
        beta = round(float(info["beta"]), 4) if info.get("beta") else None
    except Exception:
        mcap, pe, eps, beta = None, None, None, None
    snapshots.append((i, sid, SNAPSHOT_DATE, mcap, pe, eps, beta))
write_tsv("financial_snapshot.tsv", snapshots,
          ["snapshot_id", "security_id", "snapshot_date", "market_cap", "pe_ratio", "eps", "beta"])

# corporate actions (dividends + splits)
actions = []
aid = 1
for sid, sym, _ in stock_tickers:
    try:
        tk = yf.Ticker(sym)
        divs = tk.dividends
        if divs is not None and len(divs) > 0:
            for dt, amt in divs[(divs.index >= PRICE_START) & (divs.index <= PRICE_END)].items():
                actions.append((aid, sid, dt.strftime("%Y-%m-%d"), "dividend", round(float(amt), 6)))
                aid += 1
        splits = tk.splits
        if splits is not None and len(splits) > 0:
            for dt, ratio in splits[(splits.index >= PRICE_START) & (splits.index <= PRICE_END)].items():
                atype = "split" if float(ratio) > 1 else "reverse_split"
                actions.append((aid, sid, dt.strftime("%Y-%m-%d"), atype, round(float(ratio), 6)))
                aid += 1
    except Exception:
        pass
write_tsv("corporate_action.tsv", actions,
          ["action_id", "security_id", "action_date", "action_type", "amount"])

print("Done. TSV files in ./data/")
