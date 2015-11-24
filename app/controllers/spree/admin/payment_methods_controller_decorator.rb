require 'ccavenue-sdk'

Spree::Admin::PaymentMethodsController.class_eval do
  def ccavenue_verify
    payment_method = Spree::PaymentMethod.find(params[:id])

    all_credentials_specified = params[:gateway_ccavenue] && (
              params[:gateway_ccavenue][:preferred_merchant_id].present? &&
              params[:gateway_ccavenue][:preferred_access_code].present? &&
              params[:gateway_ccavenue][:preferred_encryption_key].present?
    )

    respond_to do |format|
      unless all_credentials_specified
        format.html { render text: Spree.t('ccavenue.verification_failed') }
      else
        valid = payment_method.provider.validate_merchant_credentials(params[:gateway_ccavenue][:preferred_access_code], params[:gateway_ccavenue][:preferred_encryption_key])
        reason = valid ? Spree.t('ccavenue.verification_successful') : Spree.t('ccavenue.verification_unsuccessful')
        format.html { render text: reason }
      end
    end
  end
end
