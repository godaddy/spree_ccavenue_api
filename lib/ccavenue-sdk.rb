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
        production: "https://secure.ccavenue.com/transaction/transaction.do?command=initiateTransaction",
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

    attr_reader :transaction_url, :api_url, :signup_url,
                :merchant_id, :access_code, :encryption_key, :test_mode

    def initialize(opts)
      @test_mode = opts[:test_mode].nil? ? false : opts[:test_mode] # it hits production urls by default now and test is the forced mode

      @transaction_url = opts[:transaction_url].present? ? opts[:transaction_url] : (@test_mode ? self.class.default_transaction_url : self.class.production_transaction_url)
      @api_url         = opts[:api_url].present? ? opts[:api_url] : (@test_mode ? self.class.default_api_url : self.class.production_api_url)
      @signup_url      = opts[:signup_url].present? ? opts[:signup_url] : (@test_mode ? self.class.default_signup_url : self.class.production_signup_url)
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
      ccavenue_transaction_class.create!(:amount                => order.total.to_s,
                                         :currency              => order.currency.to_s,
                                         :ccavenue_order_number => order.number
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
                                          merchant_param5: nil
                                        })
      req            = crypter.encrypt(request_params.to_query)
      Rails.logger.debug "Encrypting params: #{request_params.inspect} to #{req}"
      req
    end

    def parse_redirect_response(encrypted_response)
      Rack::Utils.parse_nested_query(crypter.decrypt(encrypted_response))
    end

    def update_transaction_from_redirect_response(transaction, cc_params)
      Rails.logger.info "Decrypted params from ccavenue #{cc_params.inspect}"
      transaction.update_attributes!(
        :auth_desc       => cc_params['order_status'],
        :card_category   => cc_params['card_name'],
        :tracking_id     => cc_params['tracking_id'],
        :ccavenue_amount => cc_params['amount']
      )
    end

    #############
    # API stuff

    # CCAvenue doesn't have a validate merchant api endpoint.
    # we use the order status api endpoint with an empty order number to simulate it
    def validate_merchant_credentials(new_access_code, new_encryption_key)
      #stash old creds and crypter
      @old_access_code = @access_code; @old_encryption_key = @encryption_key
      @old_crypter     = @crypter; @old_req_builder = @req_builder

      # init SDK with new merchant credentials
      init_from_merchant_credentials(new_access_code, new_encryption_key)
      data     = { reference_no: '', order_no: '' }.to_json # empty order id
      response = api_request(req_builder.order_status(data), Responses::MerchantValidationResponse)
      Rails.logger.info "Received following API validation response: #{response.inspect}"
      response.successful?
    ensure
      # restore old creds back
      @access_code = @old_access_code; @encryption_key = @old_encryption_key
      @crypter     = @old_crypter; @req_builder = @old_req_builder
    end

    #############
    # API stuff

    # we actually do a cancel first and then a refund since CCavenue maintains a state on its own side
    # and at this point we are not sure what their state is. We try canceling first and if that doesn't
    # succeed, we try refunding the payment
    def void!(tracking_id)
      transaction = ccavenue_transaction_class.find_by_tracking_id(tracking_id) || raise(ActiveRecord::RecordNotFound)
      cancel_response = self.cancel!(transaction)
      refund_response = self.refund!(transaction) unless cancel_response.successful? # cancel command succeeded
      response    =  refund_response || cancel_response
      Rails.logger.info %Q!Void api request returned #{response.successful? ? 'successfully' : "with a failure '#{response.reason}'"}!
      response
    end

    def cancel!(transaction)
      response = build_and_invoke_api_request(transaction) do
        data = { 'order_List' => [{ reference_no: transaction.tracking_id, amount: transaction.amount.to_s }] }.to_json
        [req_builder.cancel_order(data), Responses::CancelResponse]
      end
      Rails.logger.info %Q!Cancel api request returned #{response.successful? ? 'successfully' : "with a failure '#{response.reason}'"}!
      response
    end

    def refund!(transaction)
      response = build_and_invoke_api_request(transaction) do
        data = { reference_no: transaction.tracking_id, refund_amount: transaction.amount.to_s,
                 refund_ref_no: transaction.ccavenue_order_number }.to_json
        [req_builder.refund_order(data), Responses::RefundResponse]
      end
      Rails.logger.info %Q!Refund api request returned #{response.successful? ? 'successfully' : "with a failure '#{response.reason}'"}!
      response
    end

    def crypter
      if encryption_key
        @crypter ||= Crypter.new(encryption_key)
      end
      @crypter
    end

    def req_builder
      if access_code && encryption_key
        @req_builder ||= RequestBuilder.new(access_code, crypter)
      end
      @req_builder
    end

    #####################################
    private

    def init_from_merchant_credentials(new_access_code, new_encryption_key)
      @access_code    = new_access_code
      @encryption_key = new_encryption_key
      @crypter        = Crypter.new(@encryption_key) if @encryption_key
      @req_builder    = RequestBuilder.new(@access_code, @crypter) if @access_code && @encryption_key
    end

    def api_request(payload, response_klass)
      http_response = ::RestClient::Request.execute(method:     :post, url: api_url, payload: payload,
                                                    headers:    {'Accept' => 'application/json', :accept_encoding => 'gzip, deflate'},
                                                    verify_ssl: !test_mode)
      response_klass.successful_http_request(Rack::Utils.parse_query(http_response), crypter)
    rescue ::RestClient::RequestTimeout, ::RestClient::Exception, RuntimeError => error
      return response_klass.failed_http_request(error.message, crypter)
    end

    def build_and_invoke_api_request(transaction)
      raise ArgumentError.new(Spree.t('ccavenue.unable_to_void')) unless transaction.tracking_id
      response = api_request *yield
      Rails.logger.debug "Received following API response: #{response.inspect} for ccave transaction #{transaction.id}"
      response
    end


  end

  ################################
  ################################
  class RequestBuilder

    attr_reader :crypter

    API_VERSION = 1.1

    def initialize(access_code, crypter)
      @crypter     = crypter
      @defaultHash = {
        request_type: 'JSON',
        access_code:  access_code,
        version: API_VERSION
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

end