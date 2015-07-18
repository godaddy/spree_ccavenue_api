module CcavenueApi
  module Responses
    class CancelResponse < Response
      # the keys of this hash are the attributes of the response
      def self.build_from_response(decrypted_response)
        success_count = Integer(decrypted_response['success_count'])
        if success_count > 0
          # successful
          { success_count: success_count }
        else
          # some error, log it
          first_failed_order = decrypted_response['failed_List'].first # we only issue cancel for one order
          Rails.logger.error "ccavenue cancel response: #{first_failed_order['error_code']}  #{first_failed_order['reason']}"
          { success_count: 0, error_code: first_failed_order['error_code'], reason: first_failed_order['reason'] }
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
        self.http_status == :success && self.api_status == :success && @success_count > 0
      end

    end
  end
end
