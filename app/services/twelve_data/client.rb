require "net/http"
require "json"

module TwelveData
  class Client
    Response = Data.define(:status, :http_status, :credits_used, :credits_left, :error_code, :payload, :retry_after)
    HISTORY_SIZE = 5000

    def initialize(key: -> { Rails.application.credentials.data_api_key }, transport: nil)
      @key = key
      @transport = transport || method(:request)
    end

    def time_series(symbol:, interval:, outputsize: 8)
      validate(symbol, interval)
      raise ArgumentError, "Unsupported outputsize" unless [ 8, HISTORY_SIZE ].include?(outputsize)
      # A full history window is roughly 550 KB; incremental requests stay small.
      fetch("time_series", max_bytes: outputsize == 8 ? 262_144 : 1_048_576,
        symbol: symbol, interval: interval, timezone: "UTC", outputsize: outputsize, order: "asc", format: "JSON")
    end

    def earliest_timestamp(symbol:, interval:)
      validate(symbol, interval)
      # Documented responses omit the status field, so only an explicit error fails.
      fetch("earliest_timestamp", status_required: false, symbol: symbol, interval: interval, timezone: "UTC", format: "JSON")
    end

    def forex_pairs(symbol:)
      raise ArgumentError, "Unsupported forex symbol" unless ProviderRequest::SYMBOLS.include?(symbol)
      fetch("forex_pairs", symbol: symbol, format: "JSON")
    end

    private

    def validate(symbol, interval)
      raise ArgumentError, "Unsupported forex symbol" unless ProviderRequest::SYMBOLS.include?(symbol)
      raise ArgumentError, "Unsupported interval" unless ProviderRequest::INTERVALS.include?(interval)
    end

    def fetch(endpoint, max_bytes: 262_144, status_required: true, **parameters)
      key = @key.call
      raise ArgumentError, "Missing data_api_key credential" unless key.is_a?(String) && key.present? && !key.match?(/[\r\n]/)
      uri = URI("https://api.twelvedata.com/#{endpoint}")
      uri.query = URI.encode_www_form(parameters)
      normalize(@transport.call(uri, { "Authorization" => "apikey #{key}" }), max_bytes, status_required)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      failure("timeout")
    rescue SocketError, EOFError, IOError, SystemCallError, OpenSSL::SSL::SSLError
      failure("transport_error")
    end

    def request(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10, write_timeout: 5, max_retries: 0) do |http|
        http.request(Net::HTTP::Get.new(uri, headers))
      end
    end

    def normalize(http, max_bytes, status_required)
      code = http.code.to_i
      credits = { credits_used: integer_header(http["api-credits-used"]), credits_left: integer_header(http["api-credits-left"]) }
      retry_after = integer_header(http["retry-after"])
      return failure("rate_limited", code, credits, retry_after) if code == 429
      return failure("http_error", code, credits) unless code == 200
      return failure("invalid_response", code, credits) if http.body.bytesize > max_bytes

      payload = JSON.parse(http.body)
      return failure("invalid_response", code, credits) unless payload.is_a?(Hash)
      status_ok = status_required ? payload["status"] == "ok" : payload.fetch("status", "ok") == "ok"
      return failure("provider_error", code, credits) unless status_ok

      Response.new(status: "success", http_status: code, **credits, error_code: nil, payload: payload, retry_after: nil)
    rescue JSON::ParserError
      failure("invalid_response", code, credits)
    end

    def integer_header(value)
      value.to_s.match?(/\A\d{1,9}\z/) ? value.to_i : nil
    end

    def failure(error_code, http_status = nil, credits = {}, retry_after = nil)
      Response.new(status: "provider_failure", http_status: http_status,
        credits_used: credits[:credits_used], credits_left: credits[:credits_left],
        error_code: error_code, payload: nil, retry_after: retry_after)
    end
  end
end
