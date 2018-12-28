require 'sidekiq/web'
require 'sidekiq/results/version'
require 'sidekiq/results/result_set'
require 'sidekiq/results/middleware'
require 'sidekiq/results/web_extension'

module Sidekiq

  def self.results_max_count=(value)
    @results_max_count = value
  end

  def self.results_max_count
    return false if @results_max_count === false
    @results_max_count ||= 1000
  end

  module Results
    LIST_KEY = 'sidekiq:results'
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Results::Middleware
  end
end

if defined?(Sidekiq::Web)
  Sidekiq::Web.register Sidekiq::Results::WebExtension
  Sidekiq::Web.tabs['Results'] = 'results'
end
