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
        Success(filters: input[:filters])
      rescue StandardError
        Failure(input.errors.values.join('; '))
      end

      def request_activity(input)
        result = Gateway::Api.new(Eventure::App.config)
          .filtered_activities(filters: input[:filters])

        result.success? ? Success(result.payload) : Failure(result.message)
      rescue StandardError => e
        puts e.inspect
        puts e.backtrace
        Failure('Cannot find filtered activities right now; please try again later')
      end

      def reify_activity(activity_json)
        activities = Representer::ActivityList.new(OpenStruct.new(activities: []))
          .from_json(activity_json)
        Success(activities)
      rescue StandardError
        Failure('Error in the filtered activities -- please try again')
      end
    end
  end
end
