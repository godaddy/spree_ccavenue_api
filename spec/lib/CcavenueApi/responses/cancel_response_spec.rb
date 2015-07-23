describe CcavenueApi::Responses::CancelResponse do

  subject { CcavenueApi::Responses::CancelResponse }

  let(:success_cancel_response) { { "success_count" => 1 } }
  let(:failed_order_details) { { "error_code" => "51304", "reason" => 'failed cancel' } }
  let(:fail_cancel_response) { { "success_count" => 0, "failed_List" => [failed_order_details] } }
  let(:bad_cancel_response) { { "success_count" => nil, "failed_List" => [failed_order_details] } }

  describe "#build_from_response" do
    it "parses successful cancel response properly" do
      expect(subject.build_from_response(success_cancel_response)).to eq({ request_successful: true })
    end
    it "parses failed cancel response properly" do
      expect(subject.build_from_response(fail_cancel_response)).to eq({ request_successful: false,
                                                                        error_code:         failed_order_details['error_code'],
                                                                        reason:             failed_order_details['reason'] })
    end
    it "parses a bad cancel response properly" do
      expect(subject.build_from_response(bad_cancel_response)).to include({ :api_status => :failed,
                                                                            :reason     => Spree.t("ccavenue.api_response_parse_failed") })
    end
  end

  describe "#successful?" do
    let(:successful_args) { { http_status: :success, api_status: :success, request_successful: true}}
    context "when some error" do
      it "returns false when http_status is failed" do
        expect(subject.new(successful_args.merge({http_status: :failed})).successful?).to be(false)
      end
      it "returns false when api_status is failed" do
        expect(subject.new(successful_args.merge({ api_status: :failed })).successful?).to be(false)
      end
      it "returns false when status_count is 0" do
        expect(subject.new(successful_args.merge({ request_successful: false })).successful?).to be(false)
      end
    end
    context "when no error" do
      it "returns true" do
        expect(subject.new(successful_args).successful?).to be(true)
      end
    end
  end


end

