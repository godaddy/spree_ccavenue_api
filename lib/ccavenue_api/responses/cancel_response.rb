module CcavenueApi
  class CancelResponse
    # the keys of this hash are the attributes of the response
    def build_from_response(response)
      hsh = if response['Refund_Order_Result'] # refund response
              tmp = { refund_status: (check_if_equal(response['Refund_Order_Result']['refund_status'], 0)) ? :success : :failed, }
              if response['Refund_Order_Result']['reason'] # Only present for failed requests
                tmp[:reason] = response['Refund_Order_Result']['reason']
              end
              tmp
              # "{\"Order_Status_Result\":{\"status\":1,\"error_desc\":\"Providing Reference_No/Order No is mandatory.\"}}"
            elsif response['Order_Status_Result'] # order status response
              tmp          = {
                request_status:         (check_if_equal(response['Order_Status_Result']['status'], 0)) ? :success : :failed,
                order_status:           (check_if_equal(response['Order_Status_Result']['order_status'], 0)) ? :success : :failed,
                order_status_date_time: response['Order_Status_Result']['order_status_date_time']
              }
              tmp[:reason] = response['Order_Status_Result']['error_desc'] if response['Order_Status_Result']['error_desc']
              tmp
            elsif response['Order_Result'] # cancel response
              success_count = Integer(response['Order_Result']['success_count']) rescue nil
              tmp = { success_count: success_count }
              if response['Order_Result']['failed_List'] && (response['Order_Result']['failed_List']['failed_order']).kind_of?(Hash)
                tmp[:reason] = response['Order_Result']['failed_List']['failed_order']['reason'] rescue Spree.t('ccavenue.api_response_parse_failed')
              elsif response['Order_Result']['failed_List'] && (response['Order_Result']['failed_List']['failed_order']).kind_of?(Array)
                tmp[:reason] = ((response['Order_Result']['failed_List']['failed_order']).first)['reason'] rescue Spree.t('ccavenue.api_response_parse_failed')
              end
              tmp
            else
              raise ArgumentError.new 'Unknown response type'
            end

      return hsh
    rescue => e
      Rails.logger.error("Error parsing ccavenue api response: #{e.message}")
      return {
        reason:     Spree.t("ccavenue.api_response_parse_failed"),
        api_status: :failed
      }
    end
  end
end
