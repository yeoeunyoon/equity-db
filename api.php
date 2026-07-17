<?php
require_once 'config.php';
header('Content-Type: application/json');

$db     = get_db();
$q      = $_GET['q']      ?? '';
$ticker = strtoupper(trim($_GET['ticker'] ?? 'AAPL'));
$sector = trim($_GET['sector'] ?? '');
$start  = $_GET['start']  ?? '2024-01-01';
$end    = $_GET['end']    ?? date('Y-m-d');
$min_cap = (float)($_GET['min_cap'] ?? 0);
$min_q   = max(1, (int)($_GET['min_q'] ?? 4));

function q($db, $sql, $types='', $params=[]) {
    $s = $db->prepare($sql);
    if (!$s) die(json_encode(['error'=>$db->error]));
    if ($types) $s->bind_param($types, ...$params);
    $s->execute();
    $rows = $s->get_result()->fetch_all(MYSQLI_ASSOC);
    $s->close();
    echo json_encode(['rows'=>$rows]);
}

// ── Portfolio helpers ──────────────────────────────────────────────────────────
// Resolve a portfolio to a map of ticker => ['shares'=>float, 'cost'=>float],
// either from a saved portfolio (pid) or an ad-hoc "AAPL:10:150,MSFT:5:300" spec.
function pf_get_holdings($db, $pid, $spec) {
    if ($pid > 0) {
        $s = $db->prepare("SELECT sc.ticker, h.shares, h.average_cost
                           FROM Holding h JOIN Security sc ON sc.security_id = h.security_id
                           WHERE h.portfolio_id = ?");
        $s->bind_param('i', $pid); $s->execute();
        $res = $s->get_result()->fetch_all(MYSQLI_ASSOC); $s->close();
        $out = [];
        foreach ($res as $r) $out[strtoupper($r['ticker'])] = ['shares'=>(float)$r['shares'], 'cost'=>(float)$r['average_cost']];
        return $out;
    }
    $out = [];
    foreach (explode(',', $spec) as $part) {
        $p = explode(':', $part);
        if (count($p) < 2) continue;
        $t = strtoupper(trim($p[0]));
        if ($t === '') continue;
        $sh = (float)$p[1];
        $co = isset($p[2]) ? (float)$p[2] : 0.0;
        if ($sh <= 0) continue;
        $out[$t] = ['shares'=>$sh, 'cost'=>$co];  // last spec for a ticker wins
    }
    return $out;
}

// Latest close, sector, company and trailing-12-month dividend/share for a ticker set.
function pf_reference($db, $tickers) {
    if (!$tickers) return [];
    $ph    = implode(',', array_fill(0, count($tickers), '?'));
    $types = str_repeat('s', count($tickers));
    $sql = "SELECT s.security_id, s.ticker, s.security_type,
              c.company_name, sec.sector_name,
              lp.close AS latest_close,
              COALESCE(dv.div12, 0) AS div12
            FROM Security s
            LEFT JOIN Stock sk    ON sk.security_id = s.security_id
            LEFT JOIN Company c   ON c.company_id   = sk.company_id
            LEFT JOIN Industry i  ON i.industry_id  = c.industry_id
            LEFT JOIN Sector sec  ON sec.sector_id  = i.sector_id
            LEFT JOIN Price lp    ON lp.security_id = s.security_id
              AND lp.trade_date = (SELECT MAX(trade_date) FROM Price WHERE security_id = s.security_id)
            LEFT JOIN (SELECT security_id, SUM(amount) AS div12 FROM Corporate_Action
                       WHERE action_type = 'dividend' AND action_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
                       GROUP BY security_id) dv ON dv.security_id = s.security_id
            WHERE s.ticker IN ($ph)";
    $st = $db->prepare($sql);
    if (!$st) die(json_encode(['error'=>$db->error]));
    $st->bind_param($types, ...$tickers); $st->execute();
    $rows = $st->get_result()->fetch_all(MYSQLI_ASSOC); $st->close();
    $map = [];
    foreach ($rows as $r) $map[strtoupper($r['ticker'])] = $r;
    return $map;
}

switch ($q) {

case 'sectors':
    q($db, "SELECT sector_name FROM Sector ORDER BY sector_name");
    break;

case 's1':
    q($db, "SELECT p.trade_date, p.close
            FROM Price p JOIN Security s ON s.security_id = p.security_id
            WHERE s.ticker = ? AND p.trade_date BETWEEN ? AND ?
            ORDER BY p.trade_date",
       'sss', [$ticker, $start, $end]);
    break;

case 's2':
    q($db, "WITH daily AS (
              SELECT p.trade_date,
                (p.close - LAG(p.close) OVER (ORDER BY p.trade_date))
                / LAG(p.close) OVER (ORDER BY p.trade_date) AS ret
              FROM Price p JOIN Security s ON s.security_id = p.security_id
              WHERE s.ticker = ? AND p.trade_date BETWEEN ? AND ?
            )
            SELECT trade_date,
              ROUND(STDDEV_SAMP(ret) OVER (ORDER BY trade_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
                    * SQRT(252) * 100, 2) AS ann_vol_pct
            FROM daily WHERE ret IS NOT NULL ORDER BY trade_date",
       'sss', [$ticker, $start, $end]);
    break;

case 's3':
    q($db, "SELECT oc.expiration_date, oc.option_type,
              ROUND(AVG(oc.implied_volatility)*100, 2) AS avg_iv_pct,
              SUM(oc.open_interest) AS total_oi, COUNT(*) AS contracts
            FROM Option_Contract oc JOIN Security s ON s.security_id = oc.security_id
            WHERE s.ticker LIKE CONCAT(?, '%')
            GROUP BY oc.expiration_date, oc.option_type
            ORDER BY oc.expiration_date, oc.option_type",
       's', [$ticker]);
    break;

case 's4':
    q($db, "SELECT ca.action_date, ca.action_type, ca.amount,
              p_on.close  AS price_on_date,
              p_pre.close AS price_7d_before,
              p_aft.close AS price_7d_after,
              ROUND((p_on.close - p_pre.close)/p_pre.close*100, 2) AS chg_pre_pct,
              ROUND((p_aft.close - p_on.close)/p_on.close*100,  2) AS chg_aft_pct
            FROM Corporate_Action ca JOIN Security s ON s.security_id = ca.security_id
            LEFT JOIN Price p_on ON p_on.security_id = ca.security_id
              AND p_on.trade_date  = (SELECT MAX(trade_date) FROM Price WHERE security_id = ca.security_id AND trade_date <= ca.action_date)
            LEFT JOIN Price p_pre ON p_pre.security_id = ca.security_id
              AND p_pre.trade_date = (SELECT MAX(trade_date) FROM Price WHERE security_id = ca.security_id AND trade_date <= DATE_SUB(ca.action_date, INTERVAL 7 DAY))
            LEFT JOIN Price p_aft ON p_aft.security_id = ca.security_id
              AND p_aft.trade_date = (SELECT MIN(trade_date) FROM Price WHERE security_id = ca.security_id AND trade_date >= DATE_ADD(ca.action_date, INTERVAL 7 DAY))
            WHERE s.ticker = ? ORDER BY ca.action_date DESC",
       's', [$ticker]);
    break;

case 's5':
    q($db, "SELECT
              ROUND((se.close - ss.close)/ss.close*100, 2) AS stock_return_pct,
              ROUND((pe.close - ps.close)/ps.close*100,  2) AS spy_return_pct,
              ROUND((se.close - ss.close)/ss.close*100 - (pe.close - ps.close)/ps.close*100, 2) AS excess_return_pct
            FROM Security sec
            JOIN Price ss ON ss.security_id = sec.security_id
              AND ss.trade_date = (SELECT MIN(trade_date) FROM Price WHERE security_id = sec.security_id AND trade_date >= ?)
            JOIN Price se ON se.security_id = sec.security_id
              AND se.trade_date = (SELECT MAX(trade_date) FROM Price WHERE security_id = sec.security_id AND trade_date <= ?)
            JOIN Security spy ON spy.ticker = 'SPY'
            JOIN Price ps ON ps.security_id = spy.security_id
              AND ps.trade_date = (SELECT MIN(trade_date) FROM Price WHERE security_id = spy.security_id AND trade_date >= ?)
            JOIN Price pe ON pe.security_id = spy.security_id
              AND pe.trade_date = (SELECT MAX(trade_date) FROM Price WHERE security_id = spy.security_id AND trade_date <= ?)
            WHERE sec.ticker = ?",
       'sssss', [$start, $end, $start, $end, $ticker]);
    break;

case 's6':
    q($db, "SELECT fs.snapshot_date, fs.pe_ratio, fs.eps, fs.beta,
              ROUND(fs.market_cap/1e9, 2) AS market_cap_b
            FROM Financial_Snapshot fs JOIN Security s ON s.security_id = fs.security_id
            WHERE s.ticker = ? ORDER BY fs.snapshot_date",
       's', [$ticker]);
    break;

case 'r1':
    q($db, "SELECT st.sector_name,
              ROUND(AVG((pe.close-ps.close)/ps.close*100), 2) AS sector_return_pct,
              ROUND((spye.close-spys.close)/spys.close*100,  2) AS spy_return_pct,
              ROUND(AVG((pe.close-ps.close)/ps.close*100) - (spye.close-spys.close)/spys.close*100, 2) AS relative_pct
            FROM Sector st
            JOIN Industry i  ON i.sector_id   = st.sector_id
            JOIN Company c   ON c.industry_id  = i.industry_id
            JOIN Stock sk    ON sk.company_id  = c.company_id
            JOIN Security s  ON s.security_id  = sk.security_id
            JOIN Price ps ON ps.security_id = s.security_id
              AND ps.trade_date = (SELECT MIN(trade_date) FROM Price WHERE security_id = s.security_id AND trade_date >= ?)
            JOIN Price pe ON pe.security_id = s.security_id
              AND pe.trade_date = (SELECT MAX(trade_date) FROM Price WHERE security_id = s.security_id AND trade_date <= ?)
            JOIN Security spy ON spy.ticker = 'SPY'
            JOIN Price spys ON spys.security_id = spy.security_id
              AND spys.trade_date = (SELECT MIN(trade_date) FROM Price WHERE security_id = spy.security_id AND trade_date >= ?)
            JOIN Price spye ON spye.security_id = spy.security_id
              AND spye.trade_date = (SELECT MAX(trade_date) FROM Price WHERE security_id = spy.security_id AND trade_date <= ?)
            GROUP BY st.sector_id, st.sector_name, spys.close, spye.close
            ORDER BY relative_pct DESC",
       'ssss', [$start, $end, $start, $end]);
    break;

case 'r2':
    q($db, "SELECT i.industry_name, ROUND(AVG(fs.pe_ratio),2) AS avg_pe,
              COUNT(DISTINCT c.company_id) AS companies
            FROM Financial_Snapshot fs
            JOIN Stock sk  ON sk.security_id = fs.security_id
            JOIN Company c ON c.company_id   = sk.company_id
            JOIN Industry i ON i.industry_id = c.industry_id
            JOIN Sector s   ON s.sector_id   = i.sector_id
            WHERE s.sector_name = ? AND fs.pe_ratio > 0
              AND fs.snapshot_date = (SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = fs.security_id)
            GROUP BY i.industry_id, i.industry_name ORDER BY avg_pe DESC",
       's', [$sector]);
    break;

case 'r3':
    q($db, "WITH eps_lag AS (
              SELECT sk.company_id, fs.snapshot_date, fs.eps,
                LAG(fs.eps) OVER (PARTITION BY sk.company_id ORDER BY fs.snapshot_date) AS prev_eps
              FROM Financial_Snapshot fs JOIN Stock sk ON sk.security_id = fs.security_id
            ),
            streaks AS (
              SELECT company_id,
                SUM(CASE WHEN eps > prev_eps THEN 1 ELSE 0 END)
                  OVER (PARTITION BY company_id ORDER BY snapshot_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS streak_val
              FROM eps_lag WHERE prev_eps IS NOT NULL
            )
            SELECT c.company_name, sec.sector_name, MAX(s.streak_val) AS consecutive_qtrs
            FROM streaks s
            JOIN Company c   ON c.company_id  = s.company_id
            JOIN Industry i  ON i.industry_id = c.industry_id
            JOIN Sector sec  ON sec.sector_id  = i.sector_id
            WHERE s.streak_val >= ? AND (? = 'ALL' OR sec.sector_name = ?)
            GROUP BY c.company_id, c.company_name, sec.sector_name
            ORDER BY consecutive_qtrs DESC",
       'iss', [$min_q, $sector ?: 'ALL', $sector ?: 'ALL']);
    break;

case 'r4':
    q($db, "WITH daily_ret AS (
              SELECT p.security_id,
                (p.close - LAG(p.close) OVER (PARTITION BY p.security_id ORDER BY p.trade_date))
                / LAG(p.close) OVER (PARTITION BY p.security_id ORDER BY p.trade_date) AS ret
              FROM Price p WHERE p.trade_date BETWEEN ? AND ?
            )
            SELECT s.ticker, c.company_name,
              ROUND(STDDEV_SAMP(dr.ret) * SQRT(252) * 100, 2) AS ann_vol_pct
            FROM daily_ret dr
            JOIN Security s  ON s.security_id  = dr.security_id
            JOIN Stock sk    ON sk.security_id  = s.security_id
            JOIN Company c   ON c.company_id    = sk.company_id
            JOIN Industry i  ON i.industry_id   = c.industry_id
            JOIN Sector sec  ON sec.sector_id    = i.sector_id
            WHERE sec.sector_name = ? AND dr.ret IS NOT NULL
            GROUP BY s.ticker, c.company_name ORDER BY ann_vol_pct DESC LIMIT 10",
       'sss', [$start, $end, $sector]);
    break;

case 'r5':
    q($db, "SELECT i.industry_name, ROUND(AVG(fs.pe_ratio),1) AS avg_pe,
              COUNT(*) AS total_companies,
              ROUND(SUM(CASE WHEN fs.pe_ratio < (
                SELECT AVG(fs2.pe_ratio)
                FROM Financial_Snapshot fs2 JOIN Stock sk2 ON sk2.security_id = fs2.security_id
                     JOIN Company c2 ON c2.company_id = sk2.company_id
                WHERE c2.industry_id = i.industry_id AND fs2.pe_ratio > 0
                  AND fs2.snapshot_date = (SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = sk2.security_id)
              ) THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_below_avg
            FROM Financial_Snapshot fs
            JOIN Stock sk  ON sk.security_id  = fs.security_id
            JOIN Company c ON c.company_id    = sk.company_id
            JOIN Industry i ON i.industry_id  = c.industry_id
            WHERE fs.pe_ratio > 0
              AND fs.snapshot_date = (SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = fs.security_id)
            GROUP BY i.industry_id, i.industry_name ORDER BY pct_below_avg DESC");
    break;

case 'r6':
    q($db, "SELECT c.company_name, s.ticker,
              ROUND(d.annual_dividends / lp.close * 100, 2) AS div_yield_pct,
              ROUND(d.annual_dividends, 3) AS total_div_paid,
              ROUND(lp.close, 2) AS latest_close
            FROM (SELECT security_id, SUM(amount) AS annual_dividends
                  FROM Corporate_Action
                  WHERE action_type = 'dividend'
                    AND action_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
                  GROUP BY security_id HAVING SUM(amount) > 0) d
            JOIN Security s  ON s.security_id  = d.security_id
            JOIN Stock sk    ON sk.security_id  = s.security_id
            JOIN Company c   ON c.company_id    = sk.company_id
            JOIN Industry i  ON i.industry_id   = c.industry_id
            JOIN Sector sec  ON sec.sector_id    = i.sector_id
            JOIN Price lp ON lp.security_id = s.security_id
              AND lp.trade_date = (SELECT MAX(trade_date) FROM Price WHERE security_id = s.security_id)
            WHERE sec.sector_name = ? ORDER BY div_yield_pct DESC LIMIT 15",
       's', [$sector]);
    break;

case 'r7':
    q($db, "SELECT c.company_name, s.ticker, i.industry_name,
              ROUND(fs.market_cap/1e9, 1) AS mkt_cap_b,
              CASE WHEN fs.market_cap>=200000000000 THEN 'Mega Cap (>=200B)'
                   WHEN fs.market_cap>=10000000000  THEN 'Large Cap (10-200B)'
                   WHEN fs.market_cap>=2000000000   THEN 'Mid Cap (2-10B)'
                   ELSE 'Small Cap (<2B)' END AS cap_tier
            FROM Financial_Snapshot fs
            JOIN Stock sk   ON sk.security_id  = fs.security_id
            JOIN Company c  ON c.company_id    = sk.company_id
            JOIN Industry i ON i.industry_id   = c.industry_id
            JOIN Sector sec ON sec.sector_id    = i.sector_id
            JOIN Security s ON s.security_id    = fs.security_id
            WHERE sec.sector_name = ? AND fs.market_cap IS NOT NULL
              AND fs.snapshot_date = (SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = fs.security_id)
            ORDER BY fs.market_cap DESC",
       's', [$sector]);
    break;

case 'r8':
    q($db, "SELECT i.industry_name,
              ROUND(AVG(fs.beta),3) AS avg_beta, ROUND(MIN(fs.beta),3) AS min_beta,
              ROUND(MAX(fs.beta),3) AS max_beta, COUNT(DISTINCT c.company_id) AS companies
            FROM Financial_Snapshot fs
            JOIN Stock sk   ON sk.security_id  = fs.security_id
            JOIN Company c  ON c.company_id    = sk.company_id
            JOIN Industry i ON i.industry_id   = c.industry_id
            JOIN Sector sec ON sec.sector_id    = i.sector_id
            WHERE sec.sector_name = ? AND fs.beta IS NOT NULL
              AND fs.snapshot_date = (SELECT MAX(snapshot_date) FROM Financial_Snapshot WHERE security_id = fs.security_id)
            GROUP BY i.industry_id, i.industry_name ORDER BY avg_beta DESC",
       's', [$sector]);
    break;

case 'r9':
    q($db, "SELECT s.ticker, c.company_name, i.industry_name,
              ROUND(AVG(p.volume),0) AS avg_daily_vol,
              ROUND(AVG(p.close),2)  AS avg_close
            FROM Price p
            JOIN Security s  ON s.security_id  = p.security_id
            JOIN Stock sk    ON sk.security_id  = s.security_id
            JOIN Company c   ON c.company_id    = sk.company_id
            JOIN Industry i  ON i.industry_id   = c.industry_id
            JOIN Sector sec  ON sec.sector_id    = i.sector_id
            WHERE sec.sector_name = ? AND p.trade_date BETWEEN ? AND ?
            GROUP BY s.ticker, c.company_name, i.industry_name
            ORDER BY avg_daily_vol DESC LIMIT 10",
       'sss', [$sector, $start, $end]);
    break;

case 'tickers':
    // Full searchable universe (stocks + ETFs) with names, for autocomplete.
    q($db, "SELECT s.ticker,
              COALESCE(c.company_name, e.fund_name) AS company_name,
              s.security_type
            FROM Security s
            LEFT JOIN Stock sk  ON sk.security_id = s.security_id
            LEFT JOIN Company c ON c.company_id   = sk.company_id
            LEFT JOIN ETF e     ON e.security_id  = s.security_id
            WHERE s.security_type IN ('stock','etf')
            ORDER BY s.ticker");
    break;

case 'portfolios':
    q($db, "SELECT p.portfolio_id, p.portfolio_name, p.owner_name,
              COUNT(h.security_id) AS holdings
            FROM Portfolio p LEFT JOIN Holding h ON h.portfolio_id = p.portfolio_id
            GROUP BY p.portfolio_id, p.portfolio_name, p.owner_name
            ORDER BY p.portfolio_id");
    break;

case 'pf_holdings': {
    $pid  = (int)($_GET['pid'] ?? 0);
    $spec = $_GET['holdings'] ?? '';
    $H    = pf_get_holdings($db, $pid, $spec);
    $ref  = pf_reference($db, array_keys($H));
    $rows = [];
    foreach ($H as $t => $h) {
        $r     = $ref[$t] ?? null;
        $price = ($r && $r['latest_close'] !== null) ? (float)$r['latest_close'] : null;
        $mv    = $price !== null ? $price * $h['shares'] : null;
        $cb    = $h['cost'] * $h['shares'];
        $pl    = $mv !== null ? $mv - $cb : null;
        $name  = $r ? ($r['company_name'] ?? ($r['security_type'] === 'etf' ? 'ETF' : null)) : null;
        $sect  = $r ? ($r['sector_name']  ?? ($r['security_type'] === 'etf' ? 'ETF / Fund' : 'Other')) : 'Unknown ticker';
        $rows[] = [
            'ticker'            => $t,
            'company_name'      => $name,
            'sector_name'       => $sect,
            'shares'            => round($h['shares'], 4),
            'avg_cost'          => round($h['cost'], 4),
            'latest_close'      => $price !== null ? round($price, 2) : null,
            'market_value'      => $mv !== null ? round($mv, 2) : null,
            'cost_basis'        => round($cb, 2),
            'unrealized_pl'     => $pl !== null ? round($pl, 2) : null,
            'unrealized_pl_pct' => ($mv !== null && $cb > 0) ? round($pl / $cb * 100, 2) : null,
            'div_income_12mo'   => $r ? round((float)$r['div12'] * $h['shares'], 2) : 0,
        ];
    }
    echo json_encode(['rows'=>$rows]);
    break;
}

case 'pf_series': {
    $pid  = (int)($_GET['pid'] ?? 0);
    $spec = $_GET['holdings'] ?? '';
    $H    = pf_get_holdings($db, $pid, $spec);
    $ref  = pf_reference($db, array_keys($H));
    $pairs = [];
    foreach ($H as $t => $h) {
        if (isset($ref[$t]) && $ref[$t]['security_id'] !== null)
            $pairs[] = [(int)$ref[$t]['security_id'], (float)$h['shares']];
    }
    if (!$pairs) { echo json_encode(['rows'=>[]]); break; }
    // Portfolio market value per trading day = SUM(shares_i * close_i(date)).
    // Holdings are injected as a small (security_id, shares) derived table.
    $union  = implode(' UNION ALL ', array_fill(0, count($pairs), 'SELECT ? AS security_id, ? AS shares'));
    $types  = ''; $params = [];
    foreach ($pairs as $pr) { $types .= 'id'; $params[] = $pr[0]; $params[] = $pr[1]; }
    $types .= 'ss'; $params[] = $start; $params[] = $end;
    $sql = "SELECT p.trade_date, ROUND(SUM(p.close * h.shares), 2) AS port_value
            FROM Price p
            JOIN ($union) h ON h.security_id = p.security_id
            WHERE p.trade_date BETWEEN ? AND ?
            GROUP BY p.trade_date ORDER BY p.trade_date";
    $st = $db->prepare($sql);
    if (!$st) die(json_encode(['error'=>$db->error]));
    $st->bind_param($types, ...$params); $st->execute();
    $rows = $st->get_result()->fetch_all(MYSQLI_ASSOC); $st->close();
    echo json_encode(['rows'=>$rows]);
    break;
}

default:
    echo json_encode(['error'=>"unknown query: $q"]);
}

$db->close();
