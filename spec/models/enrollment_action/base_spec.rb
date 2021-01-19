require "rails_helper"

describe EnrollmentAction::Base do
  describe "#publish_edi" do
    let(:trading_partner_edi_publisher) { instance_double(Publishers::TradingPartnerEdi) }
    let(:amqp_connection) { double }
    let(:event_xml) { double }
    let(:hbx_enrollment_id) { double }
    let(:employer_id) { double }
    let(:cv_publish_errors_hash) { double }
    let(:cv_publish_errors) { double(:to_hash => cv_publish_errors_hash) }

    subject { EnrollmentAction::Base.new(nil, nil) }

    before :each do
      allow(Publishers::TradingPartnerEdi).to receive(:new).with(amqp_connection, event_xml).and_return(trading_partner_edi_publisher)
      allow(trading_partner_edi_publisher).to receive(:errors).and_return(cv_publish_errors)
    end

    describe "which fails to publish trading partner edi" do

      before :each do
        allow(trading_partner_edi_publisher).to receive(:publish).and_return(false)
      end

      it "returns false" do
        publish_status, _publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
        expect(publish_status).to be_falsey
      end

      it "returns the publishing errors" do
        _publish_status, publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
        expect(publish_errors).to eq cv_publish_errors_hash
      end
    end

    describe "which publishes trading partner edi" do
      let(:legacy_cv_publisher) { double }

      before :each do
        allow(trading_partner_edi_publisher).to receive(:publish).and_return(true)
        allow(Publishers::TradingPartnerLegacyCv).to receive(:new).with(amqp_connection, event_xml, hbx_enrollment_id, employer_id).and_return(legacy_cv_publisher)
      end

      describe "but fails to publish the legacy cv" do
        let(:legacy_cv_errors_hash) { double }
        let(:legacy_cv_errors) { double(:to_hash => legacy_cv_errors_hash) }
        

        before :each do
          allow(legacy_cv_publisher).to receive(:publish).and_return(false)
          allow(legacy_cv_publisher).to receive(:errors).and_return(legacy_cv_errors)
        end

        it "returns false" do
          publish_status, _publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
          expect(publish_status).to be_falsey
        end

        it "returns the publishing errors" do
          _publish_status, publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
          expect(publish_errors).to eq legacy_cv_errors_hash
        end
      end

      describe "and publishes the legacy cv" do
        before :each do
          allow(legacy_cv_publisher).to receive(:publish).and_return(true)
        end

        it "returns true" do
          publish_status, _publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
          expect(publish_status).to be_truthy
        end
      end
    end


    describe "publish_edi with options send_to_carrier & send_to_payment_processor" do

      let!(:legacy_cv_publisher) { double }

      context "send_to_carrier = true & send_to_payment_processor = false" do

        before :each do
          allow(trading_partner_edi_publisher).to receive(:publish).and_return(true)
          allow(Publishers::TradingPartnerLegacyCv).to receive(:new).with(amqp_connection, event_xml, hbx_enrollment_id, employer_id).and_return(legacy_cv_publisher)
        end

        it "should only publish to carrier" do
          publish_status, _publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id, true, false)
          expect(publish_status).to be_truthy
          expect(trading_partner_edi_publisher).to receive(:publish).and_return(true)
          expect(trading_partner_edi_publisher.publish).to eq true
          expect(legacy_cv_publisher).not_to receive(:publish)
        end
      end


      context "send_to_carrier = false & send_to_payment_processor = true" do

        before :each do
          allow(Publishers::TradingPartnerLegacyCv).to receive(:new).with(amqp_connection, event_xml, hbx_enrollment_id, employer_id).and_return(legacy_cv_publisher)
          allow(legacy_cv_publisher).to receive(:publish).and_return(true)
        end

        it "should only publish to payment processor" do
          publish_status, _publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id, false, true)
          expect(publish_status).to be_truthy
          expect(trading_partner_edi_publisher).not_to receive(:publish)
          expect(legacy_cv_publisher).to receive(:publish).and_return(true)
          expect(legacy_cv_publisher.publish).to eq true
        end
      end


      context "send_to_carrier = true & send_to_payment_processor = true" do

        before :each do
          allow(trading_partner_edi_publisher).to receive(:publish).and_return(true)
          allow(Publishers::TradingPartnerLegacyCv).to receive(:new).with(amqp_connection, event_xml, hbx_enrollment_id, employer_id).and_return(legacy_cv_publisher)
          allow(legacy_cv_publisher).to receive(:publish).and_return(true)
        end

        it "should publish to carrier and payment processor" do
          publish_status, _publish_errors = subject.publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id, true, true)
          expect(publish_status).to be_truthy
          expect(trading_partner_edi_publisher).to receive(:publish)
          expect(legacy_cv_publisher).to receive(:publish)
          expect(legacy_cv_publisher.publish).to eq true
          expect(trading_partner_edi_publisher.publish).to eq true
        end
      end
    end
  end
end
