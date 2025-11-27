# frozen_string_literal: true

require 'dry/transaction'
require 'json'

module Eventure
  module Service
    # 根據 keyword 呼叫 api-eventure 搜尋活動
    class SearchedActivities
      include Dry::Transaction

      step :validate_input
      step :request_activities
      step :reify_activities

      private

      # input 期望是一個 Hash，例如 { keyword: params['keyword'] }
      def validate_input(input)
        form_result = Eventure::Forms::KeywordInput.new.call(input)

        if form_result.failure?
          Failure(form_result.errors.to_h[:keyword].join(', '))
        else
          keyword = form_result[:keyword].to_s.strip
          Success(keyword:)
        end
      end

      def request_activities(input)
        keyword = input[:keyword]

        api = Eventure::Gateway::Api.new(Eventure::App.config)

        # Prefer calling API search endpoint if available
        if api.respond_to?(:search_activities)
          begin
            result = api.search_activities(keyword)
            return Success(result.payload) if result.success?
          rescue StandardError
            # fallthrough to local filtering
          end
        end

        # Fallback: fetch full activities list and filter locally by keyword
        list_res = api.activities_list
        return Failure('Cannot search activities now; please try again later') unless list_res.success?

        begin
          parsed = JSON.parse(list_res.payload)
          activities = Array(parsed['activities'] || parsed['data'] || [])
          filtered = activities.select do |a|
            txt = [a['name'], a['detail'], a['organizer']].compact.join(' ')
            txt.include?(keyword)
          end

          # Representer expects a JSON string like { "activities": [...] }
          Success({ 'activities' => filtered }.to_json)
        rescue StandardError
          Failure('Error parsing activities for search')
        end
      rescue StandardError
        Failure('Cannot search activities now; please try again later')
      end

      def reify_activities(activities_json)
        activities_list =
          Eventure::Representer::ActivityList
          .new(OpenStruct.new)
          .from_json(activities_json)

        Success(activities_list)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error,
                                        message: 'Error in search result -- please try again'))
      end
    end
  end
end
