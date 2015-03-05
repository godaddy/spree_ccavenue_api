require 'ccavenue-sdk'
module Spree
  class Gateway::Ccavenue < Gateway

    preference :merchant_id, :string
    preference :access_code, :string
    preference :encryption_key, :string
    preference :transaction_url, :string
    preference :api_url, :string
    preference :signup_url, :string


    def supports?(source)
      true if source.is_a? payment_source_class
    end

    def payment_source_class
      Spree::Ccavenue::Transaction
    end

    def provider_class
      CcavenueApi::SDK
    end

    def provider
      provider_class.new(
          :transaction_url => preferred_transaction_url,
          :api_url         => preferred_api_url,
          :merchant_id     => preferred_merchant_id,
          :access_code     => preferred_access_code,
          :encryption_key  => preferred_encryption_key,
          :test_mode       => preferred_test_mode
      )
    end

    def auto_capture?
      true
    end

    def method_type
      'ccavenue'
    end

    def payment_profiles_supported?
      false
    end

    #############################
    #  purchase  reflects the source (Spree::Ccavenue::Transaction) status instead of making an api call
    def purchase(amount, source, options={})
      if source.success?
        Class.new do
          def success?; true; end
          def authorization; nil; end
        end.new
      else
        class << source
          def to_s
            transaction_errors.join("\n")
          end
        end
        source
      end
    end

    # since we don't use the Gateway interface to make any of the calls below
    #########################################################################

    def authorize(amount, response_code, options={})
      raise 'not implemented'
    end

    # capture is only one where source is not passed in for payment profile
    def capture(amount, response_code, options={})
      raise 'not implemented'
    end

    # payment profiles are not supported
    def credit(amount, response_code, options={})
      raise 'not implemented'
    end

    def cancel(response_code)
      raise 'not implemented'
    end

    # payment profiles are not supported
    def void(response_code, options={})
      raise 'not implemented'
    end


  end
end
