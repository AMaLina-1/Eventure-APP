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
        puts 'enter service'
        result = Gateway::Api.new(Eventure::App.config).fetch_api_activities
        puts 'result'
        puts result.class
        puts result.payload.class
        puts result.payload['status']
        puts result['message']
        puts result['message'][:msg]
        puts result  # {"status":"processing","message":{"request_id":-1897440702705942571,"msg":"Processing the fetching request..."}}
        input[:response] = result[:response]
        if result[:response].success?
          Success(input)
        else
          Representer::HttpResponse.new(OpenStruct.new)
          .from_json(result[:response].payload)
          .then { |error| Failure(error.message) }
        end
        # result.success? ? Success(result.payload) : Failure(result.message)
      rescue StandardError => e
        puts e.inspect
        puts e.backtrace
        Failure('Cannot fetch API activities right now; please try again later')
      end

      def reify_activity(input)
        puts input[:response]
        puts input[:response].payload
        # puts result_json
        unless input[:response].processing?
          msg = Representer::FetchApiData.new(OpenStruct.new)
          .from_json(input[:response].payload)
          .then { |value| input[:msg] = value }
        end
        puts "msg: #{msg}"
        Success(input)
      rescue StandardError
        Failure('Error in the fetching API activities -- please try again')
      end
    end
  end
end
