require 'selenium-webdriver'
require 'dotenv/load'
require 'google_drive'
require 'csv'
require 'active_support'
require 'active_support/core_ext/numeric/time.rb'
require 'active_support/core_ext/string/filters.rb'
require 'fileutils'

driver = Selenium::WebDriver.for :chrome

url = 'https://analytics.twitter.com/user/TetsuKinomura/tweets'
username = ENV['TWITTER_USERNAME']
password = ENV['TWITTER_PASSWORD']

driver.get url

# 待たないとエラーが起こる
sleep 1

# ユーザー名を入力
username_field = driver.find_element(:xpath, "//*[@id='react-root']/div/div/div[2]/main/div/div/form/div/div[1]/label/div/div[2]/div/input")
username_field.send_keys username

# パスワードを入力
password_field = driver.find_element(:xpath, "//*[@id='react-root']/div/div/div[2]/main/div/div/form/div/div[2]/label/div/div[2]/div/input")
password_field.send_keys password

# ログインボタンをクリック
login_button = driver.find_element(:xpath, "//*[@id='react-root']/div/div/div[2]/main/div/div/form/div/div[3]/div/div")
login_button.click
sleep 5

# 28日間から7日間に変更
driver.find_element(:xpath, "//*[@id='daterange-button']").click
sleep 1
driver.find_element(:xpath, '/html/body/div[4]/div[4]/ul/li[1]').click
sleep 1

# エクスポート
driver.find_element(:xpath, "//*[@id='export']/button").click
sleep 1
driver.find_element(:xpath, "//*[@id='export']/ul/li[1]/button").click

sleep 20

# tweet_activity_metrics配下のファイルを取得
file_name = ''
Dir.foreach('tweet_activity_metrics') do |item|
  next unless item.include?('.csv')

  file_name = "tweet_activity_metrics/#{item}"
end

data_list = CSV.read(file_name).map { |data| data.slice(0..21) }

key_array = data_list[0]

value_arrays = data_list.drop(1)

unnecessary_keys = [
  'engagements',
  'replies',
  'hashtag clicks',
  'permalink clicks',
  'app opens',
  'app installs',
  'email tweet',
  'dial phone'
]

value_arrays.map! do |value_array|
  key_array
    .zip(value_array)
    .to_h
    .reject! do |key, _value|
      unnecessary_keys.include?(key)
    end
end

# UTCをJSTに変換
# ハッシュタグを抜きだす
# テキストの長さを調整
value_arrays.map do |each_array|
  each_array['time'] = ActiveSupport::TimeZone.new('Tokyo')
                                              .parse(each_array['time'])
                                              .to_s
  each_array['hash tag'] = each_array['Tweet text'][/#.*\s/]
  each_array['Tweet text'] = each_array['Tweet text'].truncate(20)
end

# keys = value_arrays[0].keys
values = value_arrays.map(&:values).reverse

session = GoogleDrive::Session.from_config("config.json")

# スプレッドシートを指定
sheets = session.spreadsheet_by_key("1mC6uGmMNfoT2JUwMtEdfMZSc8GnJdWgXMBp7VbqhKh0").worksheets[0]

rows = sheets.rows

# スプレッドシートへの書き込み
sheets.update_cells(rows.length + 1, 1, values)

# シートの保存
sheets.save

# ファイルを削除
FileUtils.rm(file_name)