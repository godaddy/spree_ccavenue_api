module Spree
  module CcavenueHelper

    def css_class_based_on_order_state(order)
      order.state == 'confirm' ? 'alpha omega grid_24' : 'alpha grid_16'
    end

  end
end