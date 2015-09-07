#!/bin/sh

# YYYYMMDD形式で指定した引数の日付のなみえアプリの利用データをS3からローカルのMySQLにロードする
# 引数を省略すると前日分を処理する
# このスクリプトは冪等になっている

#設定ファイル読み込み
. ./config.conf

#引数から日付文字列をとってくる。引数が無ければ1日前を指定
TARGET_DATE=$1
if [ -z "${TARGET_DATE}" ];then
    TARGET_DATE=`date -d '1 day ago' '+%Y%m%d'`
fi
echo $TARGET_DATE

#s3データをsyncしてくるディレクトリを作成
mkdir -p ../../s3_raw/namie-logs/fluentd_logs/nginx.access/$TARGET_DATE/

#パース先のディレクトリを作成
mkdir -p ../../s3_parsed/namie-logs/fluentd_logs/nginx.access/$TARGET_DATE/

#S3からローカルにデータをsync
aws s3 sync s3://namie-logs/fluentd_logs/nginx.access/$TARGET_DATE/ ../../s3_raw/namie-logs/fluentd_logs/nginx.access/$TARGET_DATE/
echo "download from s3"

#ローカルのディレクトリから解凍するディレクトリにファイルをコピー
rsync -avz ../../s3_raw/namie-logs/fluentd_logs/nginx.access/$TARGET_DATE/ ../../s3_parsed/namie-logs/fluentd_logs/nginx.access/$TARGET_DATE/

#ディレクトリを移動
pushd ../../s3_parsed/namie-logs/fluentd_logs/nginx.access/$TARGET_DATE/

#解答ディレクトリ先でファイルを解凍
find . -name '*.gz' | xargs gunzip

#タイムスタンプとユーザーIDの文字列にパースし、一時ディレクトリにCSVファイルを作成する
find .  | grep -v '.gz' | xargs perl -wnl -e '/^(\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d)\+\d\d:\d\d\t+.*\%27(.*)%40(namie\-tablet\.jp)/ and print "$1,$2\@$3"' > /tmp/logins.csv

#一時ファイルのCSVの内容をMySQLのnamie_analyticsデータベースのlogisテーブルにロードする 
mysql -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e 'LOAD DATA LOCAL INFILE "/tmp/logins.csv" INTO TABLE logins FIELDS TERMINATED BY ","'
echo "load to mysql"

#元のディレクトリに戻る
popd

