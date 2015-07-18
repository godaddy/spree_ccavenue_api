module CcavenueApi
  module Responses
    class MerchantValidationResponse < Response
      MERCHANT_CREDS_VALID_ERROR_CODE = '51004' # Reference number/Order number: Invalid Parameter
      # Ensure that reference number/order number is provided.

      # the keys of this hash are the attributes of the response
      def self.build_from_response(decrypted_response)
        status = Integer(decrypted_response['status'])
        if status == 0
          # successful
          { status: status }
        else
          # some error, log it
          Rails.logger.error "ccavenue status response: #{decrypted_response.inspect}"
          { status: status, error_code: decrypted_response['error_code'], error_desc: decrypted_response['error_desc'] }
        end
      rescue => e
        Rails.logger.error("Error parsing ccavenue api response: #{e.message}")
        return {
          reason:     Spree.t("ccavenue.api_response_parse_failed"),
          api_status: :failed
        }
      end

      ######################################
      # instance methods

      def successful?
        self.http_status == :success && self.api_status == :success && @error_code.present? && @error_code == MERCHANT_CREDS_VALID_ERROR_CODE
      end

      def reason
        @reason || @error_desc
      end

    end
  end
end
