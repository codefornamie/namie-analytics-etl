require 'google/api_client'
require 'oauth2'
require 'legato'
require 'active_support/all'

class GoogleAnalyticsLegato
  def initialize
    ga_config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')['google_analytics']

    scope="https://www.googleapis.com/auth/analytics.readonly"
    client = Google::APIClient.new(
      application_name: ga_config['api_client']['app_name'],
      appliversion_version: ga_config['api_client']['app_version']
    )
    key = Google::APIClient::PKCS12.load_key(ga_config['api_client']['key_path'], ga_config['api_client']['key_secret'])
    service_account = Google::APIClient::JWTAsserter.new(ga_config['api_client']['service_account_email'], scope, key)
    client.authorization = service_account.authorize
    oauth_client = OAuth2::Client.new("", "", {
      authorize_url: 'https://accounts.google.com/o/oauth2/auth',
      token_url: 'https://accounts.google.com/o/oauth2/token'
    })
    token = OAuth2::AccessToken.new(oauth_client, client.authorization.access_token, expires_in: 3600)
    @user = Legato::User.new(token)
  end

  def one_day_article_ranking
    profile = @user.profiles.first
    options = {start_date: 1.days.ago, end_date: Time.now, sort: "-totalevents", limit: 10}
    EventPageviewModel.exclude_category_not_set.match_action_article_reference.exclude_label_undefined.results(profile, options)
  end

  class EventPageviewModel
    extend Legato::Model

    metrics :pageviews, :sessions, :totalevents
    dimensions :event_label, :event_category, :event_action

    # イベントアクションが「記事参照」にマッチ
    filter :match_action_article_reference, &lambda { matches(:event_action, '記事参照') }
    # イベントカテゴリがセットされていないものを除外
    filter :exclude_category_not_set, &lambda { does_not_match(:event_category, '(not set)') }
    # イベントラベルがundefinedのものを除外
    filter :exclude_label_undefined, &lambda { does_not_contain(:event_label, 'undefined') }
  end
end
