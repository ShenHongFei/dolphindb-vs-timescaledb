# DolphinDB vs TimescaleDB 性能对比测试报告
## 一、概述

### DolphinDB
DolphinDB 是以 C++ 编写的一款分析型的高性能分布式时序数据库，使用高吞吐低延迟的列式内存引擎，集成了功能强大的编程语言和高容量高速度的流数据分析系统，可在数据库中进行复杂的编程和运算，显著减少数据迁移所耗费的时间。  
DolphinDB 通过内存引擎、数据本地化、细粒度数据分区和并行计算实现高速的分布式计算，内置流水线、 Map Reduce 和迭代计算等多种计算框架，使用内嵌的分布式文件系统自动管理分区数据及其副本，为分布式计算提供负载均衡和容错能力。  
DolphinDB 支持类标准 SQL 的语法，提供类似于 Python 的脚本语言对数据进行操作，也提供其它常用编程语言的 API，在金融领域中的历史数据分析建模与实时流数据处理，以及物联网领域中的海量传感器数据处理与实时分析等场景中表现出色。  

### TimescaleDB

TimescaleDB 是目前市面上唯一的开源且完全支持 SQL 的时序数据库。它在 PostgreSQL 数据库的基础上进行开发，本质上是一个 PostgreSQL 的插件。  
TimescaleDB 完全支持 SQL 且拥有 PostgreSQL 的丰富生态、并针对时间序列数据的快速插入和复杂查询进行了优化，支持自动分片，支持时间空间维度自动分区，支持多个 SERVER、多个 CHUNK 的并行查询，内部写优化（批量提交、内存索引、事务支持、数据倒灌）。  
然而，目前 TimerscaleDB 仍不支持水平扩展（集群），即不能动态增加新的数据结点以写入数据（Write clustering for multi-node Timescale deployments is under active development. <https://github.com/timescale/timescaledb/issues/9>），只支持通过 PostgreSQL 的流复制（streaming repliaction）实现的只读集群（read-only clustering）。  

在本报告中，我们对 TimescaleDB 和 DolphinDB，在时间序列数据集上进行了性能对比测试。测试涵盖了 CSV 数据文件的导入导出、磁盘空间占用、查询性能等三方面。在我们进行的所有测试中，DolphinDB 均表现的更出色，主要结论如下：

-   数据导入方面，小数据集情况下 DolphinDB 的导入性能是 TimescaleDB 的 `10+ 倍` ，大数据集的情况下导入性能是其 `100+ 倍` ，而且在导入过程中可以观察到随着导入时间的增加，TimescaleDB 的导入速率不断下降，而 DolphinDB 保持稳定。
-   数据导出方面，DolphinDB 的性能是 TimescaleDB 的 `3 倍` 左右。
-   磁盘空间占用方面，小数据集下 DolphinDB 占用的空间仅仅是 TimescaleDB 的 `1/6` ，大数据集下占用空间仅仅是 TimescaleDB 的 `1/17`
-   查询性能方面，DolphinDB 在 `4 个` 测试样例中性能超过 TimescaleDB `50+ 倍` ；在 `15 个` 测试样例中性能为 TimescaleDB `10 ~ 50 倍` ; 在 `10 个` 测试样例中性能是 TimescaleDB 的数倍；仅有 `2 个` 测试样例性能不足 TimescaleDB。

## 二、测试环境

TimescaleDB 目前仍未支持能够写入数据的集群，因此我们使用单机进行测试，单机的配置为

主机：DELL OptiPlex 7060  
CPU ：Intel Core i7-8700（6 核 12 线程 3.20 GHz）  
内存：32 GB （8GB × 4, 2666 MHz）  
硬盘：2T HDD （222 MB/s 读取；210 MB/s 写入）  
OS：Ubuntu 16.04 LTS  

我们测试时使用的 DolphinDB 版本为 Linux v0.89 (2019.01.31)，最大内存设置为 `28GB`

我们测试时使用的 PostgreSQL 版本为 Ubuntu 10.6-1 on x86_64， TimescaleDB 插件的版本为 v1.1.1  
根据 TimescaleDB 官方指南推荐的性能调优方法，结合测试机器的实际硬件配置，我们在 <https://pgtune.leopard.in.ua/> 网站上生成了配置文件，同时参考了 <https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server> 这一官方配置指南作了优化，主要将 `shared_buffers` 和 `effective_cache_size` 设置为 `16GB`，并根据 12 线程 CPU 设置了 `parallel workers` ，由于仅使用一块机械硬盘，我们将 `effective_io_concurrency` 设置为 1，具体修改的配置详见附录中 `postgresql_test.conf` 文件


## 三、数据集

本报告测试了 小数据量级(4.2 GB) 和 大数据量级(270 GB) 下 DolphinDB 和 TimescaleDB 的表现情况：

在小数据量级的测试中我们预先将硬盘中的分区数据表全部加载到内存中，即在 DolphinDB 中使用 loadTable(memoryMode=true)，在 PostgresQL 中使用 pg_prewarm 插件将其加载至 shared_buffers  
在大数据量级的测试中我们不预先加载硬盘分区表，查询测试的时间包含磁盘 I/O 的时间，为保证测试公平，每次启动程序测试前均通过 Linux 系统命令 `sync; echo 1,2,3 | tee /proc/sys/vm/drop_caches` 分别清除系统的页面缓存、目录项缓存和硬盘缓存。  

以下是两个数据集的表结构和分区方法：

### 4.2 GB 设备传感器记录小数据集（CSV 格式，3 千万条）

我们从 TimescaleDB 官方给出的样例数据集中选择了 `devices_big` 作为小数据集来测试，数据集包含 3000 个设备在 10000 个时间间隔（2016.11.15 - 2016.11.19）上的 `传感器时间`, `设备 ID`, `电池`, `内存`, `CPU` 等时序统计信息。

来源：<https://docs.timescale.com/v1.1/tutorials/other-sample-datasets>  
下载地址：<https://timescaledata.blob.core.windows.net/datasets/devices_big.tar.gz>

数据集共 `3 × 10^7` 条数据（`4.2 GB` CSV），压缩包内包含一张设备信息表和一张设备传感器信息记录表，表结构以及分区方式如下：

### device_info 表

| Column       | DolphinDB　数据类型 | TimescaleDB 数据类型 |
| ------------ | ------------------- | -------------------- |
| device_id    | SYMBOL    | text        |
| api_version  | SYMBOL    | enum        |
| manufacturer | SYMBOL    | enum        |
| model        | SYMBOL    | enum        |
| os_name      | SYMBOL    | enum        |

### readings 表


| Column              | DolphinDB 数据类型      | TimescaleDB 数据类型                         |
| ------------------- | ----------------------- | -------------------------------------------- |
| time                | DATETIME (分区第一维度) | timestamp with time zone not null (分区维度) |
| device_id           | SYMBOL (分区第二维度)   | text (有索引)                                |
| battery_level       | INT                     | integer                                      |
| battery_status      | SYMBOL                  | enum                                         |
| battery_temperature | DOUBLE                  | double precision                             |
| bssid               | SYMBOL                  | text                                         |
| cpu_avg_1min        | DOUBLE                  | double precision                             |
| cpu_avg_5min        | DOUBLE                  | double precision                             |
| cpu_avg_15min       | DOUBLE                  | double precision                             |
| mem_free            | LONG                    | bigint                                       |
| mem_used            | LONG                    | bigint                                       |
| rssi                | SHORT                   | smallint                                     |
| ssid                | SYMBOL                  | text (有索引)                                |

数据集中 `device_id` 这一字段有 3000 个不同的值，这些值在 readings 表的记录中反复出现，用 text 类型不仅占用大量空间而且查询效率较低，但是在 TimescaleDB 中我们难以对这一字段采用 enum 类型，而 DolphinDB 的 Symbol 类型简单高效地解决了存储空间和查询效率这两大问题。

同样，对于 `bssid` 和 `ssid` 这两个字段表示设备连接的 WiFi 信息，在实际中因为数据的不确定性，虽然有大量的重复值，但并不适合使用 enum 类型。

我们在 DolphinDB 中的分区方案是将 `time` 作为分区的第一个维度，按天分为 4 个区，分区边界为 `[2016.11.15 00:00:00, 2016.11.16 00:00:00, 2016.11.17 00:00:00, 2016.11.18 00:00:00, 2016.11.19 00:00:00]`；再将 `device_id` 作为分区的第二个维度，每天一共分 10 个区，最后每个分区所包含的原始数据大小约为 `100 MB`。

我们尝试了在 TimescaleDB 中将 `device_id` 作为分区的第二个维度，但经测试 90% 查询样例的性能反而不如仅由时间维度进行分区，因此我们选择仅按照时间维度和按天分为 4 个区，该维度和 DolphinDB 的分区方式相同，而 `device_id` 这一维度以官方推荐的建立索引的方式 `create index on readings (device_id, time desc); create index on readings (ssid, time desc);`（参考 <https://docs.timescale.com/v1.0/using-timescaledb/schema-management#indexing> ）来加快查询速度。


### 270 GB 股票交易大数据集（CSV 格式，23 个 CSV，65 亿条）

我们将纽约证券交易所（NYSE）提供的 2007.08.01 - 2007.08.31 一个月的股市 Level 1 报价数据作为大数据集进行测试，数据集包含 8000 多支股票在一个月内的 `交易时间`, `股票代码`, `买入价`, `卖出价`, `买入量`, `卖出量` 等报价信息。  
数据集中共有 65 亿（6,561,693,704）条报价记录，一个 CSV 中保存一个交易日的记录，该月共 23 个交易日，未压缩的 CSV 文件共计 270 GB。
来源：<https://www.nyse.com/market-data/historical>


### taq 表

| Column | DolphinDB             | TimescaleDB            |
| ------ | --------------------- | ---------------------- |
| symbol | SYMBOL (分区第二维度) | enum (分区第二维度)    |
| date   | DATE (分区第一维度)   | date (分区第一维度)    |
| time   | SECOND                | time without time zone |
| bid    | DOUBLE                | double precision       |
| ofr    | DOUBLE                | double precision       |
| bidsiz | INT                   | integer                |
| ofrsiz | INT                   | integer                |
| mode   | INT                   | integer                |
| ex     | CHAR                  | character              |
| mmid   | SYMBOL                | enum                   |

我们按 `date(日期)`, `symbol(股票代码)` 进行分区，每天再根据 symbol 分为 100 个分区，每个分区大概 120 MB 左右。


## 四、数据导入导出测试

### 从 CSV 文件导入数据

DolphinDB 使用以下脚本导入

```c++
timer {
    for (fp in fps) {
        loadTextEx(db, `taq, `date`symbol, fp, ,schema)
        print now() + ": 已导入 " + fp
    }
}
```

4.2 GB 设备传感器记录小数据集共 `30,000,000` 条数据导入用时 `20 秒`, 平均速率 `1,500,000 条/秒`

270 GB 股票交易大数据集共 6,561,693,704 条数据（`TAQ20070801 - TAQ20070831` 23 个文件），导入用时 `38 分钟`


在 TimescaleDB 的导入中，由于 `timescaledb-parallel-copy` 工具不支持 CSV 首行为列名称，我们先用 `tail -n +2` 跳过 CSV 首行，再将文件流写入其标准输入。

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

4.2 GB 设备传感器记录小数据集共 `30,000,000` 条数据导入用时 `5 分钟 45 秒`, 平均速率 `87,000 条/秒`

270 GB 股票交易大数据集仅 `TAQ20070801, TAQ20070802, TAQ20070803, TAQ20070806, TAQ20070807` 五个文件（总大小 `70 GB`）所包含的 `16.7 亿` 条数据导入用时 `24 小时`，导入速率 `19400 条/秒`，预计将数据全部 `270 GB` 数据导入需要 `92 小时`。


##### 导入性能如下表所示

|            数据集             |          DolphinDB          |          TimescaleDB          | 导入性能 （DolphinDB / TimescaleDB） |    Δ    |
| :---------------------------: | :-------------------------: | :---------------------------: | :----------------------------------: | :-----: |
| 4.2 GB 设备传感器记录小数据集 |  1,500,000 条/秒, 共 20 秒  | 87,000 条/秒, 共 5 分钟 45 秒 |                17 倍                 | 5 分钟  |
|    270 GB 股票交易大数据集    | 2,900,000 条/秒, 共 38 分钟 |   20,000 条/秒, 共 92 小时    |                145 倍                | 91 小时 |

结果显示 DolphinDB 的导入速率远大于 TimescaleDB 的导入速率，数据量大时差距更加明显，而且在导入过程中可以观察到随着导入时间的增加，TimescaleDB 的导入速率不断下降，而 DolphinDB 保持稳定。

另，TimescaleDB 在导入小数据集后仍需花费 2 min 左右的时间建立索引。

### 导出数据为 CSV 文件

在 DolphinDB   中使用 `saveText((select * from readings), '/data/devices/readings_dump.csv')` 进行数据导出

在 TimescaleDB 中使用 `time psql -d test -c "\COPY (SELECT * FROM readings) TO /data/devices/devices_dump.csv DELIMITER ',' CSV"` 进行数据导出

##### 小数据集的导出性能如下表所示

|        DolphinDB         |          TimescaleDB          | 导出性能 （DolphinDB / TimescaleDB） |   Δ    |
| :----------------------: | :---------------------------: | :----------------------------------: | :----: |
| 1,070,000 条/秒    28 秒 | 322,580 条/秒    1 分钟 33 秒 |                 3 倍                 | 1 分钟 |


## 五、磁盘空间占用对比

导入数据后对 TimescaleDB 和 DolphinDB 数据库占用空间的分析如下表所示

|            数据集             | DolphinDB |             TimescaleDB              | 空间利用率 （DolphinDB / TimescaleDB） |   Δ    |
| :---------------------------: | :-------: | :----------------------------------: | :------------------------------------: | :----: |
| 4.2 GB 设备传感器记录小数据集 |  1.2 GB   | 7.4 GB (4.2 GB table + 3.1 GB index) |                  6 倍                  | 6.2 GB |
|    270 GB 股票交易大数据集    |   51 GB   |                864 GB                |                 17 倍                  | 813 GB |

DolphinDB 的空间利用率远大于 TimescaleDB，而且 TimescaleDB 中数据库占用的存储空间甚至大于原始 CSV 数据文件的大小，这主要有以下几方面的原因：

-   Timescale 只对比较大的字段进行自动压缩（TOAST），对数据表没有自动压缩的功能，即如果字段较小、每行较短而行数较多，则数据表不会进行自动压缩，若使用 ZFS 等压缩文件系统，则会显著影响查询性能；而 DolphinDB 默认采用 LZ4 格式的压缩。
-   TimescaleDB 使用 `SELECT create_hypertable('readings', 'time', chunk_time_interval => interval '1 day')` 将原始数据表转化为 hypertable 抽象表来为不同的数据分区提供统一的查询、操作接口，其底层使用 hyperchunk 来存储数据，经分析发现 hyperchunk 中对时序数据字段的索引共计 0.8 GB，对 device_id, ssid 两个字段建立的索引共计 2.3 GB
-   device_id, ssid, bssid 字段有大量的重复值，但 bssid 和 ssid 这两个字段表示设备连接的 WiFi 信息，在实际中因为数据的不确定性，因此不适合使用 enum 类型，只能以重复字符串的形式存储；而 DolphinDB 的 Symbol 类型可以根据实际数据动态适配，简单高效地解决了存储空间的问题。

## 六、查询测试
我们一共对比了以下八种类别的查询

-   点查询指定某一字段取值进行查询
-   范围查询针对单个或多个字段根据时间区间查询数据
-   精度查询针对不同的标签维度列进行数据聚合，实现高维或者低维的字段范围查询功能
-   聚合查询是指时序数据库有提供针对字段进行计数、平均值、求和、最大值、最小值、滑动平均值、标准差、归一等聚合类 API 支持
-   对比查询按照两个维度将表中某字段的内容重新整理为一张表格（第一个维度作为列，第二个维度作为行）
-   抽样查询指的是数据库提供数据采样的 API，可以为每一次查询手动指定采样方式进行数据的稀疏处理，防止查询时间范围太大数据量过载的问题
-   关联查询对不同的字段，在进行相同精度、相同的时间范围进行过滤查询的基础上，筛选出有关联关系的字段并进行分组
-   经典查询是实际业务中常用的查询

### 4.2 GB 设备传感器记录小数据集查询测试

对于小数据集的测试，我们先将数据表全部加载至内存中

DolphinDB   使用 `loadTable(memoryMode=true)` 加载至内存  
TimescaleDB 使用 `select pg_prewarm('_hyper_2_41_chunk')` 加载至 shared_buffers

| 样例 | DolphinDB 用时 (ms) | TimescaleDB 用时 (ms) | 性能比 ( DolphinDB / TimescaleDB ) | Δ (ms) |
| ---- | -------------- | ---------------- | ---------------------------------- | ---- |
| 1.  查询总记录数 | 2 | 908 | 454 | 906 |
| 2.  点查询：按设备 ID 查询记录数 | 3 | 10 | 3 | 7 |
| 3.  范围查询.单分区维度：查询某时间段内的所有记录 | 7 | 46 | 7 | 39 |
| 4.  范围查询.多分区维度: 查询某时间段内某些设备的所有记录 | 1 | 1 | 1 | 0 |
| 5.  范围查询.分区及非分区维度：查询某时间段内某些设备的特定记录 | 3 | 57 | 19 | 54 |
| 6.  精度查询：查询各设备在每 5 min 内的内存使用量最大、最小值之差 | 65 | 2017 | 31 | 1952 |
| 7.  聚合查询.单分区维度.max：设备电池最高温度 | 25 | 1595 | 64 | 1570 |
| 8.  聚合查询.多分区维度.avg：计算各时间段内设备电池平均温度 | 602 | 3409 | 6 | 2807 |
| 9.  对比查询：对比 10 个设备 24 小时中每个小时平均电量变化情况 | 2 | 19 | 10 | 17 |
| 10. 关联查询.等值连接：查询连接某个 WiFi 的所有设备的型号 | 73 | 5753 | 79 | 5680 |
| 11. 关联查询.左连接：列出所有的 WiFi，及其连接设备的型号、系统版本，并去除重复条目 | 5 | 16 | 3 | 11 |
| 12. 关联查询.笛卡尔积（cross join） | 261 | 3637 | 14 | 3376 |
| 13. 关联查询.全连接（full join） | 1815 | 9747 | 5 | 7932 |
| 14. 经典查询：计算某时间段内高负载高电量设备的内存大小 | 15 | 556 | 37 | 541 |
| 15. 经典查询：统计连接不同网络的设备的平均电量和最大、最小电量，并按平均电量降序排列 | 59 | 1770 | 30 | 1711 |
| 16. 经典查询：查找所有设备平均负载最高的时段，并按照负载降序排列、时间升序排列 | 32 | 1184 | 37 | 1152 |
| 17. 经典查询：计算各个时间段内某些设备的总负载，并将时段按总负载降序排列 | 3 | 11 | 4 | 8 |
| 18. 经典查询：查询充电设备的最近 20 条电池温度记录 | 2 | 0.3 | 15%                                | -1.7 |
| 19. 经典查询：未在充电的、电量小于 33% 的、平均 1 分钟内最高负载的 5 个设备 | 96 | 3021 | 31 | 2925 |
| 20. 经典查询：某两个型号的设备每小时最低电量的前 20 条数据 | 70 | 2205 | 32 | 2135 |

(具体查询语句见附录小数据集测试完整脚本)

对于抽样查询，TimescaleDB 中有 tablesample 子句对数据表进行抽样，参数是采样的比例，但只有两种抽样方式（system, bernoulli），system 方式按数据块进行取样，性能较好，但采样选中的块内的所有行都会被选中，随机性较差。bernoulli 对全表进行取样，但速度较慢。这两种取样方式不支持按某一个字段进行取样；而 DolphinDB 不支持全表取样，只支持按分区取样，由于实现方式不同，我们不进行性能对比。

对于插值查询，TimescaleDB (PostgreSQL) 无内置插值查询支持，需要上百行代码来实现，见 <https://wiki.postgresql.org/wiki/Linear_Interpolation> ；而 DolphinDB 支持 4 种插值方式，ffill 向后取非空值填充、bfill 向前去非空值填充、lfill 线性插值、nullFill 指定值填充。

对于对比查询，TimescaleDB 的对比查询功能由 PostgresQL 内置的 tablefunc 插件所提供的 crosstab() 函数实现，但是从样例查询中可以看出该函数有很大的局限性：  
第一，它需要用户手动硬编码第二个维度（行）中所有可能的取值和对应的数据类型，无法根据数据动态生成，非常繁琐，因此不能对动态数据或取值多的字段使用。  
第二，它只能根据 text 的类型维度进行整理，或者由其它类型的维度事先转换为 text 类型。数据量大时该转换操作效率低下且浪费空间。  
而 DolphinDB 原生支持 pivot by 语句，只需指定分类的两个维度即可自动整理。

对于关联查询，双时间连接（asof join）对于时间序列数据分析非常方便。DolphinDB 原生支持 asof join 而 PostgresQL 暂不支持 <https://github.com/timescale/timescaledb/issues/271>

使用 count(*) 查询总记录数时，TimescaleDB 会对全表进行扫描，效率极低。

### 270 GB 股票交易大数据集查询测试

在大数据量级的测试中我们不预先加载硬盘分区表至内存，查询测试的时间包含磁盘 I/O 的时间，为保证测试公平，每次启动程序测试前均通过 Linux 系统命令 `sync; echo 1,2,3 | tee /proc/sys/vm/drop_caches` 清除系统的页面缓存、目录项缓存和硬盘缓存，启动程序后依次执行所有测试样例一遍。

| 样例                                               | DolphinDB 用时 (ms) | TimescaleDB 用时 (ms) | 性能比 ( DolphinDB / TimescaleDB ) | Δ      |
| -------------------------------------------------- | -------------- | ---------------- | ---------------------------------- | ------ |
| 1.  点查询：按股票代码、时间查询 | 738 | 1174 | 2 | 436 |
| 2.  范围查询：查询某时间段内的某些股票的所有记录 | 1,023 | 15,448 | 15 | 14,425 |
| 3.  top 1000 + 排序: 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序 | 375 | 283 | 75% | -92 |
| 4.  聚合查询.单分区维度：查询每分钟的最大卖出报价、最小买入报价 | 184 | 1228 | 7 | 1044 |
| 5.  聚合查询.多分区维度 + 排序：按股票代码分组查询每分钟的买入报价标准差和买入数量总和 | 62 | 233 | 4 | 171 |
| 6.  经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价] | 16 | 301 | 19 | 285 |
| 7.  经典查询：按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，查询 (各个股票 每分钟) [平均变化幅度] | 16,830 | 193,321 | 11 | 176,491 |
| 8.  经典查询：计算 某天 (每个股票 每分钟) 最大卖出报价与最小买入报价之差 | 8102 | 180,687 | 22 | 172,585 |
| 9.  经典查询：按 [股票代码、日期段、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价 | 63 | 4737 | 75 | 4674 |
| 10. 经典查询：按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价 | 16,418 | 348,815 | 21 | 332,397 |
| 11. 经典查询：计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序 | 4290 | 175,054 | 41 | 170,764 |

(具体查询语句见附录大数据集测试完整脚本)

## 七、附录

-   CSV 数据格式预览（取前 20 行）

| 数据     | 文件                         |
| -------- | ---------------------------- |
| devices  | [devices.csv](devices.csv)   |
| readings | [readings.csv](readings.csv) |
| TAQ      | [TAQ.csv](TAQ.csv)           |

-   DolphinDB

| 脚本                 | 文件                                                 |
| -------------------- | ---------------------------------------------------- |
| 安装、配置、启动脚本 | [test_dolphindb.sh](test_dolphindb.sh)               |
| 配置文件             | [dolphindb.cfg](dolphindb.cfg)                       |
| 小数据集测试完整脚本 | [test_dolphindb_small.txt](test_dolphindb_small.txt) |
| 大数据集测试完整脚本 | [test_dolphindb_big.txt](test_dolphindb_big.txt)     |


-   TimescaleDB

| 脚本                          | 文件                                                     |
| ----------------------------- | -------------------------------------------------------- |
| 安装、配置、启动脚本          | [test_timescaledb.sh](test_timescaledb.sh)               |
| 小数据集测试完整脚本          | [test_timescaledb_small.sql](test_timescaledb_small.sql) |
| 大数据集测试完整脚本          | [test_timescaledb_big.sql](test_timescaledb_big.sql)     |
| PostgresQL 修改配置           | [postgresql_test.conf](postgresql_test.conf)             |
| PostgresQL 完整配置           | [postgresql.conf](postgresql.conf)                       |
| PostgresQL 权限配置           | [pg_hba.conf](pg_hba.conf)                               |
| 股票代码所有可能值            | [symbols.txt](symbols.txt)                               |
| 创建 Symbol 枚举类型 SQL 语句 | [make_symbol_enum.sql](make_symbol_enum.sql)             |
| 生成 Symbol 枚举类型脚本      | [make_symbol_enum.coffee](make_symbol_enum.coffee)       |

-   测试结果处理脚本

    [REPL.coffee](REPL.coffee)