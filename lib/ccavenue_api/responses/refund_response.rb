module CcavenueApi
  module Responses
    class RefundResponse < Response

      # the keys of this hash are the attributes of the response
      def self.build_from_response(decrypted_response)
        status = Integer(decrypted_response['refund_status'])
        if status == 0
          # successful
          { request_successful: true }
        else
          # some error, log it
          Rails.logger.error "ccavenue refund response: #{decrypted_response.inspect}"
          { request_successful: false, error_code: decrypted_response['error_code'], reason: decrypted_response['reason'] }
        end
      rescue => e
        Rails.logger.error("Error parsing ccavenue api response: #{e.message}")
        return {
          reason:     Spree.t("ccavenue.api_response_parse_failed"),
          api_status: :failed
        }
      end
    end
  end
end
