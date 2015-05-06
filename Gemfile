require File.expand_path("../culture/sync", __FILE__)
source "https://rubygems.org"

gemspec #de development_group: :gem_build_tools

group :development do
  gem "pry"
end

group :test do
  gem "dotenv", "~> 2.0"
  gem "nenv"
end

group :gem_build_tools do
  gem "rake"
end

Celluloid::Sync.gems(self)
