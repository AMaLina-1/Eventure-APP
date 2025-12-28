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
        serno = input[:serno]
        user_likes = input[:user_likes]
        Success(serno:, user_likes:)
      rescue StandardError
        Failure(input.errors.values.join('; '))
      end

      def request_like(input)
        sent_hash = { serno: input[:serno], user_likes: input[:user_likes] }
        result = Gateway::Api.new(Eventure::App.config)
                             .like_activity(sent_hash)
        puts 'result: ', result

        result.success? ? Success(result.payload) : Failure(result.message)
      rescue StandardError => e
        puts e.inspect
        puts e.backtrace
        Failure('Cannot like/dislike an activity right now; please try again later')
      end

      def reify_like(liked_json)
        like_info = Representer::ActivityLike.new(OpenStruct.new)
                                             .from_json(liked_json)
        Success(like_info)
      rescue StandardError
        Failure('Error in liked/disliked activity -- please try again')
      end
    end
  end
end
