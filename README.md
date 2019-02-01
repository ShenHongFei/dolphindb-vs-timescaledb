# DolphinDB vs TimescaleDB 性能对比测试报告
## 一、介绍

### TimescaleDB
TimescaleDB 是目前市面上唯一的开源且完全支持 SQL 的时序数据库。它在 PostgreSQL 数据库的基础上进行开发，本质上是一个 PostgreSQL 的插件。  
TimescaleDB 完全支持 SQL 且拥有 PostgreSQL 的丰富生态、并针对时间序列数据的快速插入和复杂查询进行了优化，支持自动分片，支持时间空间维度自动分区，支持多个 SERVER、多个 CHUNK 的并行查询，内部写优化（批量提交、内存索引、事务支持、数据倒灌）。  
然而，目前 TimerscaleDB 仍不支持水平扩展（集群），即不能动态增加新的数据结点以写入数据（Write clustering for multi-node Timescale deployments is under active development. <https://github.com/timescale/timescaledb/issues/9>），只支持通过 PostgreSQL 的流复制（streaming repliaction）实现的只读集群（read-only clustering）。

### DolphinDB
DolphinDB 是一款分析型的分布式时序数据库，内置处理流式数据处理引擎，具有内置的并行和分布式计算的功能，并提供分布式文件系统，支持集群扩展。  
DolphinDB 以 C++ 编写，响应速度极快。提供类似于 Python 的脚本语言对数据进行操作，支持类标准 SQL 的语法。提供其它常用编程语言的 API，方便与已有应用程序集成。在金融领域中的历史数据分析建模与实时流数据处理，以及物联网领域中的海量传感器数据处理与实时分析等场景中表现出色。

## 二、数据集

### 4.2 GB 设备传感器记录小数据集（CSV 格式，3 千万条）

我们从 TimescaleDB 官方给出的样例数据集中选择了 `devices_big` 作为小数据集来测试，共 `3 × 10^7` 条数据，`4.2 GB` CSV，包含一张设备信息表和一张设备传感器信息记录表。  
数据集包含 3000 个设备在 10000 个时间间隔（2016.11.15 - 2016.11.19）上的 `传感器时间`, `设备 ID`, `电池`, `内存`, `CPU` 等时序统计信息。  
来源：<https://docs.timescale.com/v1.1/tutorials/other-sample-datasets>
下载地址：<https://timescaledata.blob.core.windows.net/datasets/devices_big.tar.gz>

### 270 GB 股票交易大数据集（CSV 格式，23 个 CSV，65 亿条）

我们从纽约证券交易所（NYSE）提供的 2007.08.01 - 2007.08.31 一个月的股市交易日历史数据作为大数据集进行测试。  
数据集中共有 65 亿（6,561,693,704）条交易记录，一个 CSV 中保存一个交易日的记录。未压缩的 23 个 CSV 文件共计 270 GB。  
数据集包含 8000 多支股票在一个月内的 `交易时间`, `股票代码`, `买入价`, `卖出价`, `买入量`, `卖出量` 等时序交易信息。  
来源：<https://www.nyse.com/market-data/historical>

## 三、测试内容

**TimescaleDB 目前仍未支持能够写入数据的集群，因此我们使用单机进行测试。**

1. 数据导入导出
2. 磁盘空间占用
3. 常用查询
4. 表连接

## 四、结论

### 导入性能

|            数据集             |        DolphinDB         |          TimescaleDB          | 导入性能 （DolphinDB / TimescaleDB） |    Δ    |
| :---------------------------: | :-------------------------: | :---------------------------: | :----------------------------------: | :-----: |
| 4.2 GB 设备传感器记录小数据集 |  1,500,000 条/秒, 共 20 秒  | 60,300 条/秒, 共 8 分钟 17 秒 |                25 倍                 | 8 分钟  |
|    270 GB 股票交易大数据集    | 2,900,000 条/秒, 共 38 分钟 |   20,000 条/秒, 共 92 小时    |                145 倍                | 91 小时 |

todo: 分析事务对导入性能的影响

### 导出性能（仅小数据集）

|        DolphinDB         |          TimescaleDB          | 导出性能 （DolphinDB / TimescaleDB） |   Δ    |
| :----------------------: | :---------------------------: | :----------------------------------: | :----: |
| 1,070,000 条/秒    28 秒 | 322,580 条/秒    1 分钟 33 秒 |                 3 倍                 | 1 分钟 |


### 磁盘空间占用

|            数据集             | DolphinDB | TimescaleDB | 空间利用率 （DolphinDB / TimescaleDB） |   Δ    |
| :---------------------------: | :-------: | :---------: | :------------------------------------: | :----: |
| 4.2 GB 设备传感器记录小数据集 |  1.2 GB   |    5 GB     |                  4 倍                  |  4 GB  |
|    270 GB 股票交易大数据集    |   51 GB   |   864 GB    |                 17 倍                  | 813 GB |

### 常用查询

| 样例                                                         | DolphinDB 用时 | TimescaleDB 用时 | 性能比 ( DolphinDB / TimescaleDB )                           | Δ      |
| ------------------------------------------------------------ | -------------- | ---------------- | ------------------------------------------------------------ | ------ |
| 按设备 ID 查询记录数                                         | 56 ms          | 160 ms           | 30% <br />TimescaleDB 在 device_id 上建立了索引，而 DolphinDB 未建立索引，<br />所以对于 device_id 的搜索有性能上的提升 | 100 ms |
| 查找某时间段内低电量的未充电设备，<br />显示其 ID、电量      | 266 ms         | 547 ms           | 2 倍                                                         | 280 ms |
| 计算某时间段内高负载高电量设备的内存大小                     | 1.3 s          | 2.1 s            | 1.7 倍                                                       | 0.8 s  |
| 统计连接不同网络的设备的平均电量和最大、最小电量，<br />并按平均电量降序排列 | 0.32 s         | 6.4 s            | 20 倍                                                        | 6 s    |
| 查找所有设备平均负载最高的时段，<br />并按照负载降序排列、时间升序排列 | 0.84 s         | 3.9 s            | 4.6 倍                                                       | 3 s    |
| 查找各个时间段内某些设备的总负载，并将时段按总负载降序排列   | 35 ms          | 19 ms            | 50%                                                          | 15 ms  |
| 查询充电设备的最近 20 条电池温度记录                         | 385 ms         | 4 ms             | 1%<br />top 20 没有起到缩小查询范围的作用                    | 400 ms |
| 未在充电的、电量小于 33% 的、平均 1 分钟内最高负载的 5 个设备 | 0.1 s          | 8.5 s            | 80 倍                                                        | 8 s    |
| 某两个型号的设备每小时最低电量的前 20 条数据                 | 0.11 s         | 8 s              | 70 倍                                                        | 8 s    |
| 按 [股票代码、日期、时间范围] 过滤，并取前 1000 条           | 900 ms         | 663 ms           | 70%                                                          | 300 ms |
| 按 [多个股票代码、日期，时间范围、报价范围] 过滤，<br />查询 [股票代码、时间、买入价、卖出价] | 0.35 s         | 6.9 s            | 27 倍                                                        | 6 s    |
| 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序    | 0.4 s          | 2.47 s           | 6 倍                                                         | 2 s    |
| 按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，<br />查询 (各个股票 每分钟) [平均变化幅度] | 16.8 s         | 4 m 35 s         | 16 倍                                                        | 4 min  |
| 计算 某天 (每个股票 每分钟) 最大卖出与最小买入价之差         | 8.4 s          | 4 m 39 s         | 33 倍                                                        | 4 min  |
| 按 [股票代码、日期段、时间段] 过滤， <br />查询 (每天，时间段内每分钟) 均价 | 0.35 s         | 6.3 s            | 18 倍                                                        | 6 s    |
| 按 [日期段、时间段] 过滤， 查询 (每股票，每天) 均价          | 16.7 s         | 10 m 1 s         | 36 倍                                                        | 10 min |
| 计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，<br />并按 (日期，股票代码) 排序 | 4.3 s          | 2 m 53 s         | 40 倍                                                        | 3 min  |

### 表连接

| 样例个数 | 性能比 （DolphinDB / TimescaleDB） |
| :------: | :--------------------------------: |
| 等值连接 |               25 倍                |
|  左连接  |               1.8 倍               |

## 五、测试环境

### 硬件配置

主机：DELL OptiPlex 7060
CPU ：Intel Core i7-8700（6 核 12 线程 3.20 GHz）
内存：32 GB （8GB × 4, 2666 MHz）
硬盘：2T HDD （222 MB/s 读取；210 MB/s 写入）

### OS

Ubuntu 16.04 LTS

### PostgreSQL & TimescaleDB

#### PostgreSQL 版本

PostgreSQL 10.6 (Ubuntu 10.6-1.pgdg16.04+1) on x86_64-pc-linux-gnu

#### TimescaleDB 版本

Timescale v1.1.1

#### PostgreSQL 配置

参考了 https://pgtune.leopard.in.ua/ , <https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server>

```ini
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
```

### DolphinDB

#### 版本

Linux v0.85 (2019.01.31)

#### 配置

```ini
localSite=localhost:8000:local8000
maxMemSize=28
maxConnections=20
workerNum=12
localExecutors=11
```

## 六、表结构 & 分区方式

### device_info 表

| Column       | DolphinDB | TimescaleDB |
| ------------ | --------- | ----------- |
| device_id    | SYMBOL    | text        |
| api_version  | SYMBOL    | enum        |
| manufacturer | SYMBOL    | enum        |
| model        | SYMBOL    | enum        |
| os_name      | SYMBOL    | enum        |

### readings 表


| Column              | DolphinDB | TimescaleDB                       |
| ------------------- | --------- | --------------------------------- |
| time                | DATETIME  | timestamp with time zone not null |
| device_id           | SYMBOL    | text (有索引)                     |
| battery_level       | DOUBLE    | double precision                  |
| battery_status      | SYMBOL    | enum                              |
| battery_temperature | DOUBLE    | double precision                  |
| bssid               | SYMBOL    | text                              |
| cpu_avg_1min        | DOUBLE    | double precision                  |
| cpu_avg_5min        | DOUBLE    | double precision                  |
| cpu_avg_15min       | DOUBLE    | double precision                  |
| mem_free            | DOUBLE    | double precision                  |
| mem_used            | DOUBLE    | double precision                  |
| rssi                | DOUBLE    | double precision                  |
| ssid                | SYMBOL    | text (有索引)                     |

按天分为 4 个区，分区边界为 `[2016.11.15 00:00:00, 2016.11.16 00:00:00, 2016.11.17 00:00:00, 2016.11.18 00:00:00, 2016.11.19 00:00:00]`

-   DolphinDB

    ```
    db = database(fp_db_readings, RANGE, 2016.11.15T00:00:00 + 86400 * 0..4)
    ```

-   TimescaleDB

    ```plsql
    SELECT create_hypertable('readings', 'time', chunk_time_interval => interval '1 day');
    ```

### taq 表

| Column | DolphinDB | TimescaleDB            |
| ------ | --------- | ---------------------- |
| symbol | SYMBOL    | enum                   |
| date   | DATE      | date                   |
| time   | SECOND    | time without time zone |
| bid    | DOUBLE    | double precision       |
| ofr    | DOUBLE    | double precision       |
| bidsiz | INT       | integer                |
| ofrsiz | INT       | integer                |
| mode   | INT       | integer                |
| ex     | CHAR      | character              |
| mmid   | SYMBOL    | enum                   |

我们按 `date(日期)`, `symbol(股票代码)` 进行分区，每天再根据 symbol 分为 100 个分区，每个分区大概 120 MB 左右。

-   DolphinDB

    ```c++
    BIN_NUM = 100
    DATE_RANGE = 2007.01.01..2008.01.01
        
    buckets = cutPoints(sample_freq_tb.symbol, BIN_NUM, sample_freq_tb.count)
    // [A, ABL, ACU, ..., ZZZ], 101 个边界
    buckets[BIN_NUM] = `ZZZZZZ        // 调整最右边界
    
    // 创建数据库分区方案
    date_schema   = database('', VALUE, DATE_RANGE)
    symbol_schema = database('', RANGE, buckets)
    db = database(FP_DB, COMPO, [date_schema, symbol_schema])
    ```

-   TimescaleDB

    ```plsql
    select create_hypertable('taq', 'date', 'symbol', 100, chunk_time_interval => interval '1 day');
    ```


## 七、测试流程

### 1. 数据导入导出

#### 从 CSV 文件导入数据

-   TimescaleDB

由于 `timescaledb-parallel-copy` 工具不支持 CSV 首行为列名称，我们先用 `tail -n +2` 跳过 CSV 首行，再将文件流写入其标准输入。

导入脚本样例

```shell
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

4.2 GB 设备传感器记录小数据集：共 `30,000,000` 条数据导入用时 `8 分钟 17 秒`, 平均速率 `60,300 条/秒`

270 GB 股票交易大数据集： 仅 `TAQ20070801, TAQ20070802, TAQ20070803, TAQ20070806, TAQ20070807` 五个文件（总大小 `70 GB`）所包含的 `16.7 亿` 条数据导入用时 `24 小时`，导入速率 `19400 条/秒`，预计将数据全部 `270 GB` 数据导入需要 `92 小时`。

-   DolphinDB

导入脚本样例

```c++
timer {
    for (fp in fps) {
        loadTextEx(db, `taq, `date`symbol, fp, ,schema)
        print now() + ": 已导入 " + fp
    }
}
```

4.2 GB 设备传感器记录小数据集：共 `30,000,000` 条数据导入用时 `20 秒`, 平均速率 `1,500,000 条/秒`

270 GB 股票交易大数据集：共 6,561,693,704 条数据（`TAQ20070801 - TAQ20070831` 23 个文件）导入用时 `38 分钟`

##### 导入性能

|            数据集             |        DolphinDB         |          TimescaleDB          | 导入性能 （DolphinDB / TimescaleDB） |    Δ    |
| :---------------------------: | :-------------------------: | :---------------------------: | :----------------------------------: | :-----: |
| 4.2 GB 设备传感器记录小数据集 |  1,500,000 条/秒, 共 20 秒  | 60,300 条/秒, 共 8 分钟 17 秒 |                25 倍                 | 8 分钟  |
|    270 GB 股票交易大数据集    | 2,900,000 条/秒, 共 38 分钟 |   20,000 条/秒, 共 92 小时    |                145 倍                | 91 小时 |


#### 导出数据为 CSV 文件

-   TimescaleDB

```shell
time psql -d test -c "\COPY (SELECT * FROM readings) TO /data/devices/devices_dump.csv DELIMITER ',' CSV"
```

-   DolphinDB

```c++
saveText((select * from readings), '/data/devices/readings_dump.csv')
```

|        DolphinDB         |          TimescaleDB          | 导入性能 （DolphinDB / TimescaleDB） |   Δ    |
| :----------------------: | :---------------------------: | :----------------------------------: | :----: |
| 1,070,000 条/秒    28 秒 | 322,580 条/秒    1 分钟 33 秒 |                 3 倍                 | 1 分钟 |

### 2. 磁盘空间占用

-   TimescaleDB

```sql
select pg_size_pretty(pg_database_size('test'));
```

-   DolphinDB

```shell
du -sh /mnt/data/DolphinDB
```

|            数据集             | DolphinDB | TimescaleDB | 空间利用率 （DolphinDB / TimescaleDB） |   Δ    |
| :---------------------------: | :-------: | :---------: | :------------------------------------: | :----: |
| 4.2 GB 设备传感器记录小数据集 |  1.2 GB   |    5 GB     |                  4 倍                  |  4 GB  |
|    270 GB 股票交易大数据集    |   51 GB   |   864 GB    |                 17 倍                  | 813 GB |


### 3. 常用查询

#### 格式

```sql
-- 测试样例名称
<TimescaleDB 查询语句>
-- TimescaleDB 耗时
<DolphinDB 查询语句>
// DolphinDB 耗时
性能：DolphinDB / TimescaleDB ≈ 性能比    Δ ≈ 时间差
```

#### 测试内容

```sql
-- TimescaleDB 建立索引 
create index on readings (time desc);
-- 26 s 547 ms
create index on readings (device_id, time desc);
-- 1 m 25 s
create index on readings (ssid);
-- 39 s


-- 按设备 ID 查询记录数
select count(*)
from readings
where device_id = 'demo000101';
-- 56 ms
select count(*)
from readings
where device_id = 'demo000101'
// 160 ms
性能：DolphinDB / TimescaleDB ≈ 1/3    Δ ≈ 100 ms
由于 TimescaleDB 在 device_id 上建立了索引，而 DolphinDB 未建立索引，所以对于 device_id 的搜索有性能上的提升

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
-- 547 ms
select min(battery_level)
from readings
where
	time between 2016.11.17 21:00:00 : 2016.11.18 09:00:00,
    battery_level <= 10,
    battery_status = 'discharging'
group by device_id
// 266 ms
性能：DolphinDB / TimescaleDB ≈ 2    Δ ≈ 280 ms


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
-- 2 s 173 ms
select
	max(date(time)) as date,
	max(mem_free + mem_used) as mem_all
from readings
where
    time <= 2016.11.18 21:00:00,
    battery_level >= 90,
    cpu_avg_1min > 90
group by hour(time), device_id
// 1306 ms
性能：DolphinDB / TimescaleDB ≈ 1.7    Δ ≈ 1 s


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
select
    max(battery_level) as max_battery,
    avg(battery_level) as avg_battery,
    min(battery_level) as min_battery
from readings
group by ssid
order by avg_battery desc
// 328 ms
性能：DolphinDB / TimescaleDB ≈ 20    Δ ≈ 6 s


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
-- 3 s 889 ms
select floor(avg(cpu_avg_15min)) as load
from readings
where time between 2016.11.16 00:00:00 : 2016.11.18 00:00:00
group by hour(time) as hour
order by load desc, hour asc;
// 847 ms
性能：DolphinDB / TimescaleDB ≈ 4.6    Δ ≈ 3 s


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
-- 19 ms
select sum(cpu_avg_15min) as sum_load
from readings
where
	time between 2016.11.15 12:00:00 : 2016.11.16 12:00:00,
    device_id in ['demo000001', 'demo000010', 'demo000100', 'demo001000']
group by hour(time)
order by sum_load desc
// 35 ms
性能：DolphinDB / TimescaleDB ≈ 1/2    Δ ≈ 15 ms


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
// 385 ms （top 20 没有起到缩小查询范围的作用）
性能：DolphinDB / TimescaleDB ≈ 1/100 倍    Δ ≈ 400 ms


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
-- 8 s 540 ms
// 未在充电的、电量小于 33% 的、平均 1 分钟内最高负载的 5 个设备
select
    time,
    device_id,
    battery_temperature
from readings
where battery_status = 'charging'
order by time desc
// 105.454 ms
性能：DolphinDB / TimescaleDB ≈ 80 倍    Δ ≈ 8 s


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
-- 8 s 47 ms
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
性能：DolphinDB / TimescaleDB ≈ 70 倍    Δ ≈ 8 s



-- 按 [股票代码、日期、时间范围] 过滤，并取前 1000 条
select *
from taq
where
	symbol = 'IBM' and
	date = '2007-08-03' and
	time >= '09:30:00'
limit 1000;
-- 663 ms
select top 1000 *
from taq
where
	symbol = 'IBM',
	date = 2007.08.03,
	time >= 09:30:00
// 900 ms
性能：DolphinDB / TimescaleDB ≈ 70%    Δ ≈ 300 ms


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
select symbol, time, bid, ofr
from taq
where
	symbol in ('IBM', 'MSFT', 'GOOG', 'YHOO'), 
	date = 2007.08.03, 
	time between 09:30:00 : 09:30:59, 
	bid > 0, 
	ofr > bid
// 357 ms
性能：DolphinDB / TimescaleDB ≈ 27 倍    Δ ≈ 6 s


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
select *
from taq
where
	date = 2007.08.06, 
	symbol = 'EBAY'
order by (ofr - bid) as spread desc
// 402 ms
性能：DolphinDB / TimescaleDB ≈ 6 倍    Δ ≈ 2 s



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
select avg( (ofr - bid) / (ofr + bid) ) * 2 as spread 
from taq 
where 
	date = 2007.08.01,
	time between 09:30:00 : 16:00:00,
	bid > 0,
	ofr > bid
group by symbol, minute(time) as minute
// 16.8 s
性能：DolphinDB / TimescaleDB ≈ 16 倍    Δ ≈ 4 min


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
select max(ofr) - min(bid) as gap 
from taq 
where 
	date = 2007.08.03, 
	bid > 0, 
	ofr > bid
group by symbol, minute(time) as minute
// 8.4 s
性能：DolphinDB / TimescaleDB ≈ 33 倍    Δ ≈ 4 min


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
select avg(ofr + bid) / 2.0 as avg_price
from taq 
where 
	symbol = 'IBM', 
	date between 2007.08.01 : 2007.08.07
	time between 09:30:00 : 16:00:00
group by date, minute(time) as minute
// 355 ms
性能：DolphinDB / TimescaleDB ≈ 18 倍    Δ ≈ 6 s


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
-- 10 m 1 s
select avg(ofr + bid) / 2.0 as avg_price
from taq 
where
	date between 2007.08.05 : 2007.08.07,
	time between 09:30:00 : 16:00:00
group by symbol, date
// 16.7 s
性能：DolphinDB / TimescaleDB ≈ 36 倍    Δ ≈ 10 min


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
-- 2 m 53 s
select wavg(bid, bidsiz) as vwab 
from taq
where date between 2007.08.05 : 2007.08.06
group by date, symbol
	having sum(bidsiz) > 0
order by date desc, symbol
// 4.3 s
性能：DolphinDB / TimescaleDB ≈ 40 倍    Δ ≈ 3 min
```


### 4. 表连接

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

## 八、其他方面比较

-   DolphinDB 提供了更加先进的分布式数据库系统和分布式计算引擎，内置处理流式数据处理引擎，并提供分布式文件系统，支持集群水平扩展；而 TimescaleDB 的集群功能目前仍在开发中。
-   DolphinDB 基于高吞吐低延迟的列式内存引擎，具有更灵活的分区方案：值分区、范围分区、列表分区、哈希分区、组合分区。支持单表百万级别的分区数，大大缩减对海量数据的检索响应时间。
-   DolphinDB 使用多范式编程脚本语言，表达能力强，不仅支持 SQL 编程，还支持支持命令式编程、函数化编程、向量化编程、元编程 和 RPC 编程，且提供近 600 个内置函数，实现时间与字符串处理、文件处理、函数话编程、时间序列运算、矩阵计算、统计分析、机器学习等功能。这使得用户可在极短时间内完成复杂交互式任务，如量化交易策略的研发，极大提高工作效率。
-   DolphinDB 支持流数据计算，启用 `发布 -- 订阅` 流数据计算模型，支持多级级联订阅，支持流表对偶性。发布一条信息相当于在表中增加一条记录。可以使用 SQL 查询本地流数据或分布式流数据。

## 九、文件目录

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
| PostgresQL 配置               | [postgresql.conf](postgresql.conf)                       |
| PostgresQL 权限配置           | [pg_hba.conf](pg_hba.conf)                               |
| 股票代码所有可能值            | [symbols.txt](symbols.txt)                               |
| 创建 Symbol 枚举类型 SQL 语句 | [make_symbol_enum.sql](make_symbol_enum.sql)             |
| 生成 Symbol 枚举类型脚本      | [make_symbol_enum.coffee](make_symbol_enum.coffee)       |


-   DolphinDB

| 脚本                 | 文件                                                 |
| -------------------- | ---------------------------------------------------- |
| 安装、配置、启动脚本 | [test_dolphindb.sh](test_dolphindb.sh)               |
| 小数据集测试完整脚本 | [test_dolphindb_small.txt](test_dolphindb_small.txt) |
| 大数据集测试完整脚本 | [test_dolphindb_big.txt](test_dolphindb_big.txt)     |


