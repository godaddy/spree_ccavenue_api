module CcavenueApi
  class Response

    class << self
      def failed_http_request(payload, decrypter)
        self.new(:reason => payload, :http_status => :failed, :original_payload => payload)
      end

      def successful_http_request(api_response, decrypter)
        Rails.logger.debug "Received api response: #{api_response}"

        if api_response["status"] && api_response["status"] == "1"
          # failed
          self.new(:reason           => api_response["enc_response"],
                   :http_status      => :success,
                   :api_status       => :failed,
                   :original_payload => api_response
          )
        else
          decrypted_payload = decrypter.decrypt(api_response['enc_response'].gsub('\r\n', '').strip)
          Rails.logger.debug "Decrypted response: #{decrypted_payload}"

          decrypted_hash = ActiveSupport::JSON.decode(decrypted_payload)
          parsed         = build_from_response(decrypted_hash)
          self.new({
                     :http_status      => :success,
                     :api_status       => :success,
                     :original_payload => decrypted_hash
                   }.merge(parsed))
        end
      end
    end

    ################################
    attr_reader :http_status, :api_status, :original_payload, :reason

    def initialize(opts)
      opts = HashWithIndifferentAccess.new(opts)
      # see build_from_response for the list of attributes e.g. reason, success_count
      opts.keys.each do |key|
        self.instance_variable_set("@#{key}".to_sym, opts[key])
      end
    end

  end
end