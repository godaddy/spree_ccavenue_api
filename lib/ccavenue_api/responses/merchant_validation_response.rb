module CcavenueApi
  module Responses
    class MerchantValidationResponse < Response
      MERCHANT_CREDS_VALID_ERROR_CODE = '51004' # Reference number/Order number: Invalid Parameter
      # Ensure that reference number/order number is provided.

      # the keys of this hash are the attributes of the response
      # if we are here, the merchant creds are valid since we are able to encrypt and decrypt the responses correctly
      #
      def self.build_from_response(decrypted_response)
        status = Integer(decrypted_response['status'])
        if status == 0
          # for merchant validation this should never be true since we didnt pass a valid order for it to check
          Rails.logger.error "Ccavenue response - status is 0, which should never be for this request - #{decrypted_response.inspect}"
          { request_successful: false, reason: Spree.t("ccavenue.unexpected_api_status", { status: status }) }
        else
          # expected since we didnt pass a valid order reference number to the request
          error_code = decrypted_response['error_code']
          if error_code == MERCHANT_CREDS_VALID_ERROR_CODE
            { request_successful: true }
          else
            Rails.logger.error("Ccavenue response error - (expected error_code #{MERCHANT_CREDS_VALID_ERROR_CODE}) - got (#{decrypted_response.inspect})")
            { request_successful: false, reason: Spree.t("ccavenue.invalid_api_error_code", { error_code: error_code }) }
          end
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
