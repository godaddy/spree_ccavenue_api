module CcavenueApi
  class RefundResponse < Response
    # the keys of this hash are the attributes of the response
    def build_from_response(response)
      # error case
      if response['reason'].present? && response['error_code'].present?
        Rails.logger.error "Error refunding: #{response['reason']}"
        {
          refund_status: :failed,
          reason: response['reason'],
          errorCode: response['error_code']
        }
      else
        {
          refund_status: :success,
        }
      end
    rescue => e
      Rails.logger.error("Error parsing ccavenue api response: #{e.message}")
      return {
        reason:     Spree.t("ccavenue.api_response_parse_failed"),
        api_status: :failed
      }
    end

    ### refund api response
    def refund_successful?
      return false if @refund_status.blank?
      self.success? && @refund_status == :success && @reason.blank?
    end

  end
end
