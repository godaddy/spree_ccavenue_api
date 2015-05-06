module CcavenueApi
  class RequestBuilder

    attr_reader :crypter

    def initialize(access_code, crypter)
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
end
