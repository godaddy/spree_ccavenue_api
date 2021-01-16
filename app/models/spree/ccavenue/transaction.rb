# frozen_string_literal: true

module Spree
  class Ccavenue::Transaction < ActiveRecord::Base
    def failed?
      self.auth_desc == 'Failure'
    end

    def aborted?
      self.auth_desc == 'Aborted'
    end

    def success?
      self.auth_desc == 'Success'
    end

    def transaction_error
      return nil if success?
      return Spree.t('ccavenue.payment_failed') if failed?
      return Spree.t('ccavenue.payment_aborted') if aborted?
      Spree.t('ccavenue.generic_failed')
    end

    def gateway_order_number(order)
      [order.number, '-', self.id].join
    end
  end
end
