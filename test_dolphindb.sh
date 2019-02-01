# 启动 DolphinDB
cd /data/DolphinDB/server
chmod +x dolphindb
nohup ./dolphindb -console 0 &
tail -f ./dolphindb.log

ps -efl | grep dolphindb

# 停止 DolphinDB
pkill dolphindb


# 查看空间占用
du -sh /data/devices/db

du -sh /data/TAQ/db

