describe CcavenueApi::Responses::RefundResponse do

  subject { CcavenueApi::Responses::RefundResponse }

  let(:success_refund_response) { { "refund_status" => 0 } }
  let(:fail_refund_response) { { "error_code" => "51309", "reason" => 'failed refund', "refund_status" => 1 } }
  let(:bad_refund_response) { { "refund_status" => nil } }

  describe "#build_from_response" do
    it "parses successful refund response properly" do
      expect(subject.build_from_response(success_refund_response)).to eq({ request_successful: true })
    end
    it "parses failed refund response properly" do
      expect(subject.build_from_response(fail_refund_response)).to include({ request_successful: false,
                                                                             error_code: fail_refund_response['error_code'],
                                                                             reason: fail_refund_response['reason'] })
    end
    it "parses a bad refund response properly" do
      expect(subject.build_from_response(bad_refund_response)).to include({ :api_status => :failed,
                                                                            :reason => Spree.t("ccavenue.api_response_parse_failed")})
    end
  end

  describe "#successful?" do
    let(:successful_args) { { http_status: :success, api_status: :success, request_successful: true } }
    context "when some error" do
      it "returns false when http_status is failed" do
        expect(subject.new(successful_args.merge({ http_status: :failed })).successful?).to be(false)
      end
      it "returns false when api_status is failed" do
        expect(subject.new(successful_args.merge({ api_status: :failed })).successful?).to be(false)
      end
      it "returns false when status_count is 0" do
        expect(subject.new(successful_args.merge({ request_successful: false })).successful?).to be(false)
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

