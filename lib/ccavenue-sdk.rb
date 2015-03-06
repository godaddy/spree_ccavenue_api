require 'rack/utils'
require 'rest-client'
require 'aes_crypter'

module CcavenueApi
  ################################
  class Crypter
    ################################

    def initialize(encryption_key)
      @encryption_key = encryption_key
    end

    def encrypt(data)
      AESCrypter.encrypt(data, @encryption_key)
    end

    def decrypt(data)
      AESCrypter.decrypt(data, @encryption_key)
    end
  end

  ################################
  class SDK
    ################################
    URLS = {
      transaction: {
        production: "https://secure.ccavenue.com/transaction/transaction.do",
        default:    "https://test.ccavenue.com/transaction/transaction.do"
      },
      api:         {
        production: "https://login.ccavenue.com/apis/servlet/DoWebTrans",
        default:    "https://180.179.175.17/apis/servlet/DoWebTrans"
      },
      signup:      {
        production: "https://login.ccavenue.com/web/registration.do?command=navigateSchemeForm",
        default:    "https://180.179.175.17/web/registration.do?command=navigateSchemeForm"
      }
    }

    class << self
      URLS.keys.each do |url_type|
        [:production, :default].each do |server_mode|
          define_method("#{server_mode}_#{url_type}_url") do
            URLS[url_type][server_mode]
          end
        end
      end
    end

    #################################### instance

    attr_reader :transaction_url, :api_url,
                :merchant_id, :access_code, :encryption_key, :test_mode

    def initialize(opts)
      @test_mode = opts[:test_mode] || true

      @transaction_url = opts[:transaction_url] || (@test_mode ? self.class.default_transaction_url : self.class.production_transaction_url)
      @api_url         = opts[:api_url] || (@test_mode ? self.class.default_api_url : self.class.production_api_url)
      @merchant_id     = opts[:merchant_id]
      @access_code     = opts[:access_code]
      @encryption_key  = opts[:encryption_key]

      init_from_merchant_credentials(@access_code, @encryption_key)
    end

    def ccavenue_transaction_class
      Spree::Ccavenue::Transaction
    end

    ###############
    # Browser Redirect methods
    #
    def build_ccavenue_checkout_transaction(order)
      ccavenue_transaction_class.create!(:amount   => order.total.to_s,
                                         :currency => order.currency.to_s,
      )
    end

    def build_encrypted_request(transaction, order_data={})
      request_params = order_data.merge({
                                          merchant_id:     merchant_id,
                                          cancel_url:      '',
                                          language:        'EN',
                                          merchant_param1: nil,
                                          merchant_param2: nil,
                                          merchant_param3: nil,
                                          merchant_param4: nil,
                                          merchant_param5: nil,
                                        })
      req            = crypter.encrypt(request_params.to_query)
      Rails.logger.debug "Encrypting params: #{request_params.inspect} to #{req}"
      req
    end

    def update_transaction_from_redirect_response(transaction, encrypted_response)
      cc_params = Rack::Utils.parse_nested_query(crypter.decrypt(encrypted_response))
      Rails.logger.info "Decrypted params from ccavenue #{cc_params.inspect}"
      transaction.update_attributes!(
        :auth_desc             => test_mode ? 'Success' : cc_params['order_status'],
        :card_category         => cc_params['card_name'],
        :ccavenue_order_number => cc_params['order_id'],
        :tracking_id           => cc_params['tracking_id'],
        :ccavenue_amount       => cc_params['amount']
      )
    end

    # CCAvenue doesn't have a validate merchant api endpoint.
    # we use the order status api endpoint with an empty order number to simulate it
    def validate_merchant_credentials(new_access_code, new_encryption_key)
      #stash old creds and crypter
      @old_access_code = @access_code; @old_encryption_key = @encryption_key
      @old_crypter     = @crypter; @old_req_builder = @req_builder

      # init SDK with new merchant credentials
      init_from_merchant_credentials(new_access_code, new_encryption_key)
      data     = {reference_no: '', order_no: ''}.to_json # empty order id
      response = api_request(req_builder.order_status(data))
      Rails.logger.info "Received following API validation response: #{response.inspect}"
      response
    ensure
      # restore old creds back
      @access_code = @old_access_code; @encryption_key = @old_encryption_key
      @crypter     = @old_crypter; @req_builder = @old_req_builder
    end

    #############
    # API stuff

    def build_and_invoke_api_request(transaction)
      raise ArgumentError.new(Spree.t('ccavenue.unable_to_void')) unless transaction.tracking_id
      response = api_request(yield)
      Rails.logger.debug "Received following API response: #{response.inspect} for ccave transaction #{transaction.id}"
      response
    end

    # we actually do a cancel first and then a refund since CCavenue maintains a state on its own side
    # and at this point we are not sure what their state is. We try canceling first and if that doesn't
    # succeed, we try refunding the payment
    def void!(transaction)
      response = self.cancel!(transaction)
      response = self.refund!(transaction) unless response.cancel_successful? # cancel command succeeded
      Rails.logger.info %Q!Void api request returned #{response.void_successful? ? 'successfully' : "with a failure '#{response.reason}'"}!
      response
    end

    def cancel!(transaction)
      response = build_and_invoke_api_request(transaction) do
        data = {'order_List' => [{reference_no: transaction.tracking_id, amount: transaction.amount.to_s}]}.to_json
        req_builder.cancel_order(data)
      end
      Rails.logger.info %Q!Cancel api request returned #{response.cancel_successful? ? 'successfully' : "with a failure '#{response.reason}'"}!
      response
    end

    def refund!(transaction)
      response = build_and_invoke_api_request(transaction) do
        data = {'order_List' => [{reference_no: transaction.tracking_id, amount: transaction.amount.to_s}]}.to_json
        req_builder.refund_order(data)
      end
      Rails.logger.info %Q!Refund api request returned #{response.refund_successful? ? 'successfully' : "with a failure '#{response.reason}'"}!
      response
    end

    #####################################
    private

    def crypter
      if @encryption_key
        @crypter ||= Crypter.new(@encryption_key)
      end
      @crypter
    end

    def req_builder
      if @access_code && @encryption_key
        @req_builder ||= RequestBuilder.new(@access_code, crypter)
      end
      @req_builder
    end

    def init_from_merchant_credentials(new_access_code, new_encryption_key)
      @access_code    = new_access_code
      @encryption_key = new_encryption_key
      @crypter        = Crypter.new(@encryption_key) if @encryption_key
      @req_builder    = RequestBuilder.new(@access_code, @crypter) if @access_code && @encryption_key
    end

    def api_request(payload)
      http_response = ::RestClient::Request.execute(method:     :post, url: api_url, payload: payload,
                                                    headers:    {'Accept' => 'application/json', :accept_encoding => 'gzip, deflate'},
                                                    verify_ssl: !test_mode)
      Response.successful_http_request(Rack::Utils.parse_query(http_response), crypter)
    rescue ::RestClient::RequestTimeout, ::RestClient::Exception, RuntimeError => error
      return Response.failed_http_request(error.message, crypter)
    end

  end

  ################################
  ################################
  class RequestBuilder

    attr_reader :access_code, :crypter

    def initialize(access_code, crypter)
      @access_code = access_code
      @crypter     = crypter
      @defaultHash = {
        request_type: 'JSON',
        access_code:  access_code,
      }
    end

    def cancel_order(data)
      @defaultHash.merge({
                           command:     'cancelOrder',
                           enc_request: crypter.encrypt(data)
                         })
    end

    def refund_order(data)
      @defaultHash.merge({
                           command:     'refundOrder',
                           enc_request: crypter.encrypt(data)
                         })
    end

    def order_status(data)
      @defaultHash.merge({
                           command:     'orderStatusTracker',
                           enc_request: crypter.encrypt(data)
                         })
    end
  end

  ################################
  ################################
  class Response

    class << self
      def failed_http_request(payload, decrypter)
        self.new(:reason => payload, :http_status => :failed, :original_payload => payload)
      end

      def successful_http_request(api_response, decrypter)
        Rails.logger.debug "Received api response: #{api_response}"

        if api_response["status"] && api_response["status"] == "1"
          self.new(:reason           => api_response["enc_response"],
                   :http_status      => :failed,
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
        hsh = if response['Refund_Order_Result']
                {
                  refund_status: response['Refund_Order_Result']['refund_status'],
                  reason:        response['Refund_Order_Result']['reason'] # Only present for failed requests
                }
                # "{\"Order_Status_Result\":{\"status\":1,\"error_desc\":\"Providing Reference_No/Order No is mandatory.\"}}"
              elsif response['Order_Status_Result']
                {
                  request_status:         (response['Order_Status_Result']['status'] == 0) ? :success : :failed,
                  reason:                 response['Order_Status_Result']['error_desc'], # Only present for failed requests
                  order_status:           response['Order_Status_Result']['order_status'],
                  order_status_date_time: response['Order_Status_Result']['order_status_date_time']
                }
              elsif response['Order_Result']
                tmp = {success_count: response['Order_Result']['success_count']}
                if response['Order_Result']['failed_List'] && !response['Order_Result']['failed_List'].blank?
                  reason = response['Order_Result']['failed_List']['failed_order'].first['reason'] rescue Spree.t('ccavenue.api_response_parse_failed')
                  tmp[:reason] = reason
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
      self.success? && @success_count > 0
    end

    ### refund api response
    def refund_successful?
      self.success? && check_if_string_or_number(@refund_status, 0) && @reason.blank?
    end

    ### void api response
    def void_successful?
      self.cancel_successful? || self.refund_successful?
    end

    ### status api response
    def order_status
      @order_status
    end

    def order_status_updated_at
      @order_status_date_time
    end

    ### merchant credentials validation
    VALIDATION_SUCCESS_MSG = 'Providing Reference_No/Order No is mandatory'

    def credentials_valid?
      self.http_status == :success && self.api_status == :success && (!@reason.blank? && @reason =~ /#{VALIDATION_SUCCESS_MSG}/)
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

    def check_if_string_or_number(var, val)
      var === val.to_s || var === val
    end
  end
end