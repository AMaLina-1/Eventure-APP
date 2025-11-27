# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Transaction to filter activities (input: filters)
    class FilteredActivities
      include Dry::Transaction

      step :validate_filter
      step :request_activity
      step :reify_activity

      private

      def validate_filter(input)
        if input.success?
          tags = input[:filters][:tag]
          city = input[:filters][:city]
          districts = input[:filters][:districts]
          dates = [input[:filters][:start_date], input[:filters][:end_date]]
          # end_date = input[:filters][:end_date]
          Success(tags:, city:, districts:, dates:)
        else
          Failure(input.errors.values.join('; '))
        end
      end

      def request_activity(input)
        result = Gateway::Api.new(Eventure::App.config)
          .filtered_activities(input)

        result.success? ? Success(result.payload) : Failure(result.message)
      rescue StandardError => e
        puts e.inspect
        puts e.backtrace
        Failure('Cannot find filtered activities right now; please try again later')
      end

      def reify_activity(activity_json)
        Representer::ActivityList.new(OpenStruct.new)
          .from_json(activity_json)
          .then { |activity| Success(activity) }
      rescue StandardError
        Failure('Error in the filtered activities -- please try again')
      end
    end
  end
end
