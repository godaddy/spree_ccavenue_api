describe CcavenueApi::SDK do
  let(:merchant_id) { '9999' }
  let(:enc_key) { '8728jdjdd' }
  let(:access_code) { '3421' }
  let(:transaction_url) { 'https://test.foo/transact' }
  let(:api_url) { 'https://test.foo/api' }
  let(:sdk_args) { {
    :merchant_id     => merchant_id,
    :encryption_key  => enc_key,
    :access_code     => access_code,
  } }
  let(:sdk) { CcavenueApi::SDK.new(sdk_args.merge({:transaction_url => transaction_url,
                                                   :api_url         => api_url
                                                  })) }
  let(:test_sdk) { CcavenueApi::SDK.new(sdk_args.merge(:test_mode => true)) }
  let(:prod_sdk) { CcavenueApi::SDK.new(sdk_args.merge(:test_mode => false)) }
  let(:order) { FactoryGirl.create(:order_with_totals) }
  let(:cc_transaction) { double('ccavenue_transaction', :id => 123, :tracking_id => '1234', :amount => 123) }
  let(:crypter) { double('crypter') }

  describe "URLS" do
    it "has default versions of urls" do
      expect(CcavenueApi::SDK.default_transaction_url).to be
      expect(CcavenueApi::SDK.default_api_url).to be
      expect(CcavenueApi::SDK.default_signup_url).to be
    end
    it "has production versions of urls" do
      expect(CcavenueApi::SDK.production_transaction_url).to be
      expect(CcavenueApi::SDK.production_api_url).to be
      expect(CcavenueApi::SDK.production_signup_url).to be
    end
  end

  describe "#initialize" do
    it "initializes the urls appropriately" do
      expect(sdk.transaction_url).to eq(transaction_url)
      expect(sdk.api_url).to eq(api_url)
      expect(sdk.signup_url).to eq(CcavenueApi::SDK.production_signup_url)
    end
    it "initialzes the crypter" do
      expect(sdk.crypter).to be_kind_of(CcavenueApi::Crypter)
    end
    context "in test mode" do
      it "initializes the urls correctly" do
        expect(test_sdk.transaction_url).to eq(CcavenueApi::SDK.default_transaction_url)
        expect(test_sdk.api_url).to eq(CcavenueApi::SDK.default_api_url)
        expect(test_sdk.signup_url).to eq(CcavenueApi::SDK.default_signup_url)
      end
    end
    context "in production mode" do
      it "initializes the urls correctly" do
        expect(prod_sdk.transaction_url).to eq(CcavenueApi::SDK.production_transaction_url)
        expect(prod_sdk.api_url).to eq(CcavenueApi::SDK.production_api_url)
        expect(prod_sdk.signup_url).to eq(CcavenueApi::SDK.production_signup_url)
      end
    end
  end

  describe "#build_ccavenue_checkout_transaction" do
    it "creates a new transaction from order" do
      expect(sdk.build_ccavenue_checkout_transaction(order)).to be_kind_of(Spree::Ccavenue::Transaction)
    end
    it "initializes transaction from order" do
      expect(sdk.build_ccavenue_checkout_transaction(order).amount).to eq(order.total)
      expect(sdk.build_ccavenue_checkout_transaction(order).currency).to eq(order.currency)
    end
  end

  describe "#build_encrypted_request" do
    let(:order_data) { {dummy: 'foo'} }
    it "invokes crypter.crypt to encrypt the request" do
      expect(sdk).to receive(:crypter).and_return(crypter)
      expect(crypter).to receive(:encrypt).and_return(encResp = '123456')
      expect(sdk.build_encrypted_request(cc_transaction, order_data)).to eq(encResp)
    end
  end

  describe "#update_transaction_from_redirect_response" do
    before do
      expect(sdk).to receive(:crypter).and_return(crypter)
    end
    let(:transaction) { Spree::Ccavenue::Transaction.new(:amount => 100.0, :currency => :USD) }
    it "invokes crypter#decrypt" do
      expect(crypter).to receive(:decrypt).and_return(decResp = '123456')
      sdk.update_transaction_from_redirect_response(transaction, double('encrypted_response'))
    end
    it "updates the transaction" do
      expect(crypter).to receive(:decrypt).and_return('123')
      decodedResp = {'order_status' => 'Success', 'card_name' => 'card_name_val',
                     'order_id'     => 'order_id_val', 'tracking_id' => 'tracking_id_val', 'amount' => 100}
      expect(Rack::Utils).to receive(:parse_nested_query).and_return(decodedResp)
      expect(transaction).to receive(:update_attributes!).with(
                               :auth_desc             => decodedResp['order_status'],
                               :card_category         => decodedResp['card_name'],
                               :ccavenue_order_number => decodedResp['order_id'],
                               :tracking_id           => decodedResp['tracking_id'],
                               :ccavenue_amount       => decodedResp['amount']
                             )
      sdk.update_transaction_from_redirect_response(transaction, '123')
    end
  end

  describe "#validate_merchant_credentials" do
    let(:new_access_code) { double('new access code') }
    let(:new_encryption_key) { double('new encryption key') }
    let(:req_builder) { double('req builder') }
    before do
      expect(sdk).to receive(:api_request).and_return(double('api_response', :credentials_valid? => true))
      expect(sdk).to receive(:req_builder).and_return(req_builder)
      allow(req_builder).to receive(:order_status).and_return('123')
    end
    it "stashes and restores the old creds back" do
      before_access_code, before_encryption_key = sdk.access_code, sdk.encryption_key
      sdk.validate_merchant_credentials(new_access_code, new_encryption_key)
      expect(sdk.access_code).to eq(before_access_code)
      expect(sdk.encryption_key).to eq(before_encryption_key)
    end

    it "invokes init_from_merchant_credentials to initialize the sdk with new values" do
      expect(sdk).to receive(:init_from_merchant_credentials).with(new_access_code, new_encryption_key)
      sdk.validate_merchant_credentials(new_access_code, new_encryption_key)
    end

    it "invokes req_builder to build the order_status data" do
      expect(req_builder).to receive(:order_status)
      sdk.validate_merchant_credentials(new_access_code, new_encryption_key)
    end
  end

  describe "#void!" do
    let(:success_cancel_res) { CcavenueApi::Response.new(http_status: :success, api_status: :success, success_count: 1) }
    let(:success_refund_res) { CcavenueApi::Response.new(http_status: :success, api_status: :success, refund_status: :success) }
    let(:fail_cancel_res) { CcavenueApi::Response.new(http_status: :success, api_status: :success, success_count: 0) }
    before do
      allow(Spree::Ccavenue::Transaction).to receive(:find_by_tracking_id).and_return(cc_transaction)
    end
    it "calls cancel! and is successful when cancel! is successful" do
      expect(sdk).to receive(:cancel!).and_return(success_cancel_res).at_least(:once)
      expect(sdk.void!(double).cancel_successful?).to eq(true)
      expect(sdk.void!(double).void_successful?).to eq(true)
    end
    it "calls refund! when cancel fails and is successful when refund! is successful" do
      expect(sdk).to receive(:cancel!).and_return(fail_cancel_res).at_least(:once)
      expect(sdk).to receive(:refund!).and_return(success_refund_res).at_least(:once)
      expect(sdk.void!(cc_transaction).refund_successful?).to eq(true)
      expect(sdk.void!(cc_transaction).void_successful?).to eq(true)
    end
  end

  describe "#cancel!" do
    let(:cancel_res) { CcavenueApi::Response.new(http_status: :success, api_status: :success, success_count: 1) }
    it "invokes build_and_invoke_api_request and returns the response from it" do
      expect(sdk).to receive(:build_and_invoke_api_request).and_return(cancel_res)
      expect(sdk.cancel!(cc_transaction)).to eq(cancel_res)
    end
    it "invokes req_builder cancel_order" do
      allow(sdk).to receive(:api_request).and_return(cancel_res)
      expect(sdk).to receive(:req_builder).and_return(req_builder=double('req builder', cancel_order: '123'))
      expect(sdk.cancel!(cc_transaction)).to eq(cancel_res)
    end
  end

  describe "#refund!" do
    let(:refund_res) { CcavenueApi::Response.new(http_status: :success, api_status: :success, refund_status: 0) }
    it "invokes build_and_invoke_api_request and returns the response from it" do
      expect(sdk).to receive(:build_and_invoke_api_request).and_return(refund_res)
      expect(sdk.refund!(cc_transaction)).to eq(refund_res)
    end
    it "invokes req_builder refund order" do
      allow(sdk).to receive(:api_request).and_return(refund_res)
      expect(sdk).to receive(:req_builder).and_return(req_builder=double('req builder', refund_order: '123'))
      expect(sdk.refund!(cc_transaction)).to eq(refund_res)
    end
  end

  describe "#crypter" do
    let(:sdk_crypter) { CcavenueApi::SDK.new(:merchant_id     => merchant_id,
                                             :access_code     => access_code,
                                             :transaction_url => transaction_url,
                                             :api_url         => api_url) }

    it "return an object of type CcavenueApi::Crypter" do
      allow(sdk_crypter).to receive(:encryption_key).and_return('123')
      expect(sdk_crypter.crypter).to be_kind_of(CcavenueApi::Crypter)
    end
    it "returns nil when encryption_key is not set" do
      expect(sdk_crypter.crypter).to eq(nil)
    end
  end

  describe "#req_builder" do
    let(:sdk_builder) { CcavenueApi::SDK.new(:merchant_id     => merchant_id,
                                             :transaction_url => transaction_url,
                                             :api_url         => api_url) }

    it "return an object of type CcavenueApi::Crypter" do
      allow(sdk_builder).to receive(:access_code).and_return('123')
      allow(sdk_builder).to receive(:encryption_key).and_return('123')
      expect(sdk_builder.req_builder).to be_kind_of(CcavenueApi::RequestBuilder)
    end
    it "returns nil when encryption_key is not set" do
      expect(sdk_builder.req_builder).to eq(nil)
    end
    it "returns nil when access_code is not set" do
      expect(sdk_builder.req_builder).to eq(nil)
    end
  end

  describe "#init_from_merchant_credentials" do
    let(:new_access_code) { '123' }
    let(:new_encryption_key) { '123' }
    before do
      expect(sdk.access_code).to_not eq(new_access_code)
      expect(sdk.encryption_key).to_not eq(new_encryption_key)
      @current_crypter, @current_req_builder = sdk.crypter, sdk.req_builder
      sdk.send(:init_from_merchant_credentials, new_access_code, new_encryption_key)
    end
    it "sets the access_code to new access_code" do
      expect(sdk.access_code).to eq(new_access_code)
    end
    it "sets the encryption_key to new encryption_key" do
      expect(sdk.encryption_key).to eq(new_encryption_key)
    end
    it "reinitializes the crypter with the new values" do
      expect(sdk.crypter).to be_kind_of(CcavenueApi::Crypter)
      expect(sdk.crypter).to_not eq(@current_crypter)
    end
    it "reinitializes the request builder with the new values" do
      expect(sdk.req_builder).to be_kind_of(CcavenueApi::RequestBuilder)
      expect(sdk.req_builder).to_not eq(@current_req_builder)
    end
  end

  describe "#api_request" do
    [true, false].each do |forced_mode|
      it "invokes RestClient with appropriate arguments when test_mode is #{forced_mode}" do
        sdk_req = CcavenueApi::SDK.new(sdk_args.merge(:test_mode => forced_mode))
        allow(Rack::Utils).to receive(:parse_query).and_return(double)
        allow(sdk_req).to receive(:test_mode).and_return(forced_mode)
        allow(CcavenueApi::Response).to receive(:successful_http_request)
        args = {
          method:     :post,
          url:        sdk_req.api_url,
          payload:    payload = double('payload'),
          headers:    {'Accept' => 'application/json', :accept_encoding => 'gzip, deflate'},
          verify_ssl: !forced_mode
        }
        expect(::RestClient::Request).to receive(:execute).with(args).and_return(double('http response'))
        sdk_req.send(:api_request, payload)
      end
    end
    it "returns a CcavenueApi::Response" do
      http_response = {"status"=>"0", "enc_response"=>"123"}
      allow(::RestClient::Request).to receive(:execute).and_return(double)
      allow(Rack::Utils).to receive(:parse_query).and_return(http_response)
      allow(CcavenueApi::Response).to receive(:successful_http_request).and_return(cc_response = double('ccave res'))
      allow_any_instance_of(CcavenueApi::Crypter).to receive(:decrypt).and_return(double)
      expect(sdk.send(:api_request, double('payload'))).to eq(cc_response)
    end
    it "catches RestClient::RequestTimeout and returns a failed Response" do
      allow(::RestClient::Request).to receive(:execute).and_raise(RestClient::RequestTimeout)
      allow(CcavenueApi::Response).to receive(:failed_http_request).and_return(cc_response = double('ccave fail res'))
      expect(sdk.send(:api_request, double('payload'))).to eq(cc_response)
    end
    it "catches RestClient::Exception and returns a failed Response" do
      allow(::RestClient::Request).to receive(:execute).and_raise(RestClient::Exception)
      allow(CcavenueApi::Response).to receive(:failed_http_request).and_return(cc_response = double('ccave fail res'))
      expect(sdk.send(:api_request, double('payload'))).to eq(cc_response)
    end
    it "catches RuntimeError and returns a failed Response" do
      allow(::RestClient::Request).to receive(:execute).and_raise(RuntimeError)
      allow(CcavenueApi::Response).to receive(:failed_http_request).and_return(cc_response = double('ccave fail res'))
      expect(sdk.send(:api_request, double('payload'))).to eq(cc_response)
    end
  end

end
