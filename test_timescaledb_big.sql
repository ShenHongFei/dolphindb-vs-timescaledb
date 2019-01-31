CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

drop table if exists taq;

-- SYMBOL,DATE,TIME,BID,OFR,BIDSIZ,OFRSIZ,MODE,EX,MMID

-- create type Symbol as enum (...);    见 create_symbols_enum.sql

create type MMID as enum ('FLOW', 'EDGX', 'EDGA', 'NASD', '');

create table taq (
    symbol Symbol,
    date date,
    time time without time zone,
    bid double precision,
    ofr double precision,
    bidsiz integer,
    ofrsiz integer,
    mode integer,
    ex character,
    mmid Mmid
);


select create_hypertable('taq', 'date', 'symbol', 100, chunk_time_interval => interval '1 day');


---------------- 综合查询性能测试

select count(*) from taq;
-- ∞

-- 按 [股票代码、日期、时间范围] 过滤，并取前 1000 条
select *
from taq
where
	symbol = 'IBM' and
	date = '2007-08-03' and
	time >= '09:30:00'
limit 1000;
-- 663 ms


-- 按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
select count(*)
from (
    select symbol, time, bid, ofr
    from taq
    where
    	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO') and
    	date = '2007-08-03' and
    	'09:30:00' <= time and time < '09:30:59' and
    	bid > 0 and
    	ofr > bid
    ) as t;
-- 6 s 909 ms


-- 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序
select count(*)
from (
    select *
    from taq
    where
    	date = '2007-08-06' and
    	symbol = 'EBAY'
    order by (ofr - bid) desc
    ) as t;
-- 2 s 475 ms


-- 按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，查询 (各个股票 每分钟) [平均变化幅度]
select count(*)
from (
    select
        symbol,
        date_trunc('minute', time) as one_minute,
        avg( (ofr - bid) / (ofr + bid) ) * 2 as spread
    from taq
    where
    	date = '2007.08.01'  and
    	'09:30:00' <= time and time < '16:00:00'  and
    	bid > 0 and
    	ofr > bid
    group by symbol, one_minute
    ) as t;
--  4 m 35 s



-- 计算 某天 (每个股票 每分钟) 最大卖出与最小买入价之差
select count(*)
from (
    select
        symbol,
        date_trunc('minute', time) as one_minute,
        max(ofr) - min(bid) as gap
    from taq
    where
    	date = '2007-08-03' and
    	bid > 0 and
    	ofr > bid
    group by symbol, one_minute
    ) as t;
-- 4 m 39 s



-- 按 [股票代码、日期段、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价
select count(*)
from (
    select
        date,
        date_trunc('minute', time) as one_minute,
        avg(ofr + bid) / 2.0 as avg_price
    from taq
    where
    	symbol = 'IBM' and
        '2007-08-01' <= date and date <= '2007-08-07' and
    	'09:30:00' <= time and time < '16:00:00'
    group by date, one_minute
    ) as t;
-- 6 s 320 ms



-- 按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价
select count(*)
from (
    select
        symbol,
        date,
        avg(ofr + bid) / 2.0 as avg_price
    from taq
    where
    	'2007-08-05' <= date and date <= '2007-08-07' and
    	'09:30:00' <= time and time <= '16:00:00'
    group by symbol, date
    ) as t;
--



-- 计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序
select count(*)
from (
    select
        date,
        symbol,
        sum(bid * bidsiz) / sum(bidsiz) as vwab
    from taq
    where
        '2007-08-05' <= date and date <= '2007-08-06'
    group by date, symbol
    	having sum(bidsiz) > 0
    order by date desc, symbol
    ) as t;
--





















































