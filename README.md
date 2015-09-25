# namie-analytics-etl
浪江タブレット事業の各種ログデータをMySQLに載せるETLプログラム

## このプログラムについて

浪江タブレット事業で集めているログを統合して分析する環境を作るためのETLを行うプログラムです。

* S3にあるnginxのアクセスログ
* MDM(ソフトバンクの端末管理サービス)の端末一覧情報
* 端末キッティング時のマスタ情報(配送日、利用開始日、利用者の避難先都道府県など)

## 対応環境

Amazon Linux Microインスタンス

## インストール

* AWSのcredential設定を済ませておく
```
aws configure
```

## 使い方

* ruby/config.ymlをconfig.sample.ymlから作成

```
cp ruby/config.sample.yml ruby/config.yml
```

* sh/config.confをconfig.sampl.confから作成

```
cp sh/config.sample.conf sh/config.conf
```

* 上記設定ファイルの該当箇所を埋める

* 依存ライブラリの設定

```
cd ruby
bundle install
```

### 実行方法

#### S3ログ

S3にあるnginxのログをパースしてgoogle appsのメールアドレス部分を取り出してMySQLにロードします。

* 引数なしで実行すると前日分を処理する
```
cd sh
./extract_load_s3.sh
```

* `YYYYMMDD`形式で年月日を渡すとその日ぶんを処理する

```
./extract_load_s3.sh 20150901
```

#### MDMログ

MDMの端末一覧のCSVを必要な部分だけパースしてMySQLにロードします。

[mdm_scraper](https://github.com/codefornamie/mdm_scraper)が事前に実行されていてCSVがS3上にあることを前提としています。

* 引数なしで実行すると当日分を処理する
```
cd ruby
bundle exec rake download_csv insert_mysql
```

* `date=YYYYMMDD`形式で年月日を渡すとその日ぶんを処理する
```
cd ruby
bundle exec rake download_csv insert_mysql date=20150901
```

#### アクティブ率の計算

MDMのアップデート時間から、アクティブな端末数とその割合を計算します。

* 引数なしで実行すると当日分を処理する
```
cd ruby
bundle exec rake update_active_summary
```

* `date=YYYYMMDD`形式で年月日を渡すとその日ぶんを処理する
```
cd ruby
bundle exec rake update_active_summary date=20150901
```

#### 日次メールの送信

各種メトリックスをまとめたものをメールで送信します。

* MDMのログから集計したアクティブ率
* GoogleAnalyticsAPIから集計した記事別アクセス数ランキング

```
cd ruby
bundle exec rake daily_kpi_mail
```

### cronからの実行

crontab
```
0 0 * * * /var/apps/etl/sh/extract_load_s3.sh
5 0 * * * cd /var/apps/etl/ruby; /home/ec2-user/bin/bundle exec rake download_csv insert_mysql
0 23 * * * cd /var/apps/etl/ruby; /home/ec2-user/bin/bundle exec rake update_active_summary daily_kpi_mail
```
pathは自分のものに置き換えてください。

## ライセンス

Apache 2.0
