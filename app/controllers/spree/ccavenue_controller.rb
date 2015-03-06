module Spree
  class CcavenueController < StoreController

    skip_before_filter :verify_authenticity_token, only: :callback
    # we need this to avoid undefined method truncated_product_description in frontend. Details on: https://coveralls.io/builds/769164
    helper 'spree/orders'
    ssl_required

    # show confirmation page
    def show
      cc_transaction           = provider.build_ccavenue_checkout_transaction(order)
      @redirect_params = ccavenue_redirect_params(order, cc_transaction)
    rescue => e
      log_error(e)
      flash[:error] = Spree.t('ccavenue.generic_failed')
      redirect_to (@order.nil? ? spree.cart_path : checkout_state_path(:payment))
    end

    # return from ccavenue
    def callback
      Rails.logger.debug "Received transaction from CCAvenue #{params.inspect}"
      transaction            = ccavenue_transaction || raise(ActiveRecord::RecordNotFound)
      session[:order_id]     ||= params[:order_id]
      session[:access_token] = order.guest_token if order.respond_to?(:guest_token)

      provider.update_transaction_from_redirect_response(transaction, params['encResp'])

      unless transaction.success?
        if transaction.failed?
          flash[:error] = Spree.t('ccavenue.payment_failed')
        elsif transaction.aborted?
          flash[:error] = Spree.t('ccavenue.payment_aborted')
        else
          flash[:error] = Spree.t('ccavenue.generic_failed')
        end
        redirect_to checkout_state_path(order.state) and return
      end

      if order.insufficient_stock_lines.present?
        Rails.logger.warn "Voiding payment for order: #{order.id} tracking_id: #{transaction.tracking_id} since out of stock"
        if void_payment(transaction)
          flash[:error] = Spree.t('ccavenue.checkout_low_inventory_after_payment_warning')
        else
          flash[:error] = Spree.t('ccavenue.refund_api_call_failed')
        end
        # TODO update order to void - not sure if we should void the order since we allow the user to drop the line items
        redirect_to spree.cart_path and return
      else
        order.payments.create!({
                                 :source         => transaction,
                                 :amount         => order.total,
                                 :payment_method => payment_method
                               })

        order.next
        if order.complete?
          flash.notice            = Spree.t('ccavenue.order_processed_successfully')
          session[:order_id]      = nil
          flash[:order_completed] = true
          redirect_to completion_route(order)
        else
          redirect_to checkout_state_path(order.state)
        end
      end
    rescue => e
      log_error(e)
      flash[:error] = Spree.t('ccavenue.checkout_payment_error')
      redirect_to @order.nil? ? spree.cart_path : checkout_state_path(current_order.state)
    end

    private

    def ccavenue_transaction
      Spree::Ccavenue::Transaction.find(params[:transaction_id])
    end

    def log_error(e)
      Rails.logger.error "Error onr edirect from Ccavenue: #{e.message}"
    end

    def completion_route(order)
      order_path(order)
    end

    # override for delayed job
    def void_payment(*args)
      response = provider.void!(*args)
      response.void_successful?
    end

    def order
      (@order ||= current_order) || raise(ActiveRecord::RecordNotFound)
    end

    def payment_method
      Spree::PaymentMethod.find(params[:id])
    end

    def provider
      payment_method.provider
    end

    def redirect_url(transaction)
      ccavenue_callback_url(payment_method,
                            :order_id       => order.id,
                            :transaction_id => transaction.id,
                            :protocol       => request.local? ? request.protocol : 'https')
    end

    def ccavenue_redirect_params(order, transaction)
      ba         = order.bill_address
      sa         = order.ship_address || order.bill_address
      order_data = {
        order_id:         transaction.gateway_order_number(order),
        amount:           order.total.to_s,
        currency:         order.currency,
        promo_code:       order.coupon_code,

        billing_name:     ba.full_name,
        billing_address:  ba.address1,
        billing_city:     ba.city,
        billing_state:    ba.state.try(:name) || ba.state_name,
        billing_zip:      ba.zipcode,
        billing_country:  ba.country.name,
        billing_tel:      ba.phone,
        billing_email:    order.email,

        delivery_name:    sa.full_name,
        delivery_address: sa.address1,
        delivery_city:    sa.city,
        delivery_state:   sa.state.try(:name) || sa.state_name,
        delivery_zip:     sa.zipcode,
        delivery_country: sa.country.name,
        delivery_tel:     sa.phone,

        redirect_url:     redirect_url(transaction)
      }

      return {
        merchant_id:     provider.merchant_id,
        access_code:     provider.access_code,
        transaction_url: provider.transaction_url,
        enc_request:     provider.build_encrypted_request(transaction, order_data)
      }
    end
  end
end
