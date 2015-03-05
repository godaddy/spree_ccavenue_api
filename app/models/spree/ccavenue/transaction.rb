module Spree
  class Ccavenue::Transaction < ActiveRecord::Base

    def failed?
      self.auth_desc && self.auth_desc == 'Failure'
    end

    def aborted?
      self.auth_desc && self.auth_desc == 'Aborted'
    end

    def success?
      self.auth_desc && self.auth_desc == 'Success'
    end

    def transaction_errors
      return [] if success?
      return [Spree.t('ccavenue.payment_failed')] if failed?
      return [Spree.t('ccavenue.payment_aborted')] if aborted?
    end

    def gateway_order_number(order)
      [order.number, '-', self.id].join
    end

  end
end
