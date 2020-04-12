require "google_drive"

session = GoogleDrive::Session.from_config("config.json")

# スプレッドシートを指定
sheets = session.spreadsheet_by_key("1mC6uGmMNfoT2JUwMtEdfMZSc8GnJdWgXMBp7VbqhKh0").worksheets[0]

# スプレッドシートへの書き込み
sheets[1,1] = "hello world!!"

# シートの保存
sheets.save