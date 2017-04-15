source "https://rubygems.org"

gemspec

gem "transpec"

# Omitted from CI Environment
group :no_ci do
  gem "rb-fsevent" # Mac OS X
  gem "rb-inotify" # Linux
  gem "pry"

  gem "yard"
  gem "redcarpet"
end
