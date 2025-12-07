# frozen_string_literal: true

require 'http'
require 'json'

module Eventure
  module Gateway
    # Infrastructure to call Eventure API
    class Api
      def initialize(config)
        @config  = config
        @request = Request.new(@config)
      end

      def alive?
        @request.api_root.success?
      end

      def fetch_api_activities
        @request.fetch_api_activities
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
      def like_activity(sent_hash)
        @request.like_activity(sent_hash)
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

      # GET /api/v1/activities?keyword=...
      # Provide a gateway-level helper so callers can request server-side search
      def search_activities(keyword)
        @request.search_activities(keyword)
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

        def fetch_api_activities
          call_api(:post, [])
        end

        def activities_list
          call_api(:get, ['activities'])
        end

        def filtered_activities(filters)
          body = filters.to_json
          call_api(:post, ['filter'], {}, body)
        end

        def like_activity(sent_hash)
          body = sent_hash.to_json
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

        def search_activities(keyword)
          params = {}
          params[:keyword] = keyword if keyword && !keyword.to_s.empty?
          call_api(:get, ['activities'], params)
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
          puts "HTTP RESPONSE BODY: #{url}"
          puts 'body:' + body.to_s
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
          # puts "HTTP RESPONSE BODY: #{response.body.to_s}"
          puts response.status
          # puts response.body
          Response.new(response)
        rescue StandardError
          raise "Invalid URL request: #{url}"
        end
      end

      # 統一包裝 HTTP response
      class Response < SimpleDelegator
        NotFound = Class.new(StandardError)
        SUCCESS_CODES = (200..299)

        def success?
          code.between?(SUCCESS_CODES.first, SUCCESS_CODES.last)
        end

        def message
          payload['message']
        end

        def payload
          body.to_s
          #   JSON.parse(body.to_s)
          # rescue JSON::ParserError
          #   {}
        end
      end
    end
  end
end
