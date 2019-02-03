----------------------------------------- TimescaleDB 性能测试脚本

--------------------- TimescaleDB 安装、配置（见 test_timescaledb.sh）

--------------------- 创建数据表
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

drop table if exists device_info;

create type BatteryStatus as enum ('discharging', 'charging');
create type ApiVersion as enum ('19', '21', '22', '23');
create type Manufacturer as enum ('iobeam');
create type Model as enum ('focus', 'mustang', 'pinto');
create type OSName as enum ('4.4.4', '5.0.0', '5.1.0', '6.0.1');


create table device_info (
    device_id       text,
    api_version     ApiVersion,
    manufacturer    Manufacturer,
    model           Model,
    os_name         OSName
);



drop table if exists readings;
create table readings (
    time                timestamp with time zone not null,
    
    device_id           text,
    
    battery_level       integer,
    battery_status      BatteryStatus,
    battery_temperature double precision,
    
    bssid               text,
    
    cpu_avg_1min        double precision,
    cpu_avg_5min        double precision,
    cpu_avg_15min       double precision,
    
    mem_free            bigint,
    mem_used            bigint,
    
    rssi                smallint,
    ssid                text
);


SELECT create_hypertable('readings', 'time', 'device_id', 10, chunk_time_interval => interval '1 day');


--------------------- 导入数据（见 test_timescaledb.sh）

-- 查看数据
-- head -n 50 /data/devices/devices_big_device_info.csv
-- head -n 50 /data/devices/devices_big_readings.csv

-- 查看数据库大小
select pg_size_pretty(pg_database_size('test3'));

select count(*) from readings;

--------------------- 导出数据（见 test_timescaledb.sh）

-------------------- 建立索引 
create index on readings (time desc);
-- 29 s

create index on readings (device_id, time desc);
-- 1 m 43 s

create index on readings (ssid);
-- 48 s



--------------------- 简单查询及内置函数计算
-- 按设备 ID 查询记录数
select count(*)
from readings
where device_id = 'demo000101';
-- 18 ms


-- 查找某时间段内低电量的未充电设备，显示其 ID、电量
select count(*)
from (
    select
        device_id,
        min(battery_level)
    from readings
    where
        '2016-11-17 21:00:00' <= time and time < '2016-11-18 09:00:00' and
        battery_level <= 10 and
        battery_status = 'discharging'
    group by device_id
    ) t;
-- 574 ms


-- 计算某时间段内高负载高电量设备的内存大小
select count(*)
from (
    select
        date_trunc('hour', time) one_hour,
        device_id,
        max(mem_free + mem_used) as mem_all
    from readings
    where
        time <= '2016-11-18 21:00:00' and
        battery_level >= 90 and
        cpu_avg_1min > 90
    group by one_hour, device_id
) t;
-- 2 s 296 ms


-- 统计连接不同网络的设备的平均电量和最大、最小电量，并按平均电量降序排列
select count(*)
from (
    select
        ssid,
        max(battery_level) max_battery,
        avg(battery_level) avg_battery,
        min(battery_level) min_battery
    from readings
    group by ssid
    order by avg_battery desc
) t;
-- 6 s 412 ms


-- 查找所有设备平均负载最高的时段，并按照负载降序排列、时间升序排列
select count(*)
from (
    select
        time_bucket('1 hour', time) as one_hour,
        floor(avg(cpu_avg_15min)) as load
    from readings
    where '2016-11-16 00:00:00' <= time and time <= '2016-11-18 00:00:00'
    group by one_hour
    order by load desc, one_hour asc
) t;
-- 3 s 939 ms



-- 查找各个时间段内某些设备的总负载，并将时段按总负载降序排列
select count(*)
from (
    select
        time_bucket('1 hour', time) as one_hour,
        sum(cpu_avg_15min) sum_load
    from readings
    where
        '2016-11-15 12:00:00' <= time and time <= '2016-11-16 12:00:00' and
        device_id in ('demo000001','demo000010','demo000100','demo001000')
    group by one_hour
    order by sum_load desc
) t;
-- 20 ms



-- 设备电量滑动平均值（moving_average）
-- select count(*)
-- from (
--     select device_id,
--         time_bucket('1 hour',time) as one_hour,
--         avg(battery_level) over (order by time rows between 99 preceding and current row)
--     from readings
--     group by device_id, one_hour
-- ) t;
-- 28 s (n = 10)
-- 2 m 54 s (n = 100)
-- O(n^2) 复杂度




--------------------- 经典查询性能测试
-- 查询充电设备的最近 20 条电池温度记录
select
    time,
    device_id,
    battery_temperature
from readings
where battery_status = 'charging'
order by time desc
limit 20;
-- 9 ms


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
-- 13 s 747 ms


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
-- 8 s 55 ms



--------------------- 表连接性能测试
-- 等值连接
select count(device_info)
from readings join device_info on readings.device_id = device_info.device_id;
-- 5 s 534 ms


-- 左连接
select count(device_info)
from readings left join device_info on readings.device_id = device_info.device_id;
-- 5 s 519 ms


