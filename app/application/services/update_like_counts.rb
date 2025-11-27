# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Transaction to update like counts (input: serno, user_likes)
    class UpdateLikeCounts
      include Dry::Transaction

      step :validate_like_serno
      step :request_like
      step :reify_like

      private

      def validate_like_serno(input)
        if input.success?
          serno = input[:serno]
          user_likes = input[:user_likes]
          Success(serno:, user_likes:)
        else
          Failure(input.errors.values.join('; '))
        end
      end

      def request_like(input)
        result = Gateway::Api.new(Eventure::App.config)
          .like_activities(input)

        result.success? ? Success(result.payload) : Failure(result.message)
      rescue StandardError => e
        puts e.inspect
        puts e.backtrace
        Failure('Cannot like/dislike an activity right now; please try again later')
      end

      def reify_like(liked_json)
        Representer::ActivityLike.new(OpenStruct.new)
          .from_json(liked_json)
          .then { |liked| Success(liked) }
      rescue StandardError
        Failure('Error in liked/disliked activity -- please try again')
      end
    end
  end
end
