module CcavenueApi
  class Response

    class << self

      def failed_http_request(payload, decrypter)
        self.new(:reason => payload, :http_status => :failed, :original_payload => payload)
      end

      def successful_http_request(api_response, decrypter)
        Rails.logger.debug "Received api response: #{api_response}"

        if api_response["status"] && api_response["status"] == "1"
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

      # the keys of this hash are the attributes of the response
      def build_from_response(response)
        hsh = if response['Refund_Order_Result']  # refund response
                tmp = {refund_status: (check_if_equal(response['Refund_Order_Result']['refund_status'], 0)) ? :success : :failed, }
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
              elsif response['Order_Result']  # cancel response
                success_count = Integer(response['Order_Result']['success_count']) rescue nil
                tmp = {success_count: success_count}
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

      def check_if_equal(var, val)
        var === val.to_s || var === val
      end
    end

    ################################
    attr_reader :http_status, :api_status, :original_payload

    def initialize(opts)
      opts = HashWithIndifferentAccess.new(opts)
      # see build_from_response for the list of attributes e.g. reason, status_count
      opts.keys.each do |key|
        self.instance_variable_set("@#{key}".to_sym, opts[key])
      end
    end

    # an api request can fail in transport
    # or it can be a business fail
    def success?
      req_status = @request_status.blank? ? true : (@request_status == :success)
      self.http_status == :success && self.api_status == :success && req_status
    end

    ### cancel api response
    def cancel_successful?
      return false if @success_count.blank?
      self.success? && @success_count > 0
    end

    ### refund api response
    def refund_successful?
      return false if @refund_status.blank?
      self.success? && @refund_status == :success && @reason.blank?
    end

    ### void api response
    def void_successful?
      return true if self.cancel_successful?
      self.refund_successful?
    end

    ### status api response
    def order_status
      return false if @order_status.blank?
      self.success? && @order_status == :success
    end

    def order_status_updated_at
      @order_status_date_time
    end

    ### merchant credentials validation
    VALIDATION_SUCCESS_MSG = 'Providing Reference_No/Order No is mandatory'

    def credentials_valid?
      valid_reason = @reason.match(/#{VALIDATION_SUCCESS_MSG}/) unless @reason.blank?
      self.http_status == :success && self.api_status == :success && valid_reason.present?
    end

    def credentials_validation_error
      @reason.blank? ? Spree.t('ccavenue.unknown_api_error') : @reason
    end

    def authorization
      "#{@reason} #{@refund_status}"
    end

    def reason
      @reason.to_s
    end

    private

    def check_if_equal(var, val)
      self.class.check_if_equal(var, val)
    end

  end
end
