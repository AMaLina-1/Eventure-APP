# frozen_string_literal: true

require 'http'

module Eventure
  module Initializer
    def self.trigger_fetch_activities
      Thread.new do
        sleep 2 # 等待伺服器完全啟動
        
        begin
          api_host = Eventure::App.config.API_HOST
          puts "Triggering initial fetch from #{api_host}..."
          
          response = HTTP.post("#{api_host}/")
          
          if response.status.success?
            puts "✓ Successfully triggered activity fetch"
            puts "Response: #{response.body}"
          else
            puts "✗ Failed to trigger fetch: #{response.status}"
          end
        rescue StandardError => e
          puts "✗ Error triggering fetch: #{e.message}"
        end
      end
    end
  end
end
