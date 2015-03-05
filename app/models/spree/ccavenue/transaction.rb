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

    def errors
      return [] if success?
      return [Spree.t('ccavenue.payment_failed')] if failed?
      return [Spree.t('ccavenue.payment_aborted')] if aborted?
    end

  end
end
