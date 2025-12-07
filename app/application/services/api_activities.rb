# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Service for activities
    class ApiActivities
      include Dry::Transaction

      step :request_activity
      step :reify_activity

      def request_activity()
        result = Gateway::Api.new(Eventure::App.config).fetch_api_activities()

        result.success? ? Success(result.payload) : Failure(result.message)
      rescue StandardError => e
        puts e.inspect
        puts e.backtrace
        Failure('Cannot fetch API activities right now; please try again later')
      end

      def reify_activity(result_json)
        puts result_json
        msg = Representer::FetchApiData.new(OpenStruct.new)
          .from_json(result_json)
        puts "msg: #{msg}"
        Success(msg)
      rescue StandardError
        Failure('Error in the fetching API activities -- please try again')
      end
    end
  end
end
