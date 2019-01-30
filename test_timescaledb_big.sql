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

-- 按 [股票代码、日期、时间范围] 过滤，并取前 1000 条
select *
from taq
where
	symbol = 'IBM' and
	date = '2007-08-10' and
	time >= '09:30:00'
limit 1000;
-- 0.9 s


-- 按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价]
select symbol, time, bid, ofr
from taq
where
	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO') and
	date = '2007-08-10' and
	'09:30:00' <= time and time < '09:30:59' and
	bid > 0 and
	ofr > bid;
--


-- 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序
select *
from taq
where
	date = '2007-08-27' and
	symbol = 'EBAY'
order by (ofr - bid) desc;
-- 245 ms


-- 按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，查询 (各个股票 每分钟) [平均变化幅度]
select
    avg( (ofr - bid) / (ofr + bid) ) * 2 as spread,
    time_bucket('1 minute', time) one_minute
from taq
where
	date = '2007.08.01'  and
	'09:30:00' <= time and time < '16:00:00'  and
	bid > 0 and
	ofr > bid
group by symbol, one_minute;
-- 12.8 s



-- 计算 某天 (每个股票 每分钟) 最大卖出与最小买入价之差
select
    max(ofr) - min(bid) as gap,
    time_bucket('1 minute', time) one_minute
from taq
where
	date = '2007-08-03' and
	bid > 0 and
	ofr > bid
group by symbol, one_minute;
-- 8.6 s



-- 按 [股票代码、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价
select
    avg(ofr + bid) / 2.0 as avg_price,
    time_bucket('1 minute', time) one_minute
from taq
where
	symbol = 'IBM' and
	'09:30:00' <= time and time < '16:00:00'
group by date, one_minute;
-- 1.7 s



-- 按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价
select avg(ofr + bid) / 2.0 as avg_price
from taq
where
	'2007-08-05' <= date and date <= '2007-08-07' and
	'09:30:00' <= time and time <= '16:00:00'
group by symbol, date;
-- 16.8 s



-- 计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序
select sum(bid * bidsiz) / sum(bidsiz) as vwab
from taq
where
    '2007-08-05' <= date and date < '2007-08-11'
group by date, symbol
	having sum(bidsiz) > 0
order by date desc, symbol;
-- 41s



alter table taq rename column bidsize to bidsiz;
alter table taq rename column ofrsize to ofrsiz;



















































