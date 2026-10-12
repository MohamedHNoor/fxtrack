require "net/http"
require "json"

class ResendSignalSender
  class TransientError < StandardError; end
  class PermanentError < StandardError; end

  def initialize(key: -> { Rails.application.credentials[:RESEND_API_KEY] }, transport: nil)
    @key, @transport = key, transport || method(:request)
  end

  def send(payload, idempotency_key:)
    key = @key.call
    raise PermanentError, "Missing email credential" unless key.is_a?(String) && key.present? && !key.match?(/[\r\n]/)
    response = @transport.call(payload, key, idempotency_key)
    code = response.code.to_i
    raise TransientError, "Email provider temporarily unavailable" if code == 429 || code >= 500
    if code == 409
      body = JSON.parse(response.body) rescue {}
      raise TransientError, "Email request in progress" if body.is_a?(Hash) && body["name"] == "concurrent_idempotent_requests"
    end
    raise PermanentError, "Email provider rejected request" unless (200..299).cover?(code)
    body = JSON.parse(response.body)
    raise TransientError, "Invalid email provider response" unless body.is_a?(Hash) && body["id"].is_a?(String) && body["id"].present?
  rescue JSON::ParserError
    raise TransientError, "Invalid email provider response"
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, EOFError, IOError, SystemCallError, OpenSSL::SSL::SSLError
    raise TransientError, "Email transport unavailable"
  end

  private
    def request(payload, key, idempotency_key)
      uri = URI("https://api.resend.com/emails")
      http_request = Net::HTTP::Post.new(uri)
      http_request["Authorization"] = "Bearer #{key}"
      http_request["Idempotency-Key"] = idempotency_key
      http_request["Content-Type"] = "application/json"
      http_request.body = payload.to_json
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10, write_timeout: 5, max_retries: 0) do |http|
        http.request(http_request)
      end
    end
end
