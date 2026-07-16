-- queries.sql
-- parameters to swap: ticker ('AAPL'), date range ('2024-01-01'/'2024-12-31'),
--                     sector ('Technology'), min_market_cap (1000000000), min_quarters (4)


-- Q01: daily close price and return for a given stock over a date range
SELECT pr.trade_date,
       pr.close,
       ROUND((pr.close - prev_pr.close) / prev_pr.close * 100, 2) AS daily_return_pct
FROM Price pr
JOIN Security sec ON sec.security_id = pr.security_id
JOIN Price prev_pr ON prev_pr.security_id = pr.security_id
    AND prev_pr.trade_date = (
        SELECT MAX(trade_date) FROM Price
        WHERE security_id = pr.security_id AND trade_date < pr.trade_date
    )
WHERE sec.ticker = 'AAPL'
  AND pr.trade_date BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY pr.trade_date;


-- Q02: 30-day rolling annualized volatility for a given stock
SELECT pr.trade_date,
       ROUND((
           SELECT STDDEV_POP((p2.close - p3.close) / p3.close)
           FROM Price p2
           JOIN Price p3 ON p3.security_id = p2.security_id
               AND p3.trade_date = (
                   SELECT MAX(trade_date) FROM Price
                   WHERE security_id = p2.security_id AND trade_date < p2.trade_date
               )
           WHERE p2.security_id = pr.security_id
             AND p2.trade_date BETWEEN DATE_SUB(pr.trade_date, INTERVAL 30 DAY) AND pr.trade_date
       ) * SQRT(252) * 100, 2) AS rolling_vol_pct
FROM Price pr
JOIN Security sec ON sec.security_id = pr.security_id
WHERE sec.ticker = 'AAPL'
  AND pr.trade_date BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY pr.trade_date;


-- Q03: implied volatility across active option contracts, by expiration and call/put
SELECT oc.expiration_date,
       oc.option_type,
       COUNT(oc.security_id) AS contract_count,
       ROUND(AVG(oc.implied_volatility), 4) AS avg_iv,
       ROUND(MIN(oc.implied_volatility), 4) AS min_iv,
       ROUND(MAX(oc.implied_volatility), 4) AS max_iv
FROM Option_Contract oc
JOIN Security und ON und.security_id = oc.security_id
WHERE und.ticker = 'AAPL'
  AND oc.expiration_date >= CURDATE()
GROUP BY oc.expiration_date, oc.option_type
ORDER BY oc.expiration_date, oc.option_type;


-- Q04: corporate actions and price change in the 7 days surrounding each event
SELECT ca.action_type,
       ca.action_date,
       ca.amount,
       before_pr.close AS price_7d_before,
       on_pr.close AS price_on_date,
       after_pr.close AS price_7d_after,
       ROUND((after_pr.close - before_pr.close) / before_pr.close * 100, 2) AS pct_change_over_event
FROM Corporate_Action ca
JOIN Security sec ON sec.security_id = ca.security_id
LEFT JOIN Price before_pr ON before_pr.security_id = ca.security_id
    AND before_pr.trade_date = (
        SELECT MAX(trade_date) FROM Price
        WHERE security_id = ca.security_id
          AND trade_date <= DATE_SUB(ca.action_date, INTERVAL 7 DAY)
    )
LEFT JOIN Price on_pr ON on_pr.security_id = ca.security_id
    AND on_pr.trade_date = (
        SELECT MAX(trade_date) FROM Price
        WHERE security_id = ca.security_id AND trade_date <= ca.action_date
    )
LEFT JOIN Price after_pr ON after_pr.security_id = ca.security_id
    AND after_pr.trade_date = (
        SELECT MIN(trade_date) FROM Price
        WHERE security_id = ca.security_id
          AND trade_date >= DATE_ADD(ca.action_date, INTERVAL 7 DAY)
    )
WHERE sec.ticker = 'AAPL'
ORDER BY ca.action_date;


-- Q05: total return for a given stock vs SPY over a date range
SELECT sec.ticker,
       ROUND((stock_end.close - stock_start.close) / stock_start.close * 100, 2) AS stock_return_pct,
       ROUND((spy_end.close - spy_start.close) / spy_start.close * 100, 2) AS spy_return_pct,
       ROUND(
           (stock_end.close - stock_start.close) / stock_start.close * 100
           - (spy_end.close - spy_start.close) / spy_start.close * 100
       , 2) AS excess_return_pct
FROM Security sec
JOIN Price stock_start ON stock_start.security_id = sec.security_id
    AND stock_start.trade_date = (
        SELECT MIN(trade_date) FROM Price
        WHERE security_id = sec.security_id AND trade_date >= '2024-01-01'
    )
JOIN Price stock_end ON stock_end.security_id = sec.security_id
    AND stock_end.trade_date = (
        SELECT MAX(trade_date) FROM Price
        WHERE security_id = sec.security_id AND trade_date <= '2024-12-31'
    )
JOIN Security spy_sec ON spy_sec.ticker = 'SPY'
JOIN Price spy_start ON spy_start.security_id = spy_sec.security_id
    AND spy_start.trade_date = (
        SELECT MIN(trade_date) FROM Price
        WHERE security_id = spy_sec.security_id AND trade_date >= '2024-01-01'
    )
JOIN Price spy_end ON spy_end.security_id = spy_sec.security_id
    AND spy_end.trade_date = (
        SELECT MAX(trade_date) FROM Price
        WHERE security_id = spy_sec.security_id AND trade_date <= '2024-12-31'
    )
WHERE sec.ticker = 'AAPL';


-- Q06: historical P/E, EPS, and beta across snapshot dates for a given stock
SELECT fs.snapshot_date,
       fs.pe_ratio,
       fs.eps,
       fs.beta
FROM Financial_Snapshot fs
JOIN Security sec ON sec.security_id = fs.security_id
WHERE sec.ticker = 'AAPL'
ORDER BY fs.snapshot_date;


-- Q07: average stock return per sector vs SPY over a date range
SELECT s.sector_name,
       COUNT(DISTINCT sec.security_id) AS stock_count,
       ROUND(AVG((end_pr.close - start_pr.close) / start_pr.close * 100), 2) AS avg_return_pct,
       ROUND((spy_end.close - spy_start.close) / spy_start.close * 100, 2) AS spy_return_pct
FROM Sector s
JOIN Industry i ON i.sector_id = s.sector_id
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Security sec ON sec.security_id = st.security_id
JOIN Price start_pr ON start_pr.security_id = sec.security_id
    AND start_pr.trade_date = (
        SELECT MIN(trade_date) FROM Price
        WHERE security_id = sec.security_id AND trade_date >= '2024-01-01'
    )
JOIN Price end_pr ON end_pr.security_id = sec.security_id
    AND end_pr.trade_date = (
        SELECT MAX(trade_date) FROM Price
        WHERE security_id = sec.security_id AND trade_date <= '2024-12-31'
    )
JOIN Security spy_sec ON spy_sec.ticker = 'SPY'
JOIN Price spy_start ON spy_start.security_id = spy_sec.security_id
    AND spy_start.trade_date = (
        SELECT MIN(trade_date) FROM Price
        WHERE security_id = spy_sec.security_id AND trade_date >= '2024-01-01'
    )
JOIN Price spy_end ON spy_end.security_id = spy_sec.security_id
    AND spy_end.trade_date = (
        SELECT MAX(trade_date) FROM Price
        WHERE security_id = spy_sec.security_id AND trade_date <= '2024-12-31'
    )
GROUP BY s.sector_id, s.sector_name, spy_start.close, spy_end.close
ORDER BY avg_return_pct DESC;


-- Q08: avg trailing P/E by industry within a sector, filtered by min market cap
SELECT i.industry_name,
       COUNT(DISTINCT c.company_id) AS company_count,
       ROUND(AVG(fs.pe_ratio), 2) AS avg_pe_ratio
FROM Sector s
JOIN Industry i ON i.sector_id = s.sector_id
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Financial_Snapshot fs ON fs.security_id = st.security_id
WHERE s.sector_name = 'Technology'
  AND fs.pe_ratio IS NOT NULL
  AND fs.market_cap >= 1000000000
  AND fs.snapshot_date = (
      SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = st.security_id
  )
GROUP BY i.industry_id, i.industry_name
ORDER BY avg_pe_ratio DESC;


-- Q09: companies with EPS growth in at least 4 consecutive quarters, within a sector
-- requires at least 5 snapshots per company to evaluate 4 growth periods
SELECT c.company_name,
       sec.ticker
FROM Company c
JOIN Stock st ON st.company_id = c.company_id
JOIN Security sec ON sec.security_id = st.security_id
JOIN Industry i ON i.industry_id = c.industry_id
JOIN Sector s ON s.sector_id = i.sector_id
WHERE s.sector_name = 'Technology'
  AND (SELECT COUNT(*) FROM Financial_Snapshot WHERE security_id = st.security_id) >= 5
  AND NOT EXISTS (
      SELECT 1
      FROM Financial_Snapshot fs1
      WHERE fs1.security_id = st.security_id
        AND fs1.snapshot_date IN (
            SELECT snapshot_date FROM Financial_Snapshot
            WHERE security_id = st.security_id
            ORDER BY snapshot_date DESC
            LIMIT 4
        )
        AND fs1.eps <= (
            SELECT fs2.eps FROM Financial_Snapshot fs2
            WHERE fs2.security_id = fs1.security_id
              AND fs2.snapshot_date < fs1.snapshot_date
            ORDER BY fs2.snapshot_date DESC
            LIMIT 1
        )
  )
ORDER BY c.company_name;


-- Q10: top 10 most volatile stocks in a sector over a date range
SELECT sec.ticker,
       c.company_name,
       ROUND(STDDEV_POP(pr.close), 2) AS price_stddev,
       COUNT(pr.trade_date) AS trading_days
FROM Sector s
JOIN Industry i ON i.sector_id = s.sector_id
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Security sec ON sec.security_id = st.security_id
JOIN Price pr ON pr.security_id = sec.security_id
WHERE s.sector_name = 'Technology'
  AND pr.trade_date BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY sec.security_id, sec.ticker, c.company_name
ORDER BY price_stddev DESC
LIMIT 10;


-- Q11: fraction of companies per industry trading below the industry average P/E
-- note: using average as a proxy for median (no native MEDIAN in MySQL)
SELECT i.industry_name,
       COUNT(DISTINCT c.company_id) AS total_companies,
       SUM(CASE WHEN fs.pe_ratio < ind_avg.avg_pe THEN 1 ELSE 0 END) AS below_avg_count,
       ROUND(
           SUM(CASE WHEN fs.pe_ratio < ind_avg.avg_pe THEN 1 ELSE 0 END)
           / COUNT(DISTINCT c.company_id) * 100
       , 1) AS pct_below_avg
FROM Industry i
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Financial_Snapshot fs ON fs.security_id = st.security_id
JOIN (
    SELECT c2.industry_id, AVG(fs2.pe_ratio) AS avg_pe
    FROM Company c2
    JOIN Stock st2 ON st2.company_id = c2.company_id
    JOIN Financial_Snapshot fs2 ON fs2.security_id = st2.security_id
    WHERE fs2.pe_ratio IS NOT NULL
      AND fs2.snapshot_date = (
          SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = st2.security_id
      )
    GROUP BY c2.industry_id
) ind_avg ON ind_avg.industry_id = i.industry_id
WHERE fs.pe_ratio IS NOT NULL
  AND fs.snapshot_date = (
      SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = st.security_id
  )
GROUP BY i.industry_id, i.industry_name
ORDER BY pct_below_avg DESC;


-- Q12: highest dividend yield stocks in a sector with P/E and market cap
-- dividend yield = sum of dividend corporate actions in the past year / latest close price
SELECT sec.ticker,
       c.company_name,
       i.industry_name,
       ROUND(div_sum.annual_dividends / p_latest.close * 100, 2) AS dividend_yield_pct,
       fs.pe_ratio,
       ROUND(fs.market_cap / 1000000000, 2) AS market_cap_billions
FROM Sector s
JOIN Industry i ON i.sector_id = s.sector_id
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Security sec ON sec.security_id = st.security_id
JOIN Financial_Snapshot fs ON fs.security_id = st.security_id
    AND fs.snapshot_date = (
        SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = st.security_id
    )
JOIN (
    SELECT security_id, SUM(amount) AS annual_dividends
    FROM Corporate_Action
    WHERE action_type = 'dividend'
      AND action_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
    GROUP BY security_id
    HAVING SUM(amount) > 0
) div_sum ON div_sum.security_id = sec.security_id
JOIN Price p_latest ON p_latest.security_id = sec.security_id
    AND p_latest.trade_date = (
        SELECT MAX(trade_date) FROM Price WHERE security_id = sec.security_id
    )
WHERE s.sector_name = 'Technology'
ORDER BY dividend_yield_pct DESC
LIMIT 20;


-- Q13: market cap distribution by cap tier in a sector
SELECT CASE
           WHEN fs.market_cap >= 200000000000 THEN 'Mega Cap (>200B)'
           WHEN fs.market_cap >= 10000000000  THEN 'Large Cap (10-200B)'
           WHEN fs.market_cap >= 2000000000   THEN 'Mid Cap (2-10B)'
           WHEN fs.market_cap >= 300000000    THEN 'Small Cap (300M-2B)'
           ELSE 'Micro Cap (<300M)'
       END AS cap_tier,
       COUNT(DISTINCT c.company_id) AS company_count,
       ROUND(AVG(fs.market_cap) / 1000000000, 2) AS avg_mktcap_billions
FROM Sector s
JOIN Industry i ON i.sector_id = s.sector_id
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Financial_Snapshot fs ON fs.security_id = st.security_id
WHERE s.sector_name = 'Technology'
  AND fs.market_cap IS NOT NULL
  AND fs.snapshot_date = (
      SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = st.security_id
  )
GROUP BY cap_tier
ORDER BY MIN(fs.market_cap) DESC;


-- Q14: avg, min, and max beta by industry within a sector
SELECT i.industry_name,
       COUNT(DISTINCT c.company_id) AS company_count,
       ROUND(AVG(fs.beta), 4) AS avg_beta,
       ROUND(MIN(fs.beta), 4) AS min_beta,
       ROUND(MAX(fs.beta), 4) AS max_beta
FROM Sector s
JOIN Industry i ON i.sector_id = s.sector_id
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Financial_Snapshot fs ON fs.security_id = st.security_id
WHERE s.sector_name = 'Technology'
  AND fs.beta IS NOT NULL
  AND fs.snapshot_date = (
      SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = st.security_id
  )
GROUP BY i.industry_id, i.industry_name
ORDER BY avg_beta DESC;


-- Q15: top 10 stocks by avg daily trading volume in a sector over a date range
SELECT sec.ticker,
       c.company_name,
       i.industry_name,
       ROUND(AVG(pr.volume), 0) AS avg_daily_volume
FROM Sector s
JOIN Industry i ON i.sector_id = s.sector_id
JOIN Company c ON c.industry_id = i.industry_id
JOIN Stock st ON st.company_id = c.company_id
JOIN Security sec ON sec.security_id = st.security_id
JOIN Price pr ON pr.security_id = sec.security_id
WHERE s.sector_name = 'Technology'
  AND pr.trade_date BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY sec.security_id, sec.ticker, c.company_name, i.industry_name
ORDER BY avg_daily_volume DESC
LIMIT 10;