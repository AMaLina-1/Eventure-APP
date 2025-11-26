# frozen_string_literal: true

require 'http'
require 'json'

module Eventure
  module Gateway
    class Api
      def initialize(config)
        @config  = config
        @request = Request.new(@config)
      end

      def alive?
        @request.get_root.success?
      end

      # GET /api/v1/activities
      def activities_list
        @request.activities_list
      end

      # POST /api/v1/filter  with { filters: {...} }
      def filtered_activities(filters)
        @request.filtered_activities(filters)
      end

      # POST /api/v1/activities/like with { serno: ... }
      def like_activity(serno)
        @request.like_activity(serno)
      end

      # GET /api/v1/cities
      def cities_list
        @request.cities_list
      end

      # GET /api/v1/districts
      def districts_list
        @request.districts_list
      end

      # GET /api/v1/tags
      def tags_list
        @request.tags_list
      end

      # 實際送 HTTP 的層
      class Request
        def initialize(config)
          @api_host = config.API_HOST
          @api_root = File.join(@api_host, 'api', 'v1')
        end

        def api_root
          call_api(:get, [])
        end

        def activities_list
          call_api(:get, ['activities'])
        end

        def filtered_activities(filters)
          body = { filters: filters }.to_json
          call_api(:post, ['filter'], {}, body)
        end

        def like_activity(serno)
          body = { serno: serno }.to_json
          call_api(:post, %w[activities like], {}, body)
        end

        def cities_list
          call_api(:get, ['cities'])
        end

        def districts_list
          call_api(:get, ['districts'])
        end

        def tags_list
          call_api(:get, ['tags'])
        end

        private

        def params_str(params)
          return '' if params.empty?

          '?' + params.map { |key, value| "#{key}=#{value}" }.join('&')
        end

        # method: :get / :post
        # resources: ['activities'], ['filter'] ...
        # params: query string 用（本專案目前用不到可以都 {}）
        # body: JSON 字串，POST 時用
        def call_api(method, resources = [], params = {}, body = nil)
          api_path = resources.empty? ? @api_host : @api_root
          url      = ([api_path] + resources).join('/') + params_str(params)

          http = HTTP.headers(
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          )

          response =
            if body
              http.public_send(method, url, body: body)
            else
              http.public_send(method, url)
            end

          Response.new(response)
        rescue StandardError
          raise "Invalid URL request: #{url}"
        end
      end

      # 統一包裝 HTTP response
      class Response < SimpleDelegator
        SUCCESS_CODES = (200..299)

        def success?
          code.between?(SUCCESS_CODES.first, SUCCESS_CODES.last)
        end

        def payload
          body.to_s
        end
      end
    end
  end
end
