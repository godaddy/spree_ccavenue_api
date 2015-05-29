describe CcavenueApi::Response do

  let(:successful_http_payload) { {"status" => "0", "enc_response" => "1234"} }
  let(:failed_http_payload) { {"status" => "1", "enc_response" => "1234"} }
  let(:crypter) { CcavenueApi::Crypter.new('123') }
  let(:success_cancel_response) { {"Order_Result" => {"success_count" => 0}} }
  let(:fail_cancel_response) { {"Order_Result" => {"success_count" => "1", "failed_List" => {"failed_order" => {"reason" => 'failed cancel'}}}} }
  let(:fail_cancel_response2) { {"Order_Result" => {"success_count" => "1", "failed_List" => {"failed_order" => [{"reason" => 'failed cancel'}]}}} }
  let(:success_refund_response) { {"Refund_Order_Result" => {"refund_status" => 0}} }
  let(:fail_refund_response) { {"Refund_Order_Result" => {"refund_status" => "1", "reason" => 'failed refund'}} }
  let(:success_order_response) {  {"Order_Status_Result" => { "status" => 0, "order_status" => "0", "order_status_date_time" => '123' }} }
  let(:fail_order_response) { {"Order_Status_Result" => { "status" => 1, "order_status" => "1", "order_status_date_time" => '123', "error_desc" => "order status failed" }} }
  let(:order_status_missing_messages) { ['Providing Reference_No/Order No is mandatory',
                                         'Providing Reference number/Order Number is mandatory',
                                         'Providing Reference number/Order Number is mandatory.']
                                      }

  describe "#failed_http_request" do
    it "returns a CcavenueApi::Response object" do
      expect(CcavenueApi::Response.failed_http_request(double, double)).to be_kind_of(CcavenueApi::Response)
    end
    it "the returned object indicates fail" do
      expect(CcavenueApi::Response.failed_http_request(double, double).success?).to eq(false)
    end
  end
  describe "#successful_http_request" do
    before do
      allow_any_instance_of(CcavenueApi::Crypter).to receive(:decrypt).and_return(double('decrypted_response'))
      allow(ActiveSupport::JSON).to receive(:decode).and_return(double)
      allow(CcavenueApi::Response).to receive(:build_from_response).and_return({})
    end
    it "returns a CcavenueApi::Response object" do
      expect(CcavenueApi::Response.successful_http_request(successful_http_payload, crypter)).to be_kind_of(CcavenueApi::Response)
    end
    it "the returned object indicates success" do
      expect(CcavenueApi::Response.successful_http_request(successful_http_payload, crypter).success?).to eq(true)
    end
  end

  describe "#build_from_response" do
    it "parses successful cancel response properly" do
      expect(CcavenueApi::Response.build_from_response(success_cancel_response)).to eq({success_count: 0})
    end
    it "parses failed cancel response properly" do
      expect(CcavenueApi::Response.build_from_response(fail_cancel_response)).to eq({success_count: 1, reason: 'failed cancel'})
    end
    it "parses failed cancel response 2 properly" do
      expect(CcavenueApi::Response.build_from_response(fail_cancel_response2)).to eq({success_count: 1, reason: 'failed cancel'})
    end
    it "parses successful refund response properly" do
      expect(CcavenueApi::Response.build_from_response(success_refund_response)).to eq({refund_status: :success})
    end
    it "parses failed refund response properly" do
      expect(CcavenueApi::Response.build_from_response(fail_refund_response)).to eq({refund_status: :failed, reason: "failed refund"})
    end
    it "parses successful order status response properly" do
      expect(CcavenueApi::Response.build_from_response(success_order_response)).to eq({:request_status=>:success, :order_status=>:success, :order_status_date_time=>"123"})
    end
    it "parses failed order status response properly" do
      expect(CcavenueApi::Response.build_from_response(fail_order_response)).to eq({:request_status=>:failed, :reason=>"order status failed", :order_status=>:failed, :order_status_date_time=>"123"})
    end
  end


  describe "#success?" do
    it "returns true when http_status and api_status both are success" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success).success?).to eq(true)
    end
    it "returns false when http_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :failed, :api_status => :success).success?).to eq(false)
    end
    it "returns false when api_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :failed).success?).to eq(false)
    end
    it "return true when request_status is not blank and is a success" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :request_status => :success).success?).to eq(true)
    end
    it "return false when request_status is not blank and is a fail" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :failed, :request_status => :failed).success?).to eq(false)
    end
  end

  describe "#cancel_successful?" do
    it "returns true when http_status and api_status both are success" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :success_count => 1).cancel_successful?).to eq(true)
    end
    it "returns false when http_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :failed, :api_status => :success, :success_count => 1).cancel_successful?).to eq(false)
    end
    it "returns false when api_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :failed, :success_count => 1).cancel_successful?).to eq(false)
    end
    it "returns false when success_count is missing" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success).cancel_successful?).to eq(false)
    end
    it "returns true when success_count is greater than 0" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :success_count => 1).cancel_successful?).to eq(true)
    end
    it "returns false when success_count is less than 1" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :success_count => 0).cancel_successful?).to eq(false)
    end
  end

  describe "#refund_successful?" do
    it "returns true when http_status and api_status both are success" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :refund_status => :success).refund_successful?).to eq(true)
    end
    it "returns false when http_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :failed, :api_status => :success, :refund_status => :success).refund_successful?).to eq(false)
    end
    it "returns false when api_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :failed, :refund_status => :success).refund_successful?).to eq(false)
    end
    it "returns false when refund_status is missing" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success).refund_successful?).to eq(false)
    end
    it "returns false when refund_status is 1 (fail)" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :refund_status => :failed).refund_successful?).to eq(false)
    end
    it "returns true when refund_status is 0 (success)" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :refund_status => :success).refund_successful?).to eq(true)
    end
  end

  describe "#void_successful?" do
    it "returns true when http_status and api_status both are success and the cancel call has succeeded" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :success_count   => 1).void_successful?).to eq(true)
    end
    it "returns true when http_status and api_status both are success and the refund call has succeeded" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :refund_status => :success).void_successful?).to eq(true)
    end
    it "returns false when http_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :failed, :api_status => :success, :refund_status => :success).void_successful?).to eq(false)
    end
    it "returns false when api_status is false" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :failed, :refund_status => :success).void_successful?).to eq(false)
    end
    it "returns false when success_count && refund_status are missing" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success).void_successful?).to eq(false)
    end
    it "returns true when success_count is 1 or more (cancel success)" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :success_count => 1).void_successful?).to eq(true)
    end
    it "returns true when success_count is 0 (cancel fail) but refund succeeds" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :success_count => 0, :refund_status => :success).void_successful?).to eq(true)
    end
    it "returns false when both cancel and refund fail" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :success_count => 0, :refund_status => :failed).void_successful?).to eq(false)
    end
  end

  describe "#credentials_valid?" do
    it "returns true when http_status and api_status both are success and call has succeeded (in its perverted sense)" do
      order_status_missing_messages.each do |message|
        expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :reason => message).credentials_valid?).to eq(true)
      end
    end
    it "returns false when http_status is false" do
      order_status_missing_messages.each do |message|
        expect(CcavenueApi::Response.new(:http_status => :failed, :api_status => :success, :reason => message).credentials_valid?).to eq(false)
      end
    end
    it "returns false when api_status is false" do
      order_status_missing_messages.each do |message|
        expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :failed, :reason => message).credentials_valid?).to eq(false)
      end
    end
    it "returns false when reason is missing" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success).credentials_valid?).to eq(false)
    end
    it "returns false when reason is different" do
      expect(CcavenueApi::Response.new(:http_status => :success, :api_status => :success, :reason => '123').credentials_valid?).to eq(false)
    end


  end
end
