require 'spec_helper'
describe Spree::CcavenueController, :type => :controller do
  # stub_authorization!

  let(:order) { FactoryGirl.create(:order_with_totals) }

  let(:routes) { Spree::Core::Engine.routes.url_helpers }

  let!(:ccavenue) { Spree::Gateway::Ccavenue.create!(:name => 'ccavenue') }

  let(:merchant_id) { '9999' }
  let(:enc_key) { '8728jdjdd' }
  let(:access_code) { '3421' }
  let(:transaction_url) { 'http://1234' }
  let(:dummy_encrypted_val) { 'aaabbbb' }
  let(:ccavenue_provider) { double('provider',
                                   merchant_id:     merchant_id,
                                   access_code:     access_code,
                                   encryption_key:  enc_key,
                                   transaction_url: transaction_url
  ) }
  let(:ccavenue_transaction) { double('ccave_transaction', id: 123, tracking_id: '123') }
  let(:ccavenue_response) { double('ccavnue_response') }

  let(:encResp) { '123' }

  before do
    order.state = 'payment'
    order.save!
  end

  context '#show' do
    context 'successful #show' do
      before do
        allow(controller).to receive(:current_order).at_least(:once).and_return(order)
        allow(controller).to receive(:ccavenue_redirect_params).and_return({})
      end
      it 'renders show' do
        get :show, :id => ccavenue.id, :use_route => 'spree'
        expect(response).to render_template("show")
      end
      it "creates a transaction" do
        expect { get :show, :id => ccavenue.id, :use_route => 'spree' }.to change { Spree::Ccavenue::Transaction.count }.by(1)
      end
    end

    context "when current_order is nil" do
      before do
        allow(controller).to receive(:current_order).at_least(:once).and_return(nil)
        allow(controller).to receive(:current_spree_user).at_least(:once).and_return(nil)
        get :show, :id => ccavenue.id, :use_route => 'spree'
      end
      it "redirects to cart" do
        expect(response).to redirect_to routes.cart_path
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
        get :show, :id => ccavenue.id, :use_route => 'spree'
        expect(assigns[:redirect_params]).to eq({:merchant_id     => merchant_id,
                                                 :access_code     => access_code,
                                                 :transaction_url => transaction_url,
                                                 :enc_request     => dummy_encrypted_val})
      end
    end

  end

  context '#callback' do
    def do_post
      post :callback, :id  => ccavenue.id,
           :transaction_id => ccavenue_transaction.id,
           :order_id       => order.id,
           :encResp        => encResp,
           :use_route      => 'spree'
    end

    before do
      allow(controller).to receive(:ccavenue_transaction).and_return(ccavenue_transaction)
      allow(controller).to receive(:provider).at_least(:once).and_return(ccavenue_provider)
      allow(ccavenue_provider).to receive(:update_transaction_from_redirect_response).and_return(nil)
    end

    context "on successful ccavenue transaction" do
      before do
        expect(controller).to receive(:current_order).at_least(:once).and_return(order)
        expect(ccavenue_transaction).to receive(:success?).and_return(true)
      end
      context "when the order is successfully completed" do
        before do
          expect(order).to receive(:insufficient_stock_lines).and_return(false)
          expect(order).to receive(:payments).and_return(double('payments', create!: double('payment')))
          expect(order).to receive(:next).and_return(nil)
          expect(order).to receive(:complete?).and_return(true)
        end
        it 'redirects to order completion route' do
          do_post
          expect(response).to redirect_to routes.order_path(order)
          expect(flash[:notice]).to eq(Spree.t('ccavenue.order_processed_successfully'))
        end
      end

      context "when the inventory goes low" do
        before do
          expect(order).to receive(:insufficient_stock_lines).and_return(true)
        end

        it "redirects to the cart with a flash message" do
          allow(controller).to receive(:void_payment).and_return(true)
          do_post
          expect(response).to redirect_to routes.cart_path
          expect(flash[:error]).to eq(Spree.t('ccavenue.checkout_low_inventory_after_payment_warning'))
        end

        it "invokes the void api call to ccavenue" do
          expect(ccavenue_provider).to receive(:void!).and_return(double('void_response', :void_successful? => true))
          do_post
          expect(response).to redirect_to routes.cart_path
        end
      end
    end

    context "when current_order is nil" do
      before do
        expect(controller).to receive(:current_order).at_least(:once).and_return(nil)
      end

      it "redirects to cart with the correct flash message" do
        do_post
        expect(response).to redirect_to routes.cart_path
        expect(flash[:error]).to eq(Spree.t('ccavenue.checkout_payment_error'))
      end
    end

    context 'when payment is aborted at ccavenue' do
      before do
        expect(controller).to receive(:current_order).at_least(:once).and_return(order)
        expect(ccavenue_transaction).to receive(:success?).and_return(false)
        expect(ccavenue_transaction).to receive(:failed?).and_return(false)
        expect(ccavenue_transaction).to receive(:aborted?).and_return(true)
        do_post
      end

      it 'redirects to checkout payment page' do
        expect(response).to redirect_to routes.checkout_state_path('payment')
      end
    end

    context 'when payment fails at ccavenue' do
      before do
        expect(controller).to receive(:current_order).at_least(:once).and_return(order)
        expect(ccavenue_transaction).to receive(:success?).and_return(false)
        expect(ccavenue_transaction).to receive(:failed?).and_return(true)
        do_post
      end

      it 'redirects to checkout payment page' do
        expect(response).to redirect_to routes.checkout_state_path('payment')
      end

    end
  end
end
