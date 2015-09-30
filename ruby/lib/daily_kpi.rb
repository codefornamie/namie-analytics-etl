require 'action_mailer'

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.prepend_view_path File.expand_path(File.dirname(__FILE__)) + '/../templates'
ActionMailer::Base.smtp_settings = {
    :address => 'localhost'
}

module DailyKpi
  class Mail < ActionMailer::Base
    @@app_config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')

    def sendMail
      mysql = Mysql2::Client.new(host: @@app_config['mysql']['host'],
                                 username: @@app_config['mysql']['user'],
                                 password: @@app_config['mysql']['password'],
                                 database: @@app_config['mysql']['database'])
      sql = <<-EOF
        SELECT target_date, all_count, day30_active, day14_active, day7_active, day3_active, day1_active
        FROM mdm_active_summary
        ORDER BY target_date DESC
        LIMIT 7
      EOF
      @active_summary = mysql.query(sql)
      @admin_name = @@app_config['daily_kpi']['mail']['admin_name']
      @admin_mail = @@app_config['daily_kpi']['mail']['admin_mail']

      gal = GoogleAnalyticsLegato.new
      @one_day_article_ranking = gal.one_day_article_ranking

      mail(from: @@app_config['daily_kpi']['mail']['from'],
          to: @@app_config['daily_kpi']['mail']['send_to'],
          subject: "【Code for Namie】デイリーKPI進捗(#{(DateTime.now).strftime('%Y/%m/%d')})") do |format|
        format.html
      end
    end
  end

  module ActiveSummary
    @@app_config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')

    def self.update(target_date)
      target_date_slash = target_date.gsub(/(\d{4})(\d{2})(\d{2})/, "\\1/\\2/\\3")
      mysql = Mysql2::Client.new(host: @@app_config['mysql']['host'],
                                 username: @@app_config['mysql']['user'],
                                 password: @@app_config['mysql']['password'],
                                 database: @@app_config['mysql']['database'])
      days = [30, 14, 7, 3, 1]
      active_summary = Hash.new

      sql = <<-"EOF"
          SELECT COUNT(*) AS count
          FROM mdm_logs
          WHERE extracted_date = '#{target_date_slash}'
      EOF
      active_summary["all"] = mysql.query(sql).first['count']

      days.each do |day|
        target_past_date = (Date.parse(target_date_slash) - day).strftime('%Y/%m/%d')
        sql = <<-"EOF"
          SELECT COUNT(*) AS count
          FROM mdm_logs
          WHERE extracted_date = '#{target_date_slash}'
          AND device_updated_at >= '#{target_past_date}'
        EOF
        active_summary[day] = mysql.query(sql).first['count']
      end

      sql = <<-"EOF"
        INSERT INTO mdm_active_summary (
          target_date,
          all_count,
          day30_active,
          day14_active,
          day7_active,
          day3_active,
          day1_active
        ) VALUES (
          '#{target_date_slash}',
          #{active_summary['all']},
          #{active_summary[30]},
          #{active_summary[14]},
          #{active_summary[7]},
          #{active_summary[3]},
          #{active_summary[1]}
        ) ON DUPLICATE KEY UPDATE
        target_date = '#{target_date_slash}'
      EOF
      mysql.query(sql)
    end
  end
end
