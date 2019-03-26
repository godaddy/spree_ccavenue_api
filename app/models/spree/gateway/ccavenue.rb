# frozen_string_literal: true

module Spree
  class Gateway::Ccavenue < Gateway

    preference :merchant_id, :string
    preference :access_code, :string
    preference :encryption_key, :string
    preference :transaction_url, :string
    preference :api_url, :string
    preference :signup_url, :string


    def supports?(source)
      source.is_a? payment_source_class
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

    #
    def payment_profiles_supported?
      false
    end

    #############################
    #  purchase  reflects the source (Spree::Ccavenue::Transaction) status instead of making an api call
    def purchase(amount, transaction, options={})
      ret = if transaction.success?
        ActiveMerchant::Billing::Response.new(true, Spree.t('ccavenue.order_processed_successfully'), {},
                                              :test => self.preferred_test_mode, :authorization => transaction.tracking_id)
      else
        ActiveMerchant::Billing::Response.new(false, Spree.t('ccavenue.generic_failed'), { :message => transaction.transaction_error },
                                              :test => self.preferred_test_mode)
      end
      ret
    end

    # payment profiles are supported
    def void(tracking_id, options={})
      response = provider.void!(tracking_id)
      ret = if response.void_successful?
        ActiveMerchant::Billing::Response.new(true, Spree.t('ccavenue.void_successful'), {},
                                              :test => self.preferred_test_mode, :authorization => tracking_id)
      else
        ActiveMerchant::Billing::Response.new(false, Spree.t('ccavenue.void_failed'), { :message => response.reason },
                                              :test => self.preferred_test_mode)
      end
      ret
    end

    # since we don't use the Gateway interface to make any of the calls below
    #########################################################################

    def authorize(amount, transaction, options={})
      raise 'not implemented'
    end

    # capture is only one where source is not passed in for payment profile
    def capture(amount, tracking_id, options={})
      raise 'not implemented'
    end

    # payment profiles are supported
    def credit(amount, tracking_id, options={})
      raise 'not implemented'
    end

    def cancel(tracking_id)
      raise 'not implemented'
    end


  end
end
