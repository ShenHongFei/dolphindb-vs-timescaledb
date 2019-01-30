----------------------------------------- TimescaleDB 性能测试脚本

--------------------- TimescaleDB 安装、配置（见 test_timescaledb.sh）

--------------------- 创建数据表
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

drop table if exists device_info;
create table device_info (
    device_id       text,
    api_version     text,
    manufacturer    text,
    model           text,
    os_name         text
);

drop table if exists readings;
create table readings (
    time                timestamp with time zone not null,
    
    device_id           text,
    
    battery_level       double precision,
    battery_status      text,
    battery_temperature double precision,
    
    bssid               text,
    
    cpu_avg_1min        double precision,
    cpu_avg_5min        double precision,
    cpu_avg_15min       double precision,
    
    mem_free            double precision,
    mem_used            double precision,
    
    rssi                double precision,
    ssid                text
);


SELECT create_hypertable('readings', 'time', chunk_time_interval => interval '1 day');


--------------------- 导入数据（见 test_timescaledb.sh）

-- 查看数据
-- head -n 50 /data/devices/devices_big_device_info.csv
-- head -n 50 /data/devices/devices_big_readings.csv

-- 查看数据库大小
select pg_size_pretty(pg_database_size('test'));

-------------------- 建立索引 
create index on readings (time desc);
-- 24 s 305 ms

create index on readings (device_id, time desc);
-- 1 m 19 s

create index on readings (ssid);
-- 39 s



--------------------- 查询性能测试
-- 根据设备 ID 过滤
select count(*) from readings where device_id = 'demo000100';
-- 17 ms

-- 根据时间过滤
select count(*) from readings where "time" <= '2016-11-16 21:00:00';
-- 1 s 224 ms

select count(*) from readings where "time" >= '2016-11-16 21:00:00';
-- 1 s 768 ms


-- 根据整型和时间过滤
select count(*) from readings where "time" <= '2016-11-16 21:00:00' and battery_level >= 90;
-- 997 ms


-- 根据整型、浮点型和时间过滤
select count(*) from readings where "time" <= '2016-11-17 21:00:00' and battery_level >= 90 and cpu_avg_1min < 10.1;
-- 1 s 744 ms


-- 按设备连接的 SSID 分组（单列）
select avg(battery_level) from readings group by ssid;
-- 6 s 843 ms


-- 按设备连接的 SSID 分组（多列）
select avg(battery_level), min(battery_level) from readings group by ssid;
-- 7 s 134 ms


-- 按小时分组（单列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour;
-- 1 s 111 ms


-- 按小时分组（多列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour;
-- 1 s 167 ms


-- 按设备 ID、小时分组（单列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour, device_id;
-- 1 s 244 ms


-- 按设备 ID、小时分组（多列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour, device_id;
-- 1 s 325 ms


-- 根据时间过滤 + 按设备 ID、小时分组
select
    device_id,
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by device_id, one_hour;
-- 1 s 270 ms


-- 排序
select count(*)
from readings
group by battery_level
order by battery_level asc;
-- 4 s 943 ms



--------------------- 内置函数计算性能测试
-- 计数（count）
select count(battery_level) from readings;
-- 2 s 583 ms


-- 归一（distinct）
select distinct(battery_level) from readings;
-- 4 s 219 ms


-- 平均值（avg）
select avg(battery_level) from readings;
-- 2 s 912 ms


-- 标准差（stddev）
select stddev(battery_level) from readings;
-- 2 s 875 ms


-- 求和（sum）
select sum(battery_level) from readings;
-- 2 s 591 ms


-- 最大值（max）
select max(battery_level) from readings;
-- 2 s 659 ms



-- 滑动平均值（moving_average）
select count(r.avg)
from (
    select avg(battery_level) over (order by time rows between 99 preceding and current row)
    from readings
) as r;
-- 28 s (n = 10)
-- 2 m 54 s (n = 100)
-- O(n^2) 复杂度


-- 向下取整
select count(*)
from (
    select floor(battery_temperature)
    from readings
    ) t;
-- 2 s 267 ms


-- 浮点相加
select count(*)
from (
     select (cpu_avg_1min + cpu_avg_5min + cpu_avg_15min) sum_cpu
     from readings
    ) as t;
-- 2 s 254 ms



-- 浮点相乘
select count(*)
from (
     select (cpu_avg_1min * cpu_avg_5min * cpu_avg_15min) mul_cpu
     from readings
    ) as t;
-- 2 s 268 ms


-- 逻辑与
select count(*)
from readings
where battery_temperature > 90.0 and battery_level < 40 and mem_free > 400000000;
-- 2 s 945 ms


-- 求对数
select count(*)
from (
    select log(mem_free)
    from readings
    ) t;
-- 2 s 273 ms


--------------------- 表连接性能测试
-- 等值连接
select count(device_info)
from readings join device_info on readings.device_id = device_info.device_id;
-- 5 s 492 ms


-- 左连接
select count(device_info)
from readings left join device_info on readings.device_id = device_info.device_id;
-- 5 s 479 ms


select count(device_info)
from readings right join device_info on readings.device_id = device_info.device_id;
-- 5 s 569 ms



--------------------- 复杂查询性能测试
-- 查询充电设备的最近 20 条电池温度记录
select
    time,
    device_id,
    battery_temperature
from readings
where battery_status = 'charging'
order by time desc limit 20;
-- 4 ms


-- 未在充电的、电量小于 33% 的、平均 1 分钟内最高负载的 5 个设备
select
    readings.device_id,
    battery_level,
    battery_status,
    cpu_avg_1min
from readings join device_info on readings.device_id = device_info.device_id
where battery_level < 33 and battery_status = 'discharging'
order by cpu_avg_1min desc, time desc
limit 5;
-- 10 s 58 ms


-- 某两个型号的设备每小时最低电量的前 20 条数据
select
    date_trunc('hour', time) "hour",
    min(battery_level) min_battery_level
from readings r
where device_id in (
    select distinct device_id
    from device_info
    where model = 'pinto' or model = 'focus'
    )
group by "hour"
order by "hour" asc
limit 20;
-- 7 s 996 ms

































































































































































































