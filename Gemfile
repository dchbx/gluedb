source 'https://rubygems.org'

gem 'rake', '10.4.2'
gem 'rails', '4.0.0'

gem "mongoid", "~> 3.1.7"
gem "origin", "~> 1.1.0"
gem "aasm", "~> 3.0.26"
gem "nokogiri", "~> 1.6.8.1"
gem "bunny", '1.4.1'
gem 'amq-protocol', '2.0.1'
gem 'jquery-rails', '3.1.3'
gem 'jquery-ui-rails', '5.0.5'
gem 'virtus', "~> 1.0.5"
gem 'spreadsheet', '1.0.4'
gem 'ruby-ole', '1.2.11.7'
gem 'openhbx_cv2', git: "https://github.com/dchbx/openhbx_cv2.git"
gem "interactor", "~> 3.1.0"
gem 'interactor-rails', '2.0.2'
gem "psych", "2.0.5"

group :development do
  gem 'capistrano', '2.15.4'
  gem 'yard', '0.8.7.6'
end

group 'development', 'test' do
  gem 'rspec', '3.3.0'
  gem 'rspec-core', '3.3.2'
end

group :development, :assets, :test do
  gem 'libv8', "~> 3.16.14.17"
  gem 'therubyracer', '0.12.2', :platforms => :ruby
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'less-rails-bootstrap', '3.2.0'
  gem 'designmodo-flatuipro-rails', git: "https://github.com/dchbx/designmodo-flatuipro-rails.git"
end

group :development, :assets do
  gem 'uglifier', '~> 3.0.4'
  gem 'font-awesome-rails', '4.2.0.0'
  gem "rails_best_practices", "~> 1.17.0"
end

group :development, :test do
  gem "parallel_tests", "~> 2.13.0"
end

group :test do
  gem 'test-unit', "~> 3.2.3"
  gem 'mongoid-rspec', "~> 1.13.0"
  gem 'rspec-rails', '3.3.3'
  gem 'rspec-collection_matchers', '1.1.2'
  gem 'capybara', '2.4.4'
  gem 'factory_girl_rails', '4.5.0'
  gem 'factory_girl', '4.5.0'
  gem 'database_cleaner', '1.5.3'
  gem 'ci_reporter', '2.0.0'
  gem 'savon', '~> 2.7.0'
  gem 'simplecov', "~> 0.12.0", :require => false
  gem 'rspec_junit_formatter', "~> 0.2.3"
end

group :production do
  gem 'unicorn', '4.8.2'
  gem 'eye', '0.6.4'
  gem 'celluloid', '0.15.2'
  gem 'nio4r', '1.1.1'
end

gem 'ruby-progressbar', '~> 1.10.0'
gem "haml", "~> 4.0.7"
gem 'kaminari', '0.16.3'
gem 'bootstrap-kaminari-views', '0.0.5'
gem "pd_x12", "~> 1.5.4"
gem 'carrierwave-mongoid', '0.7.1', :require => 'carrierwave/mongoid'
gem 'devise', '3.3.0'
gem "rsec", "~> 0.4.2"
gem "mongoid_auto_increment", '0.1.2'
gem 'american_date', '1.1.0'
gem 'cancancan', '~> 1.15.0'
gem 'oj', "~> 2.18.0"
gem 'roo', '2.1.0'
gem 'bh', "~> 1.3.6"
gem 'nokogiri-happymapper', "~> 0.5.9", :require => 'happymapper'
# Upgraded prawn to fix inverted text issue, Ref: https://github.com/prawnpdf/prawn-templates/issues/19
gem 'prawn', '~> 2.2'
gem 'prawn-templates', '~> 0.1.2'
gem 'forkr', '1.0.2'
gem 'edi_codec', git: "https://github.com/dchbx/edi_codec.git"
gem 'ibsciss-middleware', git: "https://github.com/dchbx/ruby-middleware.git", :require => "middleware"
gem 'rgl', '0.5.2'
gem 'aws-sdk', "~> 2.2.4"

# configuration support

gem "config", '1.0.0'