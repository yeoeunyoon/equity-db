#!/usr/bin/env python3
"""Generate TSV data files for the Equity Market Intelligence database.

The stock universe is the **full S&P 500**, discovered dynamically from the
Wikipedia "List of S&P 500 companies" table (which conveniently carries the
company name, GICS Sector and GICS Sub-Industry for every constituent). The
reference tables (Sector / Industry / Company / Security / Stock) are derived
from that list, so scaling the universe needs no hand-curation. ETFs, option
contracts, portfolios and holdings remain a small curated set.

Market data is pulled LIVE from Yahoo Finance via yfinance:
  * Price history  -> batched yf.download for every stock + ETF (the reliable
    daily core).
  * Financial snapshots + corporate actions -> per-ticker .info / dividends /
    splits. These are slow at 500-ticker scale, so their breadth is gated by
    --mode (see below).

Refresh modes (--mode / env REFRESH_MODE):
  * daily (default): prices for all constituents + fundamentals for the
    curated TOP-50 mega-caps only. Fast enough to run every night.
  * full: prices AND fundamentals for every constituent. Slow (~hundreds of
    .info calls); intended for a weekly sweep.

The price date range is dynamic. Precedence is CLI flag > environment
variable > default. Defaults: --end is today, --start is three years ago.
SNAPSHOT_DATE is always the end date.

Usage:
    python3 generate_data.py                      # daily, last 3 years -> today
    python3 generate_data.py --mode full          # weekly full sweep
    python3 generate_data.py --start 2024-01-01 --end 2024-12-31
    PRICE_START=2024-01-01 PRICE_END=2024-12-31 python3 generate_data.py

Requirements: pip install -r requirements.txt  (yfinance, pandas, lxml)
"""
import os, csv, argparse, sys, io, urllib.request
from datetime import date

import yfinance as yf
import pandas as pd

OUTPUT_DIR = "data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

SP500_URL = "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
SP500_FALLBACK = os.path.join(OUTPUT_DIR, "sp500.csv")

# Curated set of the largest US names, used for daily fundamentals refresh.
# Only those that are actually current S&P 500 constituents get processed.
TOP50 = [
    "AAPL", "MSFT", "NVDA", "GOOGL", "GOOG", "AMZN", "META", "TSLA", "BRK-B",
    "LLY", "JPM", "V", "XOM", "UNH", "MA", "AVGO", "JNJ", "PG", "HD", "COST",
    "ORCL", "ABBV", "MRK", "CVX", "KO", "ADBE", "PEP", "WMT", "BAC", "CRM",
    "NFLX", "AMD", "TMO", "MCD", "CSCO", "ACN", "ABT", "LIN", "DHR", "WFC",
    "TXN", "DIS", "INTC", "VZ", "PM", "INTU", "IBM", "QCOM", "CAT", "GE",
]

# Tickers commonly listed on NASDAQ (cosmetic: Wikipedia doesn't give the
# listing venue). Everything else defaults to NYSE. Purely for the Exchange FK.
NASDAQ = {
    "AAPL", "MSFT", "NVDA", "GOOGL", "GOOG", "AMZN", "META", "TSLA", "AVGO",
    "COST", "PEP", "CSCO", "ADBE", "NFLX", "AMD", "INTC", "QCOM", "TXN",
    "INTU", "AMGN", "HON", "SBUX", "GILD", "MU", "ADP", "ISRG", "BKNG",
    "REGN", "VRTX", "PYPL", "MDLZ", "ADI", "PANW", "KLAC", "SNPS", "CDNS",
    "MRVL", "ORLY", "CRWD", "ABNB", "FTNT", "ADSK", "NXPI", "MCHP", "IDXX",
}


def _default_dates():
    today = date.today()
    try:
        start = today.replace(year=today.year - 3)
    except ValueError:  # Feb 29 -> Feb 28 three years back
        start = today.replace(year=today.year - 3, day=28)
    return start.isoformat(), today.isoformat()


_default_start, _default_end = _default_dates()

parser = argparse.ArgumentParser(
    description="Generate equity-db TSV files from the live S&P 500 + Yahoo Finance.")
parser.add_argument("--start", default=os.environ.get("PRICE_START"),
                    help="Price history start date YYYY-MM-DD "
                         "(env PRICE_START; default: 3 years ago).")
parser.add_argument("--end", default=os.environ.get("PRICE_END"),
                    help="Price history end date YYYY-MM-DD "
                         "(env PRICE_END; default: today).")
parser.add_argument("--mode", choices=["daily", "full"],
                    default=os.environ.get("REFRESH_MODE", "daily"),
                    help="daily = TOP-50 fundamentals; full = all constituents "
                         "(env REFRESH_MODE; default: daily).")
parser.add_argument("--max-tickers", type=int,
                    default=int(os.environ.get("MAX_TICKERS", "0")) or None,
                    help="Cap the number of constituents (for testing).")
args = parser.parse_args()

PRICE_START = args.start or _default_start
PRICE_END = args.end or _default_end
SNAPSHOT_DATE = PRICE_END
MODE = args.mode

print(f"[generate_data] mode={MODE}  range={PRICE_START}..{PRICE_END}")


def write_tsv(filename, rows, header):
    path = os.path.join(OUTPUT_DIR, filename)
    # None -> '\N' so LOAD DATA INFILE stores a real SQL NULL (an empty field
    # would otherwise be coerced to 0 for numeric columns).
    def cell(v):
        return "\\N" if v is None else v
    with open(path, "w", newline="\n") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(header)
        w.writerows([cell(v) for v in row] for row in rows)
    print(f"[generate_data] wrote {filename}: {len(rows)} rows")


# --------------------------------------------------------------------------
# 1. S&P 500 constituents (Wikipedia, with a committed CSV fallback)
# --------------------------------------------------------------------------

def load_constituents():
    """Return a DataFrame with columns symbol, security, sector, sub_industry."""
    cols = {"Symbol": "symbol", "Security": "security",
            "GICS Sector": "sector", "GICS Sub-Industry": "sub_industry"}
    df = None
    try:
        # Wikipedia 403s the default urllib user-agent, so fetch with a
        # browser-like UA and hand the HTML to read_html.
        req = urllib.request.Request(SP500_URL, headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                          "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"})
        html = urllib.request.urlopen(req, timeout=20).read().decode("utf-8")
        tables = pd.read_html(io.StringIO(html))
        for t in tables:
            if set(cols).issubset(t.columns):
                df = t[list(cols)].rename(columns=cols)
                break
        if df is not None and not df.empty:
            df.to_csv(SP500_FALLBACK, index=False)  # refresh the cached fallback
            print(f"[generate_data] loaded {len(df)} constituents from Wikipedia")
    except Exception as e:
        print(f"[generate_data] Wikipedia fetch failed ({e}); using fallback", file=sys.stderr)

    if df is None or df.empty:
        if not os.path.exists(SP500_FALLBACK):
            sys.exit("[generate_data] no constituent list available (no network, "
                     "no data/sp500.csv fallback).")
        df = pd.read_csv(SP500_FALLBACK)
        print(f"[generate_data] loaded {len(df)} constituents from fallback CSV")

    # Normalize: Yahoo uses '-' where Wikipedia uses '.', e.g. BRK.B -> BRK-B.
    df = df.dropna(subset=["symbol", "security", "sector", "sub_industry"]).copy()
    df["symbol"] = df["symbol"].astype(str).str.strip().str.replace(".", "-", regex=False)
    df = df.drop_duplicates(subset=["symbol"]).sort_values("symbol").reset_index(drop=True)
    if args.max_tickers:
        df = df.head(args.max_tickers).reset_index(drop=True)
    return df


constituents = load_constituents()

# --------------------------------------------------------------------------
# 2. Derive reference tables from the constituent list
# --------------------------------------------------------------------------

# Sectors: distinct GICS sectors, deterministic ids by sorted name.
sector_names = sorted(constituents["sector"].unique())
sector_id = {name: i for i, name in enumerate(sector_names, 1)}
sectors = sorted((sid, name) for name, sid in sector_id.items())
write_tsv("sector.tsv", sectors, ["sector_id", "sector_name"])

# Industries: distinct (sub_industry -> sector), deterministic ids.
sub_to_sector = (constituents[["sub_industry", "sector"]]
                 .drop_duplicates().sort_values("sub_industry"))
industry_id = {}
industries = []
for i, (_, r) in enumerate(sub_to_sector.iterrows(), 1):
    industry_id[r["sub_industry"]] = i
    industries.append((i, r["sub_industry"], sector_id[r["sector"]]))
write_tsv("industry.tsv", industries, ["industry_id", "industry_name", "sector_id"])

# Companies + Stocks + Securities (one stock per company; security_id == company_id).
exchange_id_for = lambda sym: 2 if sym in NASDAQ else 1  # 2=NASDAQ, 1=NYSE
companies, stocks, securities = [], [], []
sid_of = {}  # ticker -> security_id
for cid, (_, r) in enumerate(constituents.iterrows(), 1):
    sym = r["symbol"]
    companies.append((cid, r["security"], industry_id[r["sub_industry"]], "US"))
    securities.append((cid, sym, exchange_id_for(sym), "USD", "stock"))
    stocks.append((cid, cid))
    sid_of[sym] = cid
write_tsv("company.tsv", companies,
          ["company_id", "company_name", "industry_id", "country"])

n_stocks = len(constituents)

# --------------------------------------------------------------------------
# 3. Curated ETFs / options / portfolios (ids continue after the stocks)
# --------------------------------------------------------------------------

exchanges = [
    (1, "New York Stock Exchange", "US", "America/New_York"),
    (2, "NASDAQ", "US", "America/New_York"),
    (3, "Chicago Board Options Exchange", "US", "America/Chicago"),
]
write_tsv("exchange.tsv", exchanges,
          ["exchange_id", "exchange_name", "country", "timezone"])

etf_syms = ["SPY", "QQQ", "IWM", "VTI", "XLK"]
etf_sid = {sym: n_stocks + i for i, sym in enumerate(etf_syms, 1)}
for sym, s in etf_sid.items():
    securities.append((s, sym, 2, "USD", "etf"))
    sid_of[sym] = s

# Options are their own securities (type 'option'), after the ETFs.
option_defs = [  # (underlying, expiration, strike, type, iv_fallback, oi_fallback)
    ("AAPL", "2025-04-18", 200.00, "call", 0.2850, 45230),
    ("AAPL", "2025-04-18", 200.00, "put",  0.2910, 32100),
    ("MSFT", "2025-04-18", 400.00, "call", 0.2650, 28400),
    ("TSLA", "2025-04-18", 250.00, "call", 0.5200, 19800),
    ("SPY",  "2025-04-18", 550.00, "put",  0.1820, 61200),
]
option_sid_start = n_stocks + len(etf_syms) + 1
for i, (u, exp, strike, otype, _iv, _oi) in enumerate(option_defs):
    s = option_sid_start + i
    ticker = f"{u}{exp.replace('-', '')}{'C' if otype == 'call' else 'P'}{int(strike * 1000):08d}"
    securities.append((s, ticker[:20], 3, "USD", "option"))

write_tsv("security.tsv", securities,
          ["security_id", "ticker", "exchange_id", "currency", "security_type"])
write_tsv("stock.tsv", stocks, ["security_id", "company_id"])

portfolios = [
    (1, "Growth Portfolio", "Alice Chen"), (2, "Value Portfolio", "Bob Martinez"),
    (3, "Tech Focus", "Charlie Kim"), (4, "Dividend Income", "Diana Patel"),
    (5, "Balanced Fund", "Ethan Brooks"),
]
write_tsv("portfolio.tsv", portfolios,
          ["portfolio_id", "portfolio_name", "owner_name"])

# Holdings defined by ticker so they survive universe changes; skipped if a
# ticker isn't in the current universe.
holding_defs = [
    (1, "AAPL", 100, 178.50), (1, "NVDA", 50, 480.25), (1, "AMZN", 30, 185.00),
    (1, "TSLA", 40, 245.80), (1, "NFLX", 25, 620.00),
    (2, "JNJ", 80, 155.20), (2, "JPM", 60, 195.00), (2, "KO", 200, 58.50),
    (2, "PG", 90, 165.40),
    (3, "MSFT", 70, 380.00), (3, "NVDA", 40, 490.00), (3, "AMD", 120, 155.60),
    (3, "AVGO", 30, 170.00), (3, "QQQ", 100, 480.50),
    (4, "XOM", 150, 105.30), (4, "KO", 300, 57.90), (4, "PG", 120, 162.00),
    (4, "MCD", 50, 290.00), (4, "VTI", 200, 250.00),
    (5, "AAPL", 50, 180.00), (5, "JPM", 40, 200.00), (5, "SPY", 150, 540.00),
    (5, "XLK", 80, 200.00),
]
holdings = [(pid, sid_of[t], sh, ac) for pid, t, sh, ac in holding_defs if t in sid_of]
write_tsv("holding.tsv", holdings,
          ["portfolio_id", "security_id", "shares", "average_cost"])

# --------------------------------------------------------------------------
# 4. Prices — batched download for every stock + ETF (the daily core)
# --------------------------------------------------------------------------

price_syms = list(constituents["symbol"]) + etf_syms


def download_prices(symbols, chunk=100):
    """Download OHLCV for symbols in chunks; return {symbol: DataFrame}."""
    out = {}
    for i in range(0, len(symbols), chunk):
        batch = symbols[i:i + chunk]
        try:
            df = yf.download(batch, start=PRICE_START, end=PRICE_END,
                             group_by="ticker", auto_adjust=False,
                             progress=False, threads=True)
        except Exception as e:
            print(f"[generate_data] price batch {i}-{i+len(batch)} failed: {e}",
                  file=sys.stderr)
            continue
        for sym in batch:
            try:
                sub = df[sym] if len(batch) > 1 else df
                out[sym] = sub[["Open", "High", "Low", "Close", "Volume"]].dropna(subset=["Close"])
            except Exception:
                pass
    return out


price_data = download_prices(price_syms)
prices = []
for sym, df in price_data.items():
    sid = sid_of.get(sym)
    if sid is None:
        continue
    for idx, row in df.iterrows():
        try:
            prices.append((sid, idx.strftime("%Y-%m-%d"),
                round(float(row["Open"]), 4), round(float(row["High"]), 4),
                round(float(row["Low"]), 4), round(float(row["Close"]), 4),
                int(row["Volume"]) if pd.notna(row["Volume"]) else 0))
        except Exception:
            pass
write_tsv("price.tsv", prices,
          ["security_id", "trade_date", "open", "high", "low", "close", "volume"])

# --------------------------------------------------------------------------
# 5. ETF metadata (small, always refreshed)
# --------------------------------------------------------------------------

etf_name_fb = {"SPY": "SPDR S&P 500 ETF Trust", "QQQ": "Invesco QQQ Trust",
               "IWM": "iShares Russell 2000 ETF", "VTI": "Vanguard Total Stock Market ETF",
               "XLK": "Technology Select Sector SPDR Fund"}
etf_er_fb = {"SPY": 0.0945, "QQQ": 0.2000, "IWM": 0.1900, "VTI": 0.0300, "XLK": 0.0900}
etfs = []
for sym in etf_syms:
    try:
        info = yf.Ticker(sym).info
        name = info.get("longName") or info.get("shortName") or etf_name_fb[sym]
        er = info.get("annualReportExpenseRatio") or info.get("totalExpenseRatio")
        er = round(float(er) * 100, 4) if er else etf_er_fb[sym]
    except Exception:
        name, er = etf_name_fb[sym], etf_er_fb[sym]
    etfs.append((etf_sid[sym], name, er))
write_tsv("etf.tsv", etfs, ["security_id", "fund_name", "expense_ratio"])

# Option contracts (best-effort live IV/OI, else fallbacks).
options = []
for oid, (u, exp, strike, otype, iv_fb, oi_fb) in enumerate(option_defs, 1):
    sec_id = option_sid_start + oid - 1
    iv, oi = None, None
    try:
        chain = yf.Ticker(u).option_chain(exp)
        df = chain.calls if otype == "call" else chain.puts
        match = df.iloc[(df["strike"] - strike).abs().argsort()[:1]]
        if not match.empty:
            iv = round(float(match["impliedVolatility"].values[0]), 4)
            oi_val = match["openInterest"].values[0]
            oi = int(oi_val) if pd.notna(oi_val) else 0
    except Exception:
        pass
    options.append((oid, sec_id, exp, strike, otype,
                    iv if iv is not None else iv_fb,
                    oi if oi is not None else oi_fb))
write_tsv("option_contract.tsv", options,
          ["option_id", "security_id", "expiration_date", "strike_price",
           "option_type", "implied_volatility", "open_interest"])

# --------------------------------------------------------------------------
# 6. Fundamentals — snapshots + corporate actions (breadth gated by --mode)
# --------------------------------------------------------------------------

if MODE == "full":
    fund_syms = list(constituents["symbol"])
else:  # daily
    universe = set(constituents["symbol"])
    fund_syms = [s for s in TOP50 if s in universe]
print(f"[generate_data] fundamentals for {len(fund_syms)} tickers (mode={MODE})")

snapshots = []
for i, sym in enumerate(fund_syms, 1):
    mcap = pe = eps = beta = None
    try:
        info = yf.Ticker(sym).info
        mcap = info.get("marketCap")
        pe = round(float(info["trailingPE"]), 2) if info.get("trailingPE") else None
        eps = round(float(info["trailingEps"]), 4) if info.get("trailingEps") else None
        beta = round(float(info["beta"]), 4) if info.get("beta") else None
    except Exception:
        pass
    snapshots.append((i, sid_of[sym], SNAPSHOT_DATE, mcap, pe, eps, beta))
write_tsv("financial_snapshot.tsv", snapshots,
          ["snapshot_id", "security_id", "snapshot_date",
           "market_cap", "pe_ratio", "eps", "beta"])

actions = []
aid = 1
for sym in fund_syms:
    sid = sid_of[sym]
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

print(f"[generate_data] done. {n_stocks} stocks, {len(prices)} price rows, "
      f"{len(snapshots)} snapshots, {len(actions)} corporate actions.")
