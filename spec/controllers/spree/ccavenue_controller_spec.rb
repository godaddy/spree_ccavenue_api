require 'spec_helper'
describe Spree::CcavenueController, :type => :controller do

  let(:order) { FactoryGirl.create(:order_with_totals) }
  let!(:ccavenue_gw) { Spree::Gateway::Ccavenue.create!(name: "ccavenue test gw", environment: Rails.env) }
  let(:merchant_id) { '1234' }
  let(:enc_key) { 'test#test' }
  let(:access_code) { '1234' }
  let(:transaction_url) { 'http://1234' }
  let(:dummy_encrypted_val) { 'testingtestingtesting' }
  let(:ccavenue_provider) { CcavenueApi::SDK.new(merchant_id:     merchant_id,
                                                 access_code:     access_code,
                                                 encryption_key:  enc_key,
                                                 transaction_url: transaction_url) }
  let(:ccavenue_transaction) { double('ccave_transaction', id: 123, tracking_id: '123') }
  let(:successful_ccavenue_transaction) {
    Spree::Ccavenue::Transaction.create!(tracking_id: '123', auth_desc: 'Success', ccavenue_order_number: order.number, ccavenue_amount: order.total.to_s)
  }
  let(:changed_ccavenue_transaction) {
    Spree::Ccavenue::Transaction.create!(tracking_id: '123', auth_desc: 'Success', ccavenue_order_number: order.number, ccavenue_amount: (order.total+1).to_s)
  }
  let(:failed_ccavenue_transaction) {
    Spree::Ccavenue::Transaction.create!(tracking_id: '123', auth_desc: 'Failure', ccavenue_order_number: order.number, ccavenue_amount: order.total.to_s)
  }
  let(:aborted_ccavenue_transaction) {
    Spree::Ccavenue::Transaction.create!(tracking_id: '123', auth_desc: 'Aborted', ccavenue_order_number: order.number, ccavenue_amount: order.total.to_s)
  }
  let(:ccavenue_response) { double('ccavenue_response') }
  let(:encResp) { '123' }

  before do
    order.state = 'payment'
    order.save!
    allow(Spree::PaymentMethod).to receive(:find).and_return(ccavenue_gw)
    allow(ccavenue_gw).to receive(:provider).and_return(ccavenue_provider)
  end

  context '#show' do
    context 'successful #show' do
      before do
        allow(controller).to receive(:current_order).at_least(:once).and_return(order)
        allow(controller).to receive(:ccavenue_redirect_params).and_return({})
      end
      it 'renders show' do
        get :show, :id => ccavenue_gw.id, :use_route => 'spree'
        expect(response).to render_template("show")
      end
      it "creates a transaction" do
        expect { get :show, :id => ccavenue_gw.id, :use_route => 'spree' }.to change { Spree::Ccavenue::Transaction.count }.by(1)
      end
    end

    context "when current_order is nil" do
      before do
        allow(controller).to receive(:current_order).at_least(:once).and_return(nil)
        allow(controller).to receive(:current_spree_user).at_least(:once).and_return(nil)
        get :show, :id => ccavenue_gw.id, :use_route => 'spree'
      end
      it "redirects to cart" do
        expect(response).to redirect_to spree.cart_path
      end
      it "sets the correct flash error" do
        expect(flash[:error]).to eq(Spree.t('ccavenue.generic_failed'))
      end
    end

    context "#ccavenue_redirect_params" do
      before do
        allow(controller).to receive(:current_order).at_least(:once).and_return(order)

        expect(order).to receive(:bill_address).and_return(double('ba').as_null_object)
        expect(order).to receive(:ship_address).and_return(double('sa').as_null_object)

        expect(ccavenue_provider).to receive(:build_ccavenue_checkout_transaction).and_return(ccavenue_transaction)
        expect(ccavenue_provider).to receive(:build_encrypted_request).and_return(dummy_encrypted_val)

        expect(ccavenue_transaction).to receive(:gateway_order_number).and_return('3241')
        expect(controller).to receive(:provider).at_least(:once).and_return(ccavenue_provider)
      end
      it "compiles and encrypts ccavenue params" do
        get :show, :id => ccavenue_gw.id, :use_route => 'spree'
        expect(assigns[:redirect_params]).to eq({:merchant_id     => merchant_id,
                                                 :access_code     => access_code,
                                                 :transaction_url => transaction_url,
                                                 :enc_request     => dummy_encrypted_val})
      end
    end

  end

  context '#callback' do
    def do_post
      post :callback, :id  => ccavenue_gw.id,
           :encResp        => encResp,
           :use_route      => 'spree'
    end

    before do
      allow(controller).to receive(:provider).at_least(:once).and_return(ccavenue_provider)
      allow(ccavenue_provider).to receive(:parse_redirect_response).and_return({'order_id' => "#{order.number}-#{ccavenue_transaction.id}"})
      allow(ccavenue_provider).to receive(:update_transaction_from_redirect_response).and_return(nil)
    end

    context "when current_order is nil" do
      before do
        allow(Spree::Ccavenue::Transaction).to receive(:find).and_return(successful_ccavenue_transaction)
        expect(controller).to receive(:current_order).at_least(:once).and_return(nil)
      end

      it "redirects to cart with the correct flash message" do
        do_post
        expect(response).to redirect_to spree.cart_path
        expect(flash[:error]).to eq(Spree.t('ccavenue.checkout_payment_error'))
      end
    end

    context "when the transaction does not exist on the store side" do
      before do
        allow(Spree::Ccavenue::Transaction).to receive(:find).and_return(nil)
      end

      it "redirects to cart with the correct flash message" do
        do_post
        expect(response).to redirect_to spree.cart_path
        expect(flash[:error]).to eq(Spree.t('ccavenue.checkout_payment_error'))
      end
    end

    context "on successful ccavenue transaction" do
      before do
        expect(controller).to receive(:current_order).at_least(:once).and_return(order)
        allow(Spree::Ccavenue::Transaction).to receive(:find).and_return(successful_ccavenue_transaction)
      end

      context "when the order is successfully completed" do

        it "redirects to order completion route" do
          do_post
          expect(response).to redirect_to spree.order_path(order)
          expect(flash[:notice]).to eq(Spree.t('ccavenue.order_processed_successfully'))
        end

      end

      context "when the order is not successfully completed" do

        before do
          expect(order).to receive(:complete?).and_return(false)
        end

        it "redirects to new order checkout state path" do
          do_post
          expect(response).to redirect_to spree.checkout_state_path(order.state)
        end

        context "order has errors" do

          before do
            allow(order).to receive(:errors).and_return(double("errors", full_messages: ["the_error"]).as_null_object)
          end

          it "shows errors" do
            do_post
            expect(flash[:error]).to eq "the_error"
          end

        end

        context "order has no errors" do

          it "shows generic error" do
            do_post
            expect(flash[:error]).to eq Spree.t("ccavenue.generic_failed")
          end

        end

      end

      context "when the inventory goes low" do
        before do
          expect(order).to receive(:next).and_raise
          expect(controller).to receive(:out_of_stock_error).and_return(true)
        end

        context "and the void call succeeds" do
          before do
            expect(controller).to receive(:void_payment).and_return(true)
          end
          it "redirects to the cart with a flash message" do
            do_post
            expect(response).to redirect_to spree.cart_path
            expect(flash[:error]).to eq(Spree.t('ccavenue.checkout_low_inventory_after_payment_warning'))
          end
        end

        context "and the void call fails" do

          it "redirects with appropriate flash message" do
            expect(controller).to receive(:void_payment).and_return(false)
            do_post
            expect(flash[:error]).to eq(Spree.t('ccavenue.refund_api_call_failed'))
            expect(response).to redirect_to spree.cart_path
          end

          context "due to an exception" do

            before do
              allow_any_instance_of(Spree::Payment).to receive(:void_transaction!) { raise StandardError}
            end

            it "returns generic message" do
              do_post
              expect(flash[:error]).to eq Spree.t('ccavenue.refund_api_call_failed')
            end
          end

        end
      end

      context "when the order is changed" do
        before do
          allow(Spree::Ccavenue::Transaction).to receive(:find).and_return(changed_ccavenue_transaction)
          expect(controller).to receive(:void_payment).and_return(true)
        end

        it 'redirects to checkout payment page' do
          do_post
          expect(response).to redirect_to spree.checkout_state_path('payment')
          expect(flash[:error]).to eq(Spree.t('ccavenue.checkout_payment_error'))
        end
      end
    end

    context "when payment is aborted at ccavenue" do
      before do
        expect(controller).to receive(:current_order).at_least(:once).and_return(order)
        allow(Spree::Ccavenue::Transaction).to receive(:find).and_return(aborted_ccavenue_transaction)
        expect(order).to receive(:next).and_raise
        expect(controller).to receive(:out_of_stock_error).and_return(false)
        do_post
      end

      it 'redirects to checkout payment page' do
        expect(response).to redirect_to spree.checkout_state_path('payment')
      end
    end

    context "when payment fails at ccavenue" do
      before do
        expect(controller).to receive(:current_order).at_least(:once).and_return(order)
        allow(Spree::Ccavenue::Transaction).to receive(:find).and_return(failed_ccavenue_transaction)
        expect(order).to receive(:next).and_raise
        expect(controller).to receive(:out_of_stock_error).and_return(false)
        do_post
      end

      it 'redirects to checkout payment page' do
        expect(response).to redirect_to spree.checkout_state_path('payment')
      end

    end
  end
end
