require 'api_caller'

module Spree
  class Gateway::Ccavenue < Gateway

    has_many :ccavenue_transactions, :class_name => 'Spree::Ccavenue::Transaction'

    preference :merchant_id, :string
    preference :access_code, :string
    preference :encryption_key, :string

    validate :merchant_info_validation, on: :update

    def merchant_info_validation
      if self.preferred_access_code.blank? || self.preferred_merchant_id.blank? || self.preferred_encryption_key.blank?
        errors.add(:base, Spree.t(:ccavenue_missing_creds)) and return
      end
      if reason = ::Ccavenue::ApiCaller.validate_creds(self)
        errors.add(:base, Spree.t(:ccavenue_validation_failed))
      end
    end

    def actions
      %w{capture void status sync}
    end

    def can_capture?(payment)
      ['checkout', 'pending'].include?(payment.state)
    end

    def can_void?(payment)
      payment.state != 'void'
    end

    def capture(payment)
      payment.update_attribute(:state, 'pending') if payment.state == 'checkout'
      payment.complete
      true
    end

    def void(*args)
      response = provider.void
      if response.success?
        def response.authorization; psp_reference; end
      else

        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end
      response
    end

    def status
      response = provider.status
      if response.success?
        def response.authorization; psp_reference; end
      else

        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end
      response
    end

    def sync
      response = provider.sync
      if response.success?
        def response.authorization; psp_reference; end
      else

        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end
      response
    end

    def purchase(amount, source, options = {})
      Class.new do
        def success?;
          true;
        end

        def authorization;
          nil;
        end
      end.new
    end

    def provider_class
      Spree::Ccavenue::Transaction
    end

    def payment_source_class
      Spree::Ccavenue::Transaction
    end

    def method_type
      'ccavenue'
    end

    def auto_capture?
      true
    end

    def url
      url_part = preferred_test_mode ? 'test' : 'secure'
      "https://#{url_part}.ccavenue.com/transaction/transaction.do"
    end

  end
end
