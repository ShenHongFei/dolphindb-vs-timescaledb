# DolphinDB vs TimescaleDB 性能对比测试报告
## 一、摘要

### TimescaleDB
TimescaleDB 是目前市面上唯一的开源且完全支持 SQL 的时序数据库。它在 PostgreSQL 数据库的基础上进行开发，本质上是一个 PostgreSQL 的插件。  
TimescaleDB 完全支持 SQL 且拥有 PostgreSQL 的丰富生态、并针对时间序列数据的快速插入和复杂查询进行了优化，支持自动分片，支持时间空间维度自动分区，支持多个 SERVER、多个 CHUNK 的并行查询，内部写优化（批量提交、内存索引、事务支持、数据倒灌）。  
然而，目前 TimerscaleDB 仍不支持水平扩展（集群），即不能动态增加新的数据结点以写入数据（Write clustering for multi-node Timescale deployments is under active development.   [https://github.com/timescale/timescaledb/issues/9](https://github.com/timescale/timescaledb/issues/9)），只支持通过 PostgreSQL 的流复制（streaming repliaction）实现的只读集群（read-only clustering）。

### DolphinDB
DolphinDB 是一款分析型的分布式时序数据库，内置处理流式数据处理引擎，具有内置的并行和分布式计算的功能，并提供分布式文件系统，支持集群扩展。  
DolphinDB 以 C++ 编写，响应速度极快。提供类似于 Python 的脚本语言对数据进行操作，支持类标准 SQL 的语法。提供其它常用编程语言的 API，方便与已有应用程序集成。在金融领域中的历史数据分析建模与实时流数据处理，以及物联网领域中的海量传感器数据处理与实时分析等场景中表现出色。

### A. 小数据集测试（3 千万条，4.2 GB CSV）

#### 数据集

我们从 TimescaleDB 官方给出的样例数据集中选择了 `devices_big` 作为小数据集来测试，共 `3 × 10^7` 条数据，`4.2 GB` CSV，包含一张设备信息表和一张设备传感器信息记录表。  
数据集包含 3000 个设备在 10000 个时间间隔（2016.11.15 - 2016.11.19）上的 `传感器时间`, `设备 ID`, `电池`, `内存`, `CPU` 等时序统计信息  
来源：<https://docs.timescale.com/v1.1/tutorials/other-sample-datasets>  
下载地址：<https://timescaledata.blob.core.windows.net/datasets/devices_big.tar.gz>

#### 测试内容

1. 数据导入导出
2. 磁盘占用空间
3. 简单查询（过滤、分组）
4. 内置函数计算
5. 表连接
6. 复杂查询

#### 结论

**导入性能：** DolphinDB / TimescaleDB ≈ `25 倍`

**导出性能：** DolphinDB / TimescaleDB ≈ `4 倍`

###### 磁盘占用空间

空间利用率：DolphinDB / TimescaleDB ≈ `12 倍`

###### 简单查询

5 个测试样例 DolphinDB / TimescaleDB ≈ `50 倍`  
7 个测试样例 DolphinDB / TimescaleDB ≈ `5 ~ 20 倍`  
1 个测试样例 DolphinDB / TimescaleDB ≈ `50%`

###### 内置函数计算

滑动平均函数 DolphinDB 比 TimescaleDB 效率高一个数量级（`n 倍`）  
4 个测试样例 DolphinDB / TimescaleDB ≈ `100+ 倍`  
8 个测试样例 DolphinDB / TimescaleDB ≈ `10 ~ 50 倍`

###### 表连接

等值连接 DolphinDB / TimescaleDB ≈ `25 倍`  
左连接   DolphinDB / TimescaleDB ≈ `1.8 倍`

###### 复杂查询

1 个测试样例 DolphinDB / TimescaleDB ≈ `1/200` （top 20 没有起到缩小查询范围的作用）

2 个测试样例 DolphinDB / TimescaleDB ≈ `80+ 倍`

### B. 大数据集测试（21 亿条，270 GB，23 个 CSV）

#### 数据集

我们从纽约证券交易所（NYSE）提供的 2007.08.01 - 2007.08.31 一个月的股市交易日历史数据作为大数据集进行测试。  
数据集中共有 21 亿（2,147,483,647）条交易记录，一个 CSV 中保存一个交易日的记录。未压缩的 23 个 CSV 文件共计 270 GB。  
数据集包含 8000 多支股票在一个月内的 `交易时间`, `股票代码`, `买入价`, `卖出价`, `买入量`, `卖出量` 等时序交易信息  
来源：<https://www.nyse.com/market-data/historical>

#### 测试内容

1.  数据导入
2.  磁盘占用空间
3.  经典查询

#### 结论

###### 导入性能

DolphinDB / TimescaleDB ≈ ` 倍`

###### 磁盘占用空间

空间利用率：DolphinDB / TimescaleDB ≈ ` 倍`






## 二、测试环境
由于 Timescale 目前仍未支持能够写入数据的集群，我们使用单机进行测试。

#### 硬件配置

主机：DELL OptiPlex 7060  
CPU ：Intel Core i7-8700（6 核 12 线程 3.20 GHz）  
内存：32 GB （8GB × 4, 2666 MHz）  
硬盘：2T HDD （222 MB/s 读取；210 MB/s 写入）

#### OS

Ubuntu 16.04 LTS

#### PostgreSQL & TimescaleDB

###### PostgreSQL 版本

PostgreSQL 10.6 (Ubuntu 10.6-1.pgdg16.04+1) on x86_64-pc-linux-gnu

###### TimescaleDB 版本

Timescale v1.1.1

###### PostgreSQL 配置（参考 https://pgtune.leopard.in.ua/ ）

listen_addresses = '*'

shared_preload_libraries = 'timescaledb'

max_connections = 20

shared_buffers = 8GB  
effective_cache_size = 20GB  
work_mem = 128MB  
maintenance_work_mem = 4GB

min_wal_size = 4GB  
max_wal_size = 8GB

checkpoint_completion_target = 0.9  
default_statistics_target = 500  
effective_io_concurrency = 1

max_worker_processes = 12  
max_parallel_workers_per_gather = 6  
max_parallel_workers = 12

random_page_cost = 4

#### DolphinDB

###### 版本

Linux v0.85 (2019.01.31)

###### 配置

localSite=localhost:8000:local8000  
maxMemSize=28  
maxConnections=20  
workerNum=12  
localExecutors=11

## 三、小数据集测试

#### Table Schema

-   **TimescaleDB**

```sql
create table device_info (
    device_id       text,
    api_version     text,
    manufacturer    text,
    model           text,
    os_name         text
);

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
```

**索引列：** `device_id`, `ssid`

###### 按天分为 4 个区

```plsql
SELECT create_hypertable('readings', 'time', chunk_time_interval => interval '1 day');
```

-   **DolphinDB**

###### device_info 表

| Column       | Type   |
| ------------ | ------ |
| device_id    | SYMBOL |
| api_version  | STRING |
| manufacturer | STRING |
| model        | STRING |
| os_name      | STRING |

###### readings 表

**Partition Schema:** `[2016.11.15T00:00:00, 2016.11.16T00:00:00, 2016.11.17T00:00:00, 2016.11.18T00:00:00, 2016.11.19T00:00:00]`


| column              | type     |
| ------------------- | -------- |
| time                | DATETIME |
| device_id           | SYMBOL   |
| battery_level       | DOUBLE   |
| battery_status      | STRING   |
| battery_temperature | DOUBLE   |
| bssid               | STRING   |
| cpu_avg_1min        | DOUBLE   |
| cpu_avg_5min        | DOUBLE   |
| cpu_avg_15min       | DOUBLE   |
| mem_free            | DOUBLE   |
| mem_used            | DOUBLE   |
| rssi                | DOUBLE   |
| ssid                | SYMBOL   |

###### 创建两张表的 Schema

```c++
// data path
fp_info     = '/data/devices/devices_big_device_info.csv'
fp_readings = '/data/devices/devices_big_readings.csv'

fp_db_readings = '/data/readings'

// 创建两张表的 schema
cols_info         = `device_id`api_version`manufacturer`model`os_name
cols_readings     = `time`device_id`battery_level`battery_status`battery_temperature`bssid`cpu_avg_1min`cpu_avg_5min`cpu_avg_15min`mem_free`mem_used`rssi`ssid

// tb_schema_readings = extractTextSchema(fp_readings)

types_info         = `SYMBOL`STRING`STRING`STRING`STRING
types_readings     = `DATETIME`SYMBOL`DOUBLE`STRING`DOUBLE`STRING`DOUBLE`DOUBLE`DOUBLE`DOUBLE`DOUBLE`DOUBLE`SYMBOL

schema_info     = table(cols_info, types_info)
schema_readings = table(cols_readings, types_readings)
```

###### 创建分区数据库并设置按天分区方案

```
db = database(fp_db_readings, RANGE, 2016.11.15T00:00:00 + 86400 * 0..4)
```

#### 1. 数据导入导出

###### 从 CSV 文件导入数据

-   TimescaleDB

```shell
# 导入 devices
timescaledb-parallel-copy \
    --workers 12 \
    --reporting-period 1s \
    --copy-options "CSV" \
    --connection "host=localhost user=postgres password=postgres dbname=test sslmode=disable" \
    --db-name test \
    --table device_info \
    --file /data/devices/devices_big_device_info.csv 
 
# 导入 readings
timescaledb-parallel-copy \
    --workers 12 \
    --reporting-period 1s \
    --copy-options "CSV" \
    --connection "host=localhost user=postgres password=postgres dbname=test sslmode=disable" \
    --db-name test \
    --table device_info \
    --file /data/devices/devices_big_readings.csv
```

时间：`12 min 43 sec`, row rate 39000/sec (overall), 3.000000E+07 total rows

-   DolphinDB

```c++
readings = loadTextEx(db, `readings, `time, fp_readings, , schema_readings)
device_info = loadText(fp_info, , schema_info)
```

时间：`28 sec`

**导入性能：**DolphinDB / TimescaleDB ≈ `25 倍`

###### 导出数据为 CSV 文件

-   TimescaleDB

```shell
time psql -d test -c "\COPY (SELECT * FROM readings) TO /data/devices_dump.csv DELIMITER ',' CSV"
```

时间：`1m 44s`

-   DolphinDB

```
saveText((select * from readings), '/data/readings_dump.csv')
```

时间：`28 s`

**导出性能：** DolphinDB / TimescaleDB ≈ `4 倍`

#### 2. 磁盘占用空间

原始数据 4.2 GB CSV

```sql
-- TimescaleDB
select pg_size_pretty(pg_database_size('test'));
-- 15 GB
```

```shell
# DolphinDB
du -sh /mnt/data/DolphinDB
# 1.3 GB
```

空间利用率：DolphinDB / TimescaleDB ≈ `12 倍`    Δ ≈ 14 GB


#### 3. 简单查询

##### 格式

```sql
-- 测试样例名称
<TimescaleDB 查询语句>
-- TimescaleDB 耗时
<DolphinDB 查询语句>
// DolphinDB 耗时
性能：DolphinDB / TimescaleDB ≈ 性能比    Δ ≈ 时间差
```

##### 测试结果

```sql
-- 根据设备 ID 过滤
select count(*) from readings where device_id = 'demo000100';
-- 17 ms
select count(*) from readings where device_id = 'demo000100';
// 31 ms
性能：DolphinDB / TimescaleDB ≈ 50%    Δ ≈ 15 ms


-- 根据时间过滤
select count(*) from readings where "time" <= '2016-11-16 21:00:00';
-- 1 s 224 ms
select count(*) from readings where time <= 2016.11.16 21:00:00;
// 28.65 ms
性能：DolphinDB / TimescaleDB ≈ 40 倍    Δ ≈ 1.2 s

select count(*) from readings where "time" >= '2016-11-16 21:00:00';
-- 1 s 768 ms
select count(*) from readings where time >= 2016.11.16 21:00:00;
// 26.363 ms
性能：DolphinDB / TimescaleDB ≈ 60 倍    Δ ≈ 1.7 s


-- 根据整型和时间过滤
select count(*) from readings where "time" <= '2016-11-16 21:00:00' and battery_level >= 90;
-- 997 ms
select count(*) from readings where time <= 2016.11.16 21:00:00 and battery_level >= 90;
// 89.531 ms
性能：DolphinDB / TimescaleDB ≈ 11 倍    Δ ≈ 0.9 s


-- 根据整型、浮点型和时间过滤
select count(*) from readings where "time" <= '2016-11-17 21:00:00' and battery_level >= 90 and cpu_avg_1min < 10.1;
-- 1 s 744 ms
select count(*) from readings where time <= 2016.11.17 21:00:00 and battery_level >= 90 and cpu_avg_1min < 10.1;
// 134.485 ms
性能：DolphinDB / TimescaleDB ≈ 13 倍    Δ ≈ 0.9 s


-- 按设备连接的 SSID 分组（单列）
select avg(battery_level) from readings group by ssid;
-- 6 s 843 ms
select avg(battery_level) from readings group by ssid;
// 142.92 ms
性能：DolphinDB / TimescaleDB ≈ 50 倍    Δ ≈ 6 s


-- 按设备连接的 SSID 分组（多列）
select avg(battery_level), min(battery_level) from readings group by ssid;
-- 7 s 134 ms
select avg(battery_level), min(battery_level) from readings group by ssid;
// 116.473 ms
性能：DolphinDB / TimescaleDB ≈ 60 倍    Δ ≈ 7 s



-- 按小时分组（单列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour;
-- 1 s 111 ms
select avg(cpu_avg_1min)
from readings
where 2016.11.16 21:00:00 <= time and time <= 2016.11.17 08:00:00
group by hour(time);
// 55.461 ms
性能：DolphinDB / TimescaleDB ≈ 20 倍    Δ ≈ 1 s


-- 按小时分组（多列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour;
-- 1 s 167 ms
select
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where 2016.11.16 21:00:00 <= time and time <= 2016.11.17 08:00:00
group by hour(time);
// 70.547 ms
性能：DolphinDB / TimescaleDB ≈ 16 倍    Δ ≈ 1 s



-- 按设备 ID、小时分组（单列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour, device_id;
-- 1 s 244 ms
select
    avg(cpu_avg_1min)
from readings
where 2016.11.16 21:00:00 <= time and time <= 2016.11.17 08:00:00
group by hour(time), device_id;
// 181.143 ms
性能：DolphinDB / TimescaleDB ≈ 16 倍    Δ ≈ 1 s


-- 按设备 ID、小时分组（多列）
select
    time_bucket('1 hour', time) one_hour,
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where '2016-11-16 21:00:00' <= time and time <= '2016-11-17 08:00:00'
group by one_hour, device_id;
-- 1 s 325 ms
select
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where 2016.11.16 21:00:00 <= time and time <= 2016.11.17 08:00:00
group by hour(time), device_id;
// 213.301 ms
性能：DolphinDB / TimescaleDB ≈ 5 倍    Δ ≈ 1 s


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
select
    avg(cpu_avg_1min),
    max(cpu_avg_1min)
from readings
where 2016.11.16 21:00:00 <= time and time <= 2016.11.17 08:00:00
group by device_id, hour(time);
// 227.405 ms
性能：DolphinDB / TimescaleDB ≈ 5 倍    Δ ≈ 1 s


-- 排序
select count(*)
from readings
group by battery_level
order by battery_level asc;
-- 4 s 943 ms
select count(*)
from readings
group by battery_level
order by battery_level asc;
// 95.66 ms
性能：DolphinDB / TimescaleDB ≈ 50 倍    Δ ≈ 5 s

```

#### 4. 内置函数计算

```sql
-- 计数（count）
select count(battery_level) from readings;
-- 2 s 583 ms
select count(battery_level) from readings;
// 0.585 ms
性能：DolphinDB / TimescaleDB ≈ 50 倍    Δ ≈ 5 s


-- 归一（distinct）
select distinct(battery_level) from readings;
-- 4 s 219 ms
select distinct(battery_level) from readings;
// 85.026 ms
性能：DolphinDB / TimescaleDB ≈ 50 倍    Δ ≈ 4 s


-- 平均值（avg）
select avg(battery_level) from readings;
-- 2 s 912 ms
select avg(battery_level) from readings;
// 11.275 ms
性能：DolphinDB / TimescaleDB ≈ 290 倍    Δ ≈ 2 s


-- 标准差（stddev）
select stddev(battery_level) from readings;
-- 2 s 875 ms
select std(battery_level) from readings;
// 21.56 ms
性能：DolphinDB / TimescaleDB ≈ 140 倍    Δ ≈ 2 s


-- 求和（sum）
select sum(battery_level) from readings;
-- 2 s 591 ms
select sum(battery_level) from readings;
// 11.425 ms
性能：DolphinDB / TimescaleDB ≈ 240 倍    Δ ≈ 2 s


-- 最大值（max）
select max(battery_level) from readings;
-- 2 s 659 ms
select max(battery_level) from readings;
// 14.341 ms
性能：DolphinDB / TimescaleDB ≈ 240 倍    Δ ≈ 2 s


-- 滑动平均值（moving_average）
select count(r.avg)
from (
    select avg(battery_level) over (order by time rows between 99 preceding and current row)
    from readings
) as r;
-- 28 s (n = 10)
-- 2 m 54 s (n = 100)
-- O(n^2) 复杂度
select mavg(battery_level, 100) from readings
// 124.467 ms (n = 10)
// 84.947 ms (n = 100)
// O(n) 复杂度
性能：DolphinDB / TimescaleDB ≈ n 倍    Δ ≈ 3 min


-- 向下取整
select count(*)
from (
    select floor(battery_temperature)
    from readings
    ) t;
-- 2 s 267 ms
select floor(battery_temperature)
from readings
// 110.551 ms
性能：DolphinDB / TimescaleDB ≈ 20 倍    Δ ≈ 2 s


-- 浮点相加
select count(*)
from (
     select (cpu_avg_1min + cpu_avg_5min + cpu_avg_15min) sum_cpu
     from readings
    ) as t;
-- 2 s 254 ms
select (cpu_avg_1min + cpu_avg_5min + cpu_avg_15min)
from readings
// 170.305 ms
性能：DolphinDB / TimescaleDB ≈ 13 倍    Δ ≈ 2 s


-- 浮点相乘
select count(*)
from (
     select (cpu_avg_1min * cpu_avg_5min * cpu_avg_15min) mul_cpu
     from readings
    ) as t;
-- 2 s 268 ms
select (cpu_avg_1min * cpu_avg_5min * cpu_avg_15min)
from readings
// 71.45 ms （cpu_avg_* 等列已加载进内存）
性能：DolphinDB / TimescaleDB ≈ 30 倍    Δ ≈ 2 s


-- 逻辑与
select count(*)
from readings
where battery_temperature > 90.0 and battery_level < 40 and mem_free > 400000000;
-- 2 s 945 ms
select count(*)
from readings
where battery_temperature > 90.0 and battery_level < 40 and mem_free > 400000000;
// 132.777 ms
性能：DolphinDB / TimescaleDB ≈ 20 倍    Δ ≈ 2 s


-- 求对数
select count(*)
from (
    select log(mem_free)
    from readings
    ) t;
-- 2 s 273 ms
select log(mem_free)
from readings
// 214.694 ms
性能：DolphinDB / TimescaleDB ≈ 10 倍    Δ ≈ 2 s
```

#### 5. 表连接

```sql
-- 等值连接
select count(device_info)
from readings join device_info on readings.device_id = device_info.device_id;
-- 5 s 492 ms
select count(device_info)
from ej(readings, device_info, 'device_id')
// 221.206 ms
性能：DolphinDB / TimescaleDB ≈ 25 倍    Δ ≈ 5 s


-- 左连接
select count(device_info)
from readings left join device_info on readings.device_id = device_info.device_id;
-- 5 s 479 ms
select count(device_info)
from lj(readings, device_info, 'device_id')
// 2916.276 ms
性能：DolphinDB / TimescaleDB ≈ 1.8 倍    Δ ≈ 2 s
```

#### 6. 复杂查询

```sql 
-- 查询充电设备的最近 20 条电池温度记录
select
    time,
    device_id,
    battery_temperature
from readings
where battery_status = 'charging'
order by time desc limit 20;
-- 4 ms
select top 20
    time,
    device_id,
    battery_temperature
from readings
where battery_status = 'charging'
order by time desc
// 876.276 ms （top 20 没有起到缩小查询范围的作用）
性能：DolphinDB / TimescaleDB ≈ 1/200    Δ ≈ 800 ms


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
// 未在充电的、电量小于 33% 的、平均 1 分钟内最高负载的 5 个设备
select
    time,
    device_id,
    battery_temperature
from readings
where battery_status = 'charging'
order by time desc
// 105.454 ms
性能：DolphinDB / TimescaleDB ≈ 100 倍    Δ ≈ 10 s


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
timer {
    device_ids = 
        exec distinct device_id
        from device_info
        where model = 'pinto' or model = 'focus';

    battery_levels = 
        select min(battery_level) as min_battery_level
        from readings
        where device_id in device_ids
        group by hour(time)
        order by hour_time asc;

    battery_levels[0:20]
}
// 116.365 ms
性能：DolphinDB / TimescaleDB ≈ 80 倍    Δ ≈ 8 s


```


## 四、大数据集测试

#### Table Schema

-   **TimescaleDB**

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

drop table if exists taq;

-- SYMBOL,DATE,TIME,BID,OFR,BIDSIZ,OFRSIZ,MODE,EX,MMID

-- create type Symbol as enum (...);    执行 create_symbols_enum.sql 以创建 Symbol 枚举类型。该文件是根据 TAQ20070801.csv 中提取的 symbols 生成的 Symbol 枚举类型创建语句。生成方法见附录

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

```

我们按 `date(日期)`, `symbol(股票代码)` 进行分区，每天根据 symbol 分为 100 个分区，每个分区大概 120 MB 左右。

-   **DolphinDB**

| Column | Type   |
| ------ | ------ |
| symbol | SYMBOL |
| date   | DATE   |
| time   | SECOND |
| bid    | DOUBLE |
| ofr    | DOUBLE |
| bidsiz | INT    |
| ofrsiz | INT    |
| mode   | INT    |
| ex     | CHAR   |
| mmid   | SYMBOL |

创建分区

```c++
FP_TAQ = '/data/TAQ/'
FP_SAMPLE_TB = FP_TAQ + 'csv/TAQ20070801.csv'


orig_tb_schema = extractTextSchema(FP_SAMPLE_TB)
// 查看 orig_tb_schema
// 将列名调整为小写避免与 DolphinDB 内置的 SYMBOL, DATE, TIME 等保留关键字产生冲突
cols = lower(orig_tb_schema.name)
schema = table(cols, orig_tb_schema.type)
// table(lower(orig_tb_schema.name), orig_tb_schema.type)     报错 Every table column should have a unique name. ？？



sample_tb = ploadText(FP_SAMPLE_TB, , schema)
// 用时 40s

sample_freq_tb = select count(*) from sample_tb group by symbol
mmid_tb = select count(*) from sample_tb group by mmid
// FLOW, EDGX, EDGA, NASD

// 导出 symbols ，使 TimescaleDB 的 symbol 字段能够基于这些 symbols 创建 enum type
saveText(sample_freq_tb.symbol, FP_TAQ + 'symbols.txt')


// 8369 rows, [symbol, count], 分到 100 个 buckets
BIN_NUM = 100

buckets = cutPoints(sample_freq_tb.symbol, BIN_NUM, sample_freq_tb.count)
// [A, ABL, ACU, ..., ZZZ], 101 个边界
buckets[BIN_NUM] = `ZZZZZZ        // 调整最右边界


DATE_RANGE = 2007.01.01..2008.01.01

// 创建数据库分区方案
date_schema   = database('', VALUE, DATE_RANGE)
symbol_schema = database('', RANGE, buckets)



FP_DB = FP_TAQ + 'db/'
db = database(FP_DB, COMPO, [date_schema, symbol_schema])

sample_tb = NULL

FP_CSV = FP_TAQ + 'csv/'
fps = FP_CSV + (exec filename from files(FP_CSV) order by filename)

```

在 DolphinDB 中我们先根据 `date(日期)` 进行值分区，再根据 `symbol(股票代码)` 进行范围分区（100 个范围）

#### 1. 数据导入

-   TimescaleDB

由于 `timescaledb-parallel-copy` 工具不支持 CSV 首行为列名称，我们先用 `tail -n +2` 跳过 CSV 首行，再将文件流写入其标准输入。

```bash
for f in /data/TAQ/csv/*.csv ; do
    tail -n +2 $f | timescaledb-parallel-copy \
        --workers 12 \
        --reporting-period 1s \
        --copy-options "CSV" \
        --connection "host=localhost user=postgres password=postgres dbname=test sslmode=disable" \
        --db-name test \
        --table taq \
        --batch-size 200000
    
    echo "文件 $f 导入完成"
done
```

时间：`4 小时` 仅导入了 `TAQ20070801` 一个文件（`16.6 GB`）, row rate `26572/sec` (overall), 3.834733E+08 total rows，还剩下 22 个文件（253 GB），预计导入所有文件需要 。

预计将数据全部导入需要

-   DolphinDB

```c++
// 单机硬盘分区数据库不能同时并发写入数据（不支持事务），以下代码报错 The database didn't close normally or another transaction is in the progress.
/*
    for (fp in fps) {
        job_id = fp.strReplace(".csv", "")
        job_name = job_id
        fp = FP_TAQ + FP_CSV + fp
        submitJob(job_id, job_name, loadTextEx{db, `taq, `date`symbol, fp})
    }

    getRecentJobs(size(fps))
*/

// pt = loadTextEx(db, `taq, `date`symbol, fps[0], ,schema)

timer {
    for (fp in fps) {
        loadTextEx(db, `taq, `date`symbol, fp, ,schema)
        print now() + ": 已导入 " + fp
    }
}

```

时间：`38 分钟`

**导入性能：** DolphinDB / TimescaleDB ≈ ` 倍`

#### 2. 经典查询

```sql
-- 按 [股票代码、日期、时间范围] 过滤，并取前 1000 条
select *
from taq
where
    symbol = 'IBM' and
    date = '2007-08-10' and
    time >= '09:30:00'
limit 1000;
--
select top 1000 *
from taq
where
    symbol = 'IBM',
    date = 2007.08.10,
    time >= 09:30:00
// 0.9 s



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
select symbol, time, bid, ofr
from taq
where
    symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'), 
    date = 2007.08.10, 
    time between 09:30:00 : 09:30:59, 
    bid > 0, 
    ofr > bid
// 
性能：DolphinDB / TimescaleDB ≈  倍    Δ ≈  s


-- 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序
select *
from taq
where
    date = '2007-08-27' and
    symbol = 'EBAY'
order by (ofr - bid) desc;
--
select *
from taq
where
    date = 2007.08.27, 
    symbol = 'EBAY'
order by (ofr - bid) as spread desc
// 245 ms
性能：DolphinDB / TimescaleDB ≈  倍    Δ ≈  s


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
--
select avg( (ofr - bid) / (ofr + bid) ) * 2 as spread 
from taq 
where 
    date = 2007.08.01,
    time between 09:30:00 : 16:00:00,
    bid > 0,
    ofr > bid
group by symbol, minute(time) as minute
// 12.8 s
性能：DolphinDB / TimescaleDB ≈  倍    Δ ≈  s



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
--
select max(ofr) - min(bid) as gap 
from taq 
where 
    date = 2007.08.03, 
    bid > 0, 
    ofr > bid
group by symbol, minute(time) as minute
// 8.6 s
性能：DolphinDB / TimescaleDB ≈  倍    Δ ≈  s



-- 按 [股票代码、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价
select
    avg(ofr + bid) / 2.0 as avg_price,
    time_bucket('1 minute', time) one_minute
from taq
where
    symbol = 'IBM' and
    '09:30:00' <= time and time < '16:00:00'
group by date, one_minute;
--
select avg(ofr + bid) / 2.0 as avg_price
from taq 
where 
    symbol = 'IBM', 
    time between 09:30:00 : 16:00:00
group by date, minute(time) as minute
// 1.7 s
性能：DolphinDB / TimescaleDB ≈  倍    Δ ≈  s



-- 按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价
select avg(ofr + bid) / 2.0 as avg_price
from taq
where
    '2007-08-05' <= date and date <= '2007-08-07' and
    '09:30:00' <= time and time <= '16:00:00'
group by symbol, date;
--
select avg(ofr + bid) / 2.0 as avg_price
from taq 
where
    date between 2007.08.05 : 2007.08.07,
    time between 09:30:00 : 16:00:00
group by symbol, date
// 
性能：DolphinDB / TimescaleDB ≈  倍    Δ ≈  s



-- 计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序
select sum(bid * bidsiz) / sum(bidsiz) as vwab
from taq
where
    '2007-08-05' <= date and date < '2007-08-11'
group by date, symbol
    having sum(bidsiz) > 0
order by date desc, symbol;
--
select wavg(bid, bidsiz) as vwab 
from taq
where date between 2007.08.05 : 2007.08.11
group by date, symbol
    having sum(bidsiz) > 0
order by date desc, symbol
// 41s
性能：DolphinDB / TimescaleDB ≈  倍    Δ ≈  s

```

## 五、其他方面比较

-   DolphinDB 提供了更加先进的分布式数据库系统和分布式计算引擎，内置处理流式数据处理引擎，并提供分布式文件系统，支持集群水平扩展；而 TimescaleDB 的集群功能目前仍在开发中。
-   DolphinDB 基于高吞吐低延迟的列式内存引擎，具有更灵活的分区方案：值分区、范围分区、列表分区、哈希分区、组合分区。支持单表百万级别的分区数，大大缩减对海量数据的检索响应时间。
-   DolphinDB 使用多范式编程脚本语言，表达能力强，不仅支持 SQL 编程，还支持支持命令式编程、函数化编程、向量化编程、元编程 和 RPC 编程，且提供近 600 个内置函数，实现时间与字符串处理、文件处理、函数话编程、时间序列运算、矩阵计算、统计分析、机器学习等功能。这使得用户可在极短时间内完成复杂交互式任务，如量化交易策略的研发，极大提高工作效率。
-   DolphinDB 支持流数据计算，启用 `发布 -- 订阅` 流数据计算模型，支持多级级联订阅，支持流表对偶性。发布一条信息相当于在表中增加一条记录。可以使用 SQL 查询本地流数据或分布式流数据。

## 六、文件目录

-   CSV 数据格式预览（取前 20 行）

| 数据     | 文件                         |
| -------- | ---------------------------- |
| devices  | [devices.csv](devices.csv)   |
| readings | [readings.csv](readings.csv) |
| TAQ      | [TAQ.csv](TAQ.csv)           |

-   TimescaleDB

| 脚本                          | 文件                                                     |
| ----------------------------- | -------------------------------------------------------- |
| 安装、配置、启动脚本          | [test_timescaledb.sh](test_timescaledb.sh)               |
| 小数据集测试完整脚本          | [test_timescaledb_small.sql](test_timescaledb_small.sql) |
| 大数据集测试完整脚本          | [test_timescaledb_big.sql](test_timescaledb_big.sql)     |
| 股票代码所有可能值            | [symbols.txt](symbols.txt)                               |
| 创建 Symbol 枚举类型 SQL 语句 | [make_symbol_enum.sql](make_symbol_enum.sql)             |
| 生成 Symbol 枚举类型脚本      | [make_symbol_enum.coffee](make_symbol_enum.coffee)       |


-   DolphinDB

| 脚本                 | 文件                                                 |
| -------------------- | ---------------------------------------------------- |
| 安装、配置、启动脚本 | [test_dolphindb.sh](test_dolphindb.sh)               |
| 小数据集测试完整脚本 | [test_dolphindb_small.sql](test_dolphindb_small.sql) |
| 大数据集测试完整脚本 | [test_dolphindb_big.sql](test_dolphindb_big.sql)     |


