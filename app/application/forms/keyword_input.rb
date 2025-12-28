# frozen_string_literal: true

require 'dry-validation'

module Eventure
  module Forms
    # Form validation for search box input
    class KeywordInput < Dry::Validation::Contract
      VALID_CHAR = /^[\p{Han}\p{Latin}\d\s.-]+$/

      params do
        required(:keyword).maybe(:string)
      end

      rule(:keyword) do
        key.failure('Keywords cannot contain special characters') if value && !VALID_CHAR.match?(value)
      end
    end
  end
end
