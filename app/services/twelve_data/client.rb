require "net/http"
require "json"

module TwelveData
  class Client
    Response = Data.define(:status, :http_status, :credits_used, :credits_left, :error_code, :payload, :retry_after)

    def initialize(key: -> { Rails.application.credentials.data_api_key }, transport: nil)
      @key = key
      @transport = transport || method(:request)
    end

    def time_series(symbol:, interval:)
      raise ArgumentError, "Unsupported forex symbol" unless ProviderRequest::SYMBOLS.include?(symbol)
      raise ArgumentError, "Unsupported interval" unless ProviderRequest::INTERVALS.include?(interval)
      key = @key.call
      raise ArgumentError, "Missing data_api_key credential" unless key.is_a?(String) && key.present? && !key.match?(/[\r\n]/)

      uri = URI("https://api.twelvedata.com/time_series")
      uri.query = URI.encode_www_form(symbol: symbol, interval: interval, timezone: "UTC", outputsize: 8, order: "asc", format: "JSON")
      http = @transport.call(uri, { "Authorization" => "apikey #{key}" })
      normalize(http)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      failure("timeout")
    rescue SocketError, EOFError, IOError, SystemCallError, OpenSSL::SSL::SSLError
      failure("transport_error")
    end

    private

    def request(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10, write_timeout: 5, max_retries: 0) do |http|
        http.request(Net::HTTP::Get.new(uri, headers))
      end
    end

    def normalize(http)
      code = http.code.to_i
      credits = { credits_used: integer_header(http["api-credits-used"]), credits_left: integer_header(http["api-credits-left"]) }
      retry_after = integer_header(http["retry-after"])
      return failure("rate_limited", code, credits, retry_after) if code == 429
      return failure("http_error", code, credits) unless code == 200
      return failure("invalid_response", code, credits) if http.body.bytesize > 262_144

      payload = JSON.parse(http.body)
      return failure("invalid_response", code, credits) unless payload.is_a?(Hash)
      return failure("provider_error", code, credits) unless payload["status"] == "ok"

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
