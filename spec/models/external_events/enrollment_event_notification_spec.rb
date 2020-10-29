require "rails_helper"

describe ::ExternalEvents::EnrollmentEventNotification, :dbclean => :after_each do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let :enrollment_event_notification do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  describe "#drop_if_bogus_plan_year!" do
    subject { enrollment_event_notification.drop_if_bogus_plan_year! }

    context 'of a notification without a bogus plan year' do
      before { allow(enrollment_event_notification).to receive('has_bogus_plan_year?').and_return(false) }

      it 'returns false if has_bogus_plan_year is false' do
        expect(subject).to be_falsey
      end
    end

    context 'of a notification with a bogus plan year' do
      let(:result_publisher) { double :drop_bogus_plan_year! => true }

      before do
        allow(enrollment_event_notification).to receive('has_bogus_plan_year?').and_return(true)
        allow(enrollment_event_notification).to receive('response_with_publisher').and_yield(result_publisher)
      end

      it 'drops bogus plan year if has_bogus_plan_year is true' do
        subject
        expect(result_publisher).to have_received('drop_bogus_plan_year!')
      end
    end

    describe "has_bogus_plan_year?" do

      let(:start_date) {Date.today.beginning_of_month}
      let(:end_date) {Date.today.beginning_of_month + 1.year - 1.day}

      let(:plan_year) { FactoryGirl.create(:plan_year, start_date: start_date, end_date: end_date)}

      let(:employer) { FactoryGirl.create(:employer, plan_years:[plan_year])}
      let(:employer_link) { double(:id => "1234") }
      let(:enrollee) {double}
      let(:policy_cv) { instance_double(::Openhbx::Cv2::Policy) }


      before do
        allow(enrollment_event_notification).to receive(:is_shop?).and_return(true)
        allow(enrollment_event_notification).to receive(:policy_cv).and_return(policy_cv)
      end

      context 'when enrollee start date falls in b/w plan year dates' do

        it 'returns false' do
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:find_employer).with(policy_cv).and_return(employer)
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:extract_subscriber).with(policy_cv).and_return(enrollee)
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:extract_enrollee_start).with(enrollee).and_return(start_date)
          expect(enrollment_event_notification.has_bogus_plan_year?).to be_falsey
        end
      end

      context 'when enrollee start date falls outside plan year dates with termination event' do
        let(:enrollee_start_date) {Date.today.beginning_of_month + 1.month}
        let(:end_date) {Date.today.beginning_of_month}
        let(:plan_year) { FactoryGirl.create(:plan_year, start_date: start_date, end_date: end_date)}
        let(:employer) { FactoryGirl.create(:employer, plan_years:[plan_year])}

        before do
          allow(enrollment_event_notification).to receive(:is_termination?).and_return(true)
        end

        it 'returns false' do
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:find_employer).with(policy_cv).and_return(employer)
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:extract_subscriber).with(policy_cv).and_return(enrollee)
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:extract_enrollee_start).with(enrollee).and_return(enrollee_start_date)
          expect(enrollment_event_notification.has_bogus_plan_year?).to be_falsey
        end
      end

      context 'when enrollee start date falls outside plan year dates with no termination event' do
        let(:enrollee_start_date) {Date.today.beginning_of_month + 1.month}
        let(:end_date) {Date.today.beginning_of_month}
        let(:plan_year) { FactoryGirl.create(:plan_year, start_date: start_date, end_date: end_date)}
        let(:employer) { FactoryGirl.create(:employer, plan_years:[plan_year])}

        before do
          allow(enrollment_event_notification).to receive(:is_termination?).and_return(false)
        end

        it 'returns true' do
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:find_employer).with(policy_cv).and_return(employer)
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:extract_subscriber).with(policy_cv).and_return(enrollee)
          allow_any_instance_of(Handlers::EnrollmentEventXmlHelper).to receive(:extract_enrollee_start).with(enrollee).and_return(enrollee_start_date)
          expect(enrollment_event_notification.has_bogus_plan_year?).to be_truthy
        end
      end
    end
  end

  describe "#drop_if_bogus_term!" do
    subject { enrollment_event_notification.drop_if_bogus_term! }

    context 'of a notification without a bogus_termination' do
      it 'returns false' do
        expect(subject).to be_falsey
      end
    end

    context 'of a notification with a bogus termination' do
      let(:result_publisher) { double :drop_bogus_term! => true }

      before do
        enrollment_event_notification.instance_variable_set :@bogus_termination, true
        allow(enrollment_event_notification).to receive('response_with_publisher').and_yield(result_publisher)
      end

      it 'calls drops_bogus_term! on result_publisher' do
        subject
        expect(result_publisher).to have_received('drop_bogus_term!').with(enrollment_event_notification)
      end
    end
  end

  describe "#check_for_bogus_term_against" do
    let(:others) { spy Array.new([ other ]) }

    subject { enrollment_event_notification.check_for_bogus_term_against(others) }

    context 'of a non-termination event' do
      let(:other) { double }

      before do
        allow(enrollment_event_notification).to receive('is_termination?').and_return(false)
      end

      it 'returns nothing' do
        expect(subject).to be_nil
      end

      it 'does nothing' do
        subject
        expect(others).to_not have_received('each')
      end
    end

    context 'of a termination event' do
      before do
        allow(enrollment_event_notification).to receive('is_termination?').and_return(true)
      end

      context 'an enrollment with coverage starter' do
        let(:other) { double :is_coverage_starter? => true }

        it 'sets @bogus_termination to false' do
          expect(enrollment_event_notification.instance_variable_get(:@bogus_termination)).to be_falsey
        end
      end

      context 'an enrollment that is not coverage starter' do
        let(:other) { double :is_coverage_starter? => false }

        before { allow(enrollment_event_notification).to receive('existing_policy').and_return(nil) }

        it 'sets @bogus_termination to existing_policy.nil?' do
          subject
          expect(enrollment_event_notification).to have_received('existing_policy')
        end
      end
    end
  end

  describe "#edge_for" do
    let(:graph) { double 'graph' }
    let(:other) { instance_double(ExternalEvents::EnrollmentEventNotification, :hbx_enrollment_id => 1) }

    subject { enrollment_event_notification.edge_for(graph, other) }

    context 'when ordering by the submitted at time, and the starts are in reverse order, and the first is a term' do
      before do
        allow(enrollment_event_notification).to receive(:subscriber_start).and_return(2017)
        allow(other).to                         receive(:subscriber_start).and_return(2016)
        allow(other).to receive(:submitted_at_time).and_return(2)
        allow(enrollment_event_notification).to receive(:submitted_at_time).and_return(1)

        allow(other).to                         receive(:active_year).and_return(2017)
        allow(enrollment_event_notification).to receive(:active_year).and_return(2017)
        allow(enrollment_event_notification).to receive(:hbx_enrollment_id).and_return(2)
        allow(enrollment_event_notification).to receive(:is_termination?).and_return(true)
        allow(other).to receive(:is_termination?).and_return(false)
        allow(other).to receive(:hash).and_return(1)
        allow(enrollment_event_notification).to receive(:hash).and_return(1)
      end

      it 'orders by submitted time stamp instead of coverage start' do
        expect(graph).to receive(:add_edge).with(enrollment_event_notification, other)
        subject
      end
    end

    context 'other being the same enrollment' do
      before { allow(enrollment_event_notification).to receive('hbx_enrollment_id').and_return(1) }

      context 'when other is termination, and self is not' do
        before do
          allow(other).to                         receive(:is_termination?).and_return(true)
          allow(enrollment_event_notification).to receive(:is_termination?).and_return(false)
        end

        it 'adds edge to graph of enrollment_event_notification to other' do
          expect(graph).to receive('add_edge').with(enrollment_event_notification, other)
          subject
        end
      end

      context 'when other is not termination, and self is' do
        before do
          allow(other).to                         receive(:is_termination?).and_return(false)
          allow(enrollment_event_notification).to receive(:is_termination?).and_return(true)
        end

        it 'adds edge to graph of other to enrollment_event_notification' do
          expect(graph).to receive('add_edge').with(other, enrollment_event_notification)
          subject
        end
      end

      context 'other cases' do
        before do
          allow(other).to                         receive(:is_termination?).and_return(false)
          allow(enrollment_event_notification).to receive(:is_termination?).and_return(false)
        end

        it 'returns :ok' do
          expect(subject).to eql(:ok)
        end
      end
    end

    context 'enrollment_event_notification and other being different years' do
      before do
        allow(enrollment_event_notification).to receive('hbx_enrollment_id').and_return(2)
      end

      context 'and other being before enrollment_event_notification' do
        before do
          allow(other).to                         receive(:active_year).and_return(2016)
          allow(enrollment_event_notification).to receive(:active_year).and_return(2017)
        end

        it 'adds edge to graph of other to enrollment_event_notification' do
          expect(graph).to receive('add_edge').with(other, enrollment_event_notification)
          subject
        end
      end

      context 'and enrollment_event_notification being before other' do
        before do
          allow(other).to                         receive(:active_year).and_return(2017)
          allow(enrollment_event_notification).to receive(:active_year).and_return(2016)
        end

        it 'adds edge to graph of enrollment_event_notification to other' do
          expect(graph).to receive('add_edge').with(enrollment_event_notification, other)
          subject
        end
      end
    end

    context "subscriber_start is different" do
      before do
        allow(other).to receive(:submitted_at_time).and_return(1)
        allow(enrollment_event_notification).to receive(:submitted_at_time).and_return(1)
        allow(other).to                         receive(:active_year).and_return(2017)
        allow(enrollment_event_notification).to receive(:active_year).and_return(2017)
        allow(enrollment_event_notification).to receive('hbx_enrollment_id').and_return(2)
      end

      context 'and other is before enrollment_event_notification' do
        before do
          allow(other).to                         receive(:subscriber_start).and_return(2016)
          allow(enrollment_event_notification).to receive(:subscriber_start).and_return(2017)
        end

        it 'adds edge to graph of other to enrollment_event_notification' do
          expect(graph).to receive('add_edge').with(other, enrollment_event_notification)
          subject
        end
      end

      context 'and enrollment_event_notification is before other' do
        before do
          allow(other).to                         receive(:subscriber_start).and_return(2017)
          allow(enrollment_event_notification).to receive(:subscriber_start).and_return(2016)
        end

        it 'adds edge to graph of enrollment_event_notification to other' do
          expect(graph).to receive('add_edge').with(enrollment_event_notification, other)
          subject
        end
      end
    end


    context 'other scenarios like' do
      before do
        allow(other).to receive(:submitted_at_time).and_return(1)
        allow(enrollment_event_notification).to receive(:submitted_at_time).and_return(1)
        allow(other).to                         receive(:active_year).and_return(2017)
        allow(enrollment_event_notification).to receive(:active_year).and_return(2017)
        allow(other).to                         receive(:subscriber_start).and_return(2017)
        allow(enrollment_event_notification).to receive(:subscriber_start).and_return(2017)
        allow(enrollment_event_notification).to receive('hbx_enrollment_id').and_return(2)
      end

      context "when both other's and enrollment_event_notification's subscriber_end is nil" do
        before do
          allow(other).to                         receive(:subscriber_end).and_return(nil)
          allow(enrollment_event_notification).to receive(:subscriber_end).and_return(nil)
        end

        it 'returns :ok' do
          expect(subject).to eql(:ok)
        end
      end

      context "when other's subscriber_end is nil" do
        before do
          allow(other).to                         receive(:subscriber_end).and_return(nil)
          allow(enrollment_event_notification).to receive(:subscriber_end).and_return(1)
        end

        it 'adds edge to graph of enrollment_event_notification to other' do
          expect(graph).to receive('add_edge').with(enrollment_event_notification, other)
          subject
        end
      end

      context "when enrollment_event_notification's subscriber_end is nil" do
        before do
          allow(other).to                         receive(:subscriber_end).and_return(1)
          allow(enrollment_event_notification).to receive(:subscriber_end).and_return(nil)
        end

        it 'adds edge to graph of other to enrollment_event_notification' do
          expect(graph).to receive('add_edge').with(other, enrollment_event_notification)
          subject
        end
      end

      context "when enrollment_event_notification's subscriber_end is before other's" do
        before do
          allow(other).to                         receive(:subscriber_end).and_return(2)
          allow(enrollment_event_notification).to receive(:subscriber_end).and_return(1)
        end

        it 'adds edge to graph of enrollment_event_notification to other' do
          expect(graph).to receive('add_edge').with(enrollment_event_notification, other)
          subject
        end
      end

      context "when other's subscriber_end is before enrollment_event_notification's" do
        before do
          allow(other).to                         receive(:subscriber_end).and_return(1)
          allow(enrollment_event_notification).to receive(:subscriber_end).and_return(2)
        end

        it 'adds edge to graph of other to enrollment_event_notification' do
          expect(graph).to receive('add_edge').with(other, enrollment_event_notification)
          subject
        end
      end
    end
  end

  describe "#drop_if_bogus_renewal_term!" do
    subject { enrollment_event_notification.drop_if_bogus_renewal_term! }

    context 'of a notification without a bogus_renewal_termination' do
      it 'returns false' do
        expect(subject).to be_falsey
      end
    end

    context 'of a notification with a bogus renewal termination' do
      let(:result_publisher) { double :drop_bogus_renewal_term! => true }

      before do
        enrollment_event_notification.instance_variable_set :@bogus_renewal_termination, true
        allow(enrollment_event_notification).to receive('response_with_publisher').and_yield(result_publisher)
      end

      it 'calls drops_bogus_renewal_term! on result_publisher' do
        subject
        expect(result_publisher).to have_received('drop_bogus_renewal_term!').with(enrollment_event_notification)
      end
    end
  end

  describe "#check_for_bogus_renewal_term_against" do
    let(:other) { double 'other' }
    subject { enrollment_event_notification.check_for_bogus_renewal_term_against(other) }

    context 'when other is termination' do
      before { allow(other).to receive('is_termination?').and_return(true) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when enrollment_event_notification is not termination' do
      before do
        allow(other).to                         receive('is_termination?').and_return(false)
        allow(enrollment_event_notification).to receive('is_termination?').and_return(false)
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context "when enrollment_event_notification subscriber_end is not the same as other's subscriber_start" do
      before do
        allow(other).to                         receive('is_termination?').and_return(false)
        allow(enrollment_event_notification).to receive('is_termination?').and_return(true)
        allow(other).to                         receive('subscriber_start').and_return(Date.today)
        allow(enrollment_event_notification).to receive('subscriber_end').and_return(Date.today)
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context "when enrollment_event_notification active year does not precede other's active_year" do
      before do
        allow(other).to                         receive('is_termination?').and_return(false)
        allow(enrollment_event_notification).to receive('is_termination?').and_return(true)
        allow(other).to                         receive('subscriber_start').and_return(Date.today)
        allow(enrollment_event_notification).to receive('subscriber_end').and_return(Date.yesterday)
        allow(other).to                         receive('active_year').and_return(2017)
        allow(enrollment_event_notification).to receive('active_year').and_return(2016)
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context "other scenarios" do
      before do
        allow(other).to                         receive('is_termination?').and_return(false)
        allow(enrollment_event_notification).to receive('is_termination?').and_return(true)
        allow(other).to                         receive('subscriber_start').and_return(Date.new(2017,3,1))
        allow(enrollment_event_notification).to receive('subscriber_end').and_return(Date.new(2017,2,28))
        allow(other).to                         receive('active_year').and_return(2016)
        allow(enrollment_event_notification).to receive('active_year').and_return(2017)
      end

      it 'sets @bogus_renewal_termination to true' do
        subject
        expect(enrollment_event_notification.instance_variable_get(:@bogus_renewal_termination)).to be_truthy
      end
    end
  end
end

describe ExternalEvents::EnrollmentEventNotification, "that is not a term" do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }

  subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  before :each do
    allow(subject).to receive(:is_termination?).and_return(false)
  end

  it "is not an already processed termination" do
    expect(subject.already_processed_termination?).to be_falsey
  end
end

describe ExternalEvents::EnrollmentEventNotification, "that is a term with no existing enrollment" do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }

  subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  before :each do
    allow(subject).to receive(:is_termination?).and_return(true)
    allow(subject).to receive(:existing_policy).and_return(nil)
  end

  it "is not an already processed termination" do
    expect(subject.already_processed_termination?).to be_falsey
  end
end

describe ExternalEvents::EnrollmentEventNotification, "that is cancel with a canceled enrollment" do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:existing_policy) { instance_double(Policy, :canceled? => true, :terminated? => true) }

  subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  before :each do
    allow(subject).to receive(:is_termination?).and_return(true)
    allow(subject).to receive(:is_cancel?).and_return(true)
    allow(subject).to receive(:existing_policy).and_return(existing_policy)
  end

  it "is an already processed termination" do
    expect(subject.already_processed_termination?).to be_truthy
  end
end

describe ExternalEvents::EnrollmentEventNotification, "that is termination with a terminated enrollment" do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:existing_policy) { instance_double(Policy, :canceled? => false, :terminated? => true) }

  subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  before :each do
    allow(subject).to receive(:is_termination?).and_return(true)
    allow(subject).to receive(:is_cancel?).and_return(false)
    allow(subject).to receive(:existing_policy).and_return(existing_policy)
    allow(subject).to receive(:is_reterm_with_earlier_date?).and_return(false)
  end

  it "is an already processed termination" do
    expect(subject.already_processed_termination?).to be_truthy
  end
end

describe ExternalEvents::EnrollmentEventNotification, "that is a cancel with a terminated enrollment" do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:existing_policy) { instance_double(Policy, :canceled? => false, :terminated? => true) }

  subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  before :each do
    allow(subject).to receive(:is_termination?).and_return(true)
    allow(subject).to receive(:is_reterm_with_earlier_date?).and_return(false)
    allow(subject).to receive(:is_cancel?).and_return(true)
    allow(subject).to receive(:existing_policy).and_return(existing_policy)
  end

  it "is not an already processed termination" do
    expect(subject.already_processed_termination?).to be_falsey
  end
end

describe ExternalEvents::EnrollmentEventNotification, "that is a term with an active enrollment" do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:existing_policy) { instance_double(Policy, :canceled? => false, :terminated? => false) }

  subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  before :each do
    allow(subject).to receive(:is_termination?).and_return(true)
    allow(subject).to receive(:is_cancel?).and_return(false)
    allow(subject).to receive(:existing_policy).and_return(existing_policy)
    allow(subject).to receive(:is_reterm_with_earlier_date?).and_return(false)
  end

  it "is not an already processed termination" do
    expect(subject.already_processed_termination?).to be_falsey
  end
end


describe ExternalEvents::EnrollmentEventNotification, "that is termination with a terminated enrollment with earlier end date" do
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:existing_policy) { instance_double(Policy, :canceled? => false, :terminated? => true) }

  subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  before :each do
    allow(subject).to receive(:is_termination?).and_return(true)
    allow(subject).to receive(:existing_policy).and_return(existing_policy)
    allow(subject).to receive(:is_reterm_with_earlier_date?).and_return(true)
  end

  it "is an already processed termination" do
    expect(subject.already_processed_termination?).to be_falsey
  end
end

describe "#is_reterm_with_earlier_date?" do
  let(:start_date) {Date.today.beginning_of_month}
  let(:enrollee) {double}
  let(:policy_cv) { instance_double(::Openhbx::Cv2::Policy) }

  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }

  let :subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  context "with new past end date" do

    let(:existing_policy) { instance_double(Policy, :terminated? => true, :policy_end => Date.today.next_month) }

    before :each do
      allow(subject).to receive(:enrollment_action).and_return("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      allow(subject).to receive(:existing_policy).and_return(existing_policy)
      allow(subject).to receive(:subscriber).and_return(enrollee)
      allow(subject).to receive(:extract_enrollee_end).with(enrollee).and_return(start_date)
    end

    it "should return true" do
      expect(subject.is_reterm_with_earlier_date?).to be_truthy
    end

  end

  context "with new future end date" do

    let(:start_date) {Date.today.beginning_of_month + 2.months}
    let(:existing_policy) { instance_double(Policy, :terminated? => true, :policy_end => Date.today.next_month) }

    before :each do
      allow(subject).to receive(:enrollment_action).and_return("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      allow(subject).to receive(:existing_policy).and_return(existing_policy)
      allow(subject).to receive(:subscriber).and_return(enrollee)
      allow(subject).to receive(:extract_enrollee_end).with(enrollee).and_return(start_date)
    end

    it "should return false" do
      expect(subject.is_reterm_with_earlier_date?).to be_falsey
    end
  end

  context "with no end date" do

    let(:start_date) {nil}
    let(:existing_policy) { instance_double(Policy, :terminated? => true, :policy_end => Date.today.next_month) }

    before :each do
      allow(subject).to receive(:enrollment_action).and_return("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      allow(subject).to receive(:existing_policy).and_return(existing_policy)
      allow(subject).to receive(:subscriber).and_return(enrollee)
      allow(subject).to receive(:extract_enrollee_end).with(enrollee).and_return(start_date)
    end

    it "should return false" do
      expect(subject.is_reterm_with_earlier_date?).to be_falsey
    end
  end
end

describe "#drop_if_already_processed" do
  let(:start_date) {Date.today.beginning_of_month}
  let(:enrollee) {double}
  let(:policy_cv) { instance_double(::Openhbx::Cv2::Policy) }

  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:policy) { FactoryGirl.create(:policy) }
  let(:hbx_enrollment_id) { policy.hbx_enrollment_ids.first }

  let!(:enrollment_action_issue) do
    ::EnrollmentAction::EnrollmentActionIssue.create(
      :hbx_enrollment_id => hbx_enrollment_id,
      :enrollment_action_uri => "urn:openhbx:terms:v1:enrollment#terminate_enrollment"
    )
  end

  let(:existing_policy) { instance_double(Policy, :terminated? => true, :policy_end => Date.today.next_month) }
  
  let :subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end

  context "termination event received for already terminated policy and eligible for re-termination" do
    before do
      allow(subject).to receive(:is_termination?).and_return(true)
      allow(subject).to receive(:hbx_enrollment_id).and_return(hbx_enrollment_id)
      allow(subject).to receive(:enrollment_action).and_return("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
       allow(subject).to receive(:is_reterm_with_earlier_date?).and_return(true)
    end

    it "returns false" do
      expect(subject.drop_if_already_processed!).to be_false
    end
  end

  context "termination event received for already terminated policy and not eligble for re-termination" do
    let!(:result_publisher) { double :drop_if_already_processed! => true }
    
    before do
      allow(subject).to receive(:is_termination?).and_return(true)
      allow(subject).to receive('response_with_publisher').and_yield(result_publisher)
      allow(subject).to receive(:hbx_enrollment_id).and_return(hbx_enrollment_id)
      allow(subject).to receive(:enrollment_action).and_return("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      allow(subject).to receive(:is_reterm_with_earlier_date?).and_return(false)
    end

    it "returns notify event already processed" do
      expect(result_publisher).to receive(:drop_already_processed!).with(subject)
      subject.drop_if_already_processed!
    end
  end
end

describe "#has_renewal_cancel_policy", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.next_year.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:coverage_start) { Date.today.next_year.beginning_of_year }
  let(:enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: coverage_start)}
  let(:enrollee2) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.next_year.beginning_of_year, coverage_end: coverage_end)}

  let!(:renewal_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: nil, kind: kind, enrollees: [enrollee])
    policy.update_attributes(hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let!(:renewal_cancel_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, carrier_id: carrier_id, plan: plan, coverage_start: Date.today.next_year.beginning_of_year , coverage_end: Date.today.beginning_of_year, kind: kind, enrollees: [enrollee2])
    policy.save
    policy
  }

  let(:source_event_xml) { <<-EVENTXML
  <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
  <header>
    <hbx_id>29035</hbx_id>
    <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
  </header>
  <event>
    <body>
      <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
        <affected_members>
          <affected_member>
            <member>
              <id><id>1</id></id>
            </member>
            <benefit>
              <premium_amount>465.13</premium_amount>
              <begin_date>20190101</begin_date>
            </benefit>
          </affected_member>
        </affected_members>
        <enrollment xmlns="http://openhbx.org/api/terms/1.0">
          <policy>
            <id>
              <id>123</id>
            </id>
          <enrollees>
            <enrollee>
              <member>
                <id><id>#{primary.authority_member.hbx_member_id}</id></id>
              </member>
              <is_subscriber>true</is_subscriber>
              <benefit>
                <premium_amount>111.11</premium_amount>
                <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
              </benefit>
            </enrollee>
          </enrollees>
          <enrollment>
          <individual_market>
            <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
            <applied_aptc_amount>100.00</applied_aptc_amount>
          </individual_market>
          <shop_market>
            <employer_link>
              <id><id>urn:openhbx:terms:v1:employer:id##{employer_id}</id></id>
            </employer_link>
          </shop_market>
          <premium_total_amount>56.78</premium_total_amount>
          <total_responsible_amount>123.45</total_responsible_amount>
          </enrollment>
          </policy>
        </enrollment>
        </enrollment_event_body>
    </body>
  </event>
</enrollment_event>
  EVENTXML
  }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let :subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
  end

  context "IVL: with canceled renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { Date.today.next_year.beginning_of_year }
    let(:employer_id) { nil }
    let(:employer) { nil}
    before do
      allow(subject).to receive(:existing_plan).and_return(plan)
    end

    it "should return canceled renewal policy" do
      expect(renewal_cancel_policy.is_shop?).to eq false
      expect(subject.renewal_cancel_policy).to eq([renewal_cancel_policy])
    end
  end

  context "IVL: without canceled renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { nil }
    let(:employer_id) { nil }
    let(:employer) { nil}
    before do
      allow(subject).to receive(:existing_plan).and_return(plan)
    end

    it "should return empty array" do
      expect(renewal_cancel_policy.is_shop?).to eq false
      expect(subject.renewal_cancel_policy).to eq []
    end
  end

  context "SHOP: with canceled renewal policy" do
    let(:kind) { 'shop' }
    let(:coverage_end) { Date.today.next_year.beginning_of_year }
    let(:employer) { FactoryGirl.create(:employer)}
    let(:employer_id) { employer.hbx_id }
    before do
      allow(subject).to receive(:existing_plan).and_return(plan)
    end

    it "should return canceled renewal policy" do
      expect(renewal_cancel_policy.is_shop?).to eq true
      expect(subject.renewal_cancel_policy).to eq [renewal_cancel_policy]
    end
  end

  context "SHOP: without canceled renewal policy" do
    let(:kind) { 'shop' }
    let(:coverage_end) { nil }
    let(:employer) { FactoryGirl.create(:employer)}
    let(:employer_id) { employer.hbx_id }
    before do
      allow(subject).to receive(:existing_plan).and_return(plan)
    end

    it "should return empty array" do
      expect(renewal_cancel_policy.is_shop?).to eq true
      expect(subject.renewal_cancel_policy).to eq []
    end
  end
end

describe "#renewal_policies_to_cancel", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 123 ,:coverage_type => "health", year: Date.today.next_year.year) }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, hios_plan_id: 123, renewal_plan: plan, :coverage_type => "health", year: Date.today.year) }
  let(:dental_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "dental", year: Date.today.next_year.year) }
  let(:catastrophic_active_plan) { Plan.create!(:name => "test_plan", metal_level: 'catastrophic', hios_plan_id: '94506DC0390008', carrier_id: carrier_id, renewal_plan: plan, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:coverage_start) { Date.today.next_year.beginning_of_year }
  let(:enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_month, coverage_end: Date.today.end_of_month)}
  let(:enrollee2) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.next_year.beginning_of_year, coverage_end: coverage_end)}

  let!(:active_term_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_month, coverage_end: Date.today.end_of_month, kind: kind)
    policy.update_attributes(enrollees: [enrollee], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let!(:renewal_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, carrier_id: carrier_id, plan: plan, coverage_start: Date.today.next_year.beginning_of_year , coverage_end: coverage_end, kind: kind)
    policy.update_attributes(enrollees: [enrollee2])
    policy.save
    policy
  }
  let!(:renewal_dental_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, carrier_id: carrier_id, plan: dental_plan, coverage_start: Date.today.next_year.beginning_of_year , coverage_end: coverage_end, kind: kind, enrollees: [enrollee2])
    policy.save
    policy
  }

  let(:source_event_xml) { <<-EVENTXML
   <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
   <header>
     <hbx_id>29035</hbx_id>
     <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
   </header>
   <event>
     <body>
       <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
         <affected_members>
           <affected_member>
             <member>
               <id><id>1</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>20190101</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>123</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
           <individual_market>
             <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
             <applied_aptc_amount>100.00</applied_aptc_amount>
           </individual_market>
           <shop_market>
             <employer_link>
               <id><id>urn:openhbx:terms:v1:employer:id##{employer_id}</id></id>
             </employer_link>
           </shop_market>
           <premium_total_amount>56.78</premium_total_amount>
           <total_responsible_amount>123.45</total_responsible_amount>
           </enrollment>
           </policy>
         </enrollment>
         </enrollment_event_body>
     </body>
   </event>
 </enrollment_event>
  EVENTXML
  }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let :subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
  end

  context "IVL: with renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { nil}
    let(:employer_id) { nil }
    let(:employer) { nil}
    before do
      allow(subject).to receive(:existing_plan).and_return(active_plan)
    end

    it "should return renewal policy" do
      expect(renewal_policy.is_shop?).to eq false
      expect(subject.renewal_policies_to_cancel).to eq([renewal_policy])
    end
  end
  
  context "IVL with catastrophic plan : with renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { nil}
    let(:employer_id) { nil }
    let(:employer) { nil}
    before do
      allow(subject).to receive(:existing_plan).and_return(catastrophic_active_plan)
      active_term_policy.plan = catastrophic_active_plan
      active_term_policy.save
    end

    it "should return renewal policy" do
      expect(renewal_policy.is_shop?).to eq false
      expect(subject.renewal_policies_to_cancel).to eq([renewal_policy])
    end
  end

  context "IVL: without renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { Date.today.next_year.beginning_of_year }
    let(:employer_id) { nil }
    let(:employer) { nil}
    before do
      allow(subject).to receive(:existing_plan).and_return(active_plan)
    end

    it "should return empty array" do
      expect(renewal_policy.is_shop?).to eq false
      expect(subject.renewal_policies_to_cancel).to eq []
    end
  end

  context "SHOP: with renewal policy" do
    let(:kind) { 'shop' }
    let(:coverage_end) { nil }
    let(:employer) { FactoryGirl.create(:employer)}
    let!(:plan_year) { FactoryGirl.create(:plan_year, employer: employer, start_date: Date.new(Date.today.year, 1, 1), end_date: Date.new(Date.today.year, 12, 31))}
    let(:employer_id) { employer.hbx_id }
    before do
      allow(subject).to receive(:existing_plan).and_return(active_plan)
    end

    it "should not return renewal policy" do
      expect(renewal_policy.is_shop?).to eq true
      expect(subject.renewal_policies_to_cancel).to eq []
    end
  end

  context "SHOP: without renewal policy" do
    let(:kind) { 'shop' }
    let(:coverage_end) { Date.today.next_year.beginning_of_year  }
    let(:employer) { FactoryGirl.create(:employer)}
    let(:employer_id) { employer.hbx_id }
    before do
      allow(subject).to receive(:existing_plan).and_return(active_plan)
    end

    it "should return empty array" do
      expect(renewal_policy.is_shop?).to eq true
      expect(subject.renewal_policies_to_cancel).to eq []
    end
  end
end

describe "#dep_add_or_drop_to_renewal_policy?", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.next_year.year) }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, renewal_plan: plan, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:dep) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let!(:dep2) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let!(:dep3) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let(:prim_coverage_start) { Date.today.next_year.beginning_of_year }
  let(:dep_coverage_start) { Date.today.next_year.beginning_of_year }

  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: '')}
  let(:active_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: coverage_end)}
  let(:active_enrollee3) { Enrollee.new(m_id: dep2.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: coverage_end)}
  let(:active_enrollee4) { Enrollee.new(m_id: dep3.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: coverage_end)}

  let(:renewal_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: prim_coverage_start, coverage_end: '')}
  let(:renewal_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: dep_coverage_start, coverage_end: '')}

  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_month, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1, active_enrollee2, active_enrollee3])
    policy.save
    policy
  }
  let!(:renewal_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, carrier_id: carrier_id, plan: plan, coverage_start: Date.today.next_year.beginning_of_year , coverage_end: nil, kind: kind,)
    policy.update_attributes(enrollees: [renewal_enrollee1, renewal_enrollee2], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let(:source_event_xml) { <<-EVENTXML
   <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
   <header>
     <hbx_id>29035</hbx_id>
     <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
   </header>
   <event>
     <body>
       <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
         <affected_members>
           <affected_member>
             <member>
               <id><id>1</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>20190101</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>123</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{begin_date}</begin_date>
               </benefit>
             </enrollee>
             <enrollee>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>false</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{begin_date}</begin_date>
               </benefit>
             </enrollee>
             <enrollee>
               <member>
                 <id><id>#{dep2.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>false</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{begin_date}</begin_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
           <individual_market>
             <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
             <applied_aptc_amount>100.00</applied_aptc_amount>
           </individual_market>
           <shop_market>
             <employer_link>
               <id><id>urn:openhbx:terms:v1:employer:id##{employer_id}</id></id>
             </employer_link>
           </shop_market>
           <premium_total_amount>56.78</premium_total_amount>
           <total_responsible_amount>123.45</total_responsible_amount>
           </enrollment>
           </policy>
         </enrollment>
         </enrollment_event_body>
     </body>
   </event>
 </enrollment_event>
  EVENTXML
  }
  let(:source_event_xml2) { <<-EVENTXML
   <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
   <header>
     <hbx_id>29035</hbx_id>
     <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
   </header>
   <event>
     <body>
       <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
         <affected_members>
           <affected_member>
             <member>
               <id><id>1</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>20190101</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>123</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{begin_date}</begin_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
           <individual_market>
             <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
             <applied_aptc_amount>100.00</applied_aptc_amount>
           </individual_market>
           <shop_market>
             <employer_link>
               <id><id>urn:openhbx:terms:v1:employer:id##{employer_id}</id></id>
             </employer_link>
           </shop_market>
           <premium_total_amount>56.78</premium_total_amount>
           <total_responsible_amount>123.45</total_responsible_amount>
           </enrollment>
           </policy>
         </enrollment>
         </enrollment_event_body>
     </body>
   </event>
 </enrollment_event>
  EVENTXML
  }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }

  context "Dependent Add to renewal policy" do
    let :subject do
      ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
    end
    context "IVL: dep added to renewal policy" do
      let(:kind) { 'individual' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return true" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq true
      end
    end

    context "IVL: dep adding to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'individual' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep added to renewal policy" do
      let(:kind) { 'shop' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let!(:plan_year) { FactoryGirl.create(:plan_year, employer: employer, start_date: Date.new(Date.today.year, 1, 1), end_date: Date.new(Date.today.year, 12, 31))}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep added to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'shop' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "IVL: dep added to renewal policy and dependent not added to active policy" do
      let(:kind) { 'individual' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan)
        allow(subject).to receive(:is_shop?).and_return(false)
        active_policy.update_attributes(enrollees: [active_enrollee1, active_enrollee2, active_enrollee3, active_enrollee4])
      end

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end
  end

  context "Dependent Drop to renewal policy" do
    let :subject do
      ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml2, headers
    end
    context "IVL: dep dropped to renewal policy" do
      let(:kind) { 'individual' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { Date.today.beginning_of_month}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return true" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq true
      end
    end

    context "IVL: dep dropped to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'individual' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep dropped to renewal policy" do
      let(:kind) { 'shop' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let!(:plan_year) { FactoryGirl.create(:plan_year, employer: employer, start_date: Date.new(Date.today.year, 1, 1), end_date: Date.new(Date.today.year, 12, 31))}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep dropped to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'shop' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "IVL: dep dropped to renewal policy, and didn't dropped from active policy" do
      let(:kind) { 'individual' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return false" do
        expect(subject.dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end
  end
end

describe "#plan_change_dep_add_or_drop_to_renewal_policy?", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.next_year.year) }
  let(:plan2) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.next_year.year) }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, renewal_plan: plan2, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:dep) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let!(:dep2) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }

  let(:prim_coverage_start) { Date.today.next_year.beginning_of_year }
  let(:dep_coverage_start) { Date.today.next_year.beginning_of_year }

  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: '')}
  let(:active_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: coverage_end)}
  let(:active_enrollee3) { Enrollee.new(m_id: dep2.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: coverage_end)}

  let(:renewal_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: prim_coverage_start, coverage_end: '')}
  let(:renewal_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: dep_coverage_start, coverage_end: '')}

  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_month, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1, active_enrollee2, active_enrollee3])
    policy.save
    policy
  }
  let!(:renewal_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, carrier_id: carrier_id, plan: plan, coverage_start: Date.today.next_year.beginning_of_year , coverage_end: nil, kind: kind,)
    policy.update_attributes(enrollees: [renewal_enrollee1, renewal_enrollee2], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let(:source_event_xml) { <<-EVENTXML
   <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
   <header>
     <hbx_id>29035</hbx_id>
     <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
   </header>
   <event>
     <body>
       <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
         <affected_members>
           <affected_member>
             <member>
               <id><id>1</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>20190101</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>123</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{begin_date}</begin_date>
               </benefit>
             </enrollee>
             <enrollee>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>false</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{begin_date}</begin_date>
               </benefit>
             </enrollee>
             <enrollee>
               <member>
                 <id><id>#{dep2.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>false</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{begin_date}</begin_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
           <individual_market>
             <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
             <applied_aptc_amount>100.00</applied_aptc_amount>
           </individual_market>
           <shop_market>
             <employer_link>
               <id><id>urn:openhbx:terms:v1:employer:id##{employer_id}</id></id>
             </employer_link>
           </shop_market>
           <premium_total_amount>56.78</premium_total_amount>
           <total_responsible_amount>123.45</total_responsible_amount>
           </enrollment>
           </policy>
         </enrollment>
         </enrollment_event_body>
     </body>
   </event>
 </enrollment_event>
  EVENTXML
  }
  let(:source_event_xml2) { <<-EVENTXML
   <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
   <header>
     <hbx_id>29035</hbx_id>
     <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
   </header>
   <event>
     <body>
       <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
         <affected_members>
           <affected_member>
             <member>
               <id><id>1</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>20190101</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>123</id>
             </id>
             <enrollees>
               <enrollee>
                 <member>
                   <id><id>#{primary.authority_member.hbx_member_id}</id></id>
                 </member>
                 <is_subscriber>true</is_subscriber>
                 <benefit>
                   <premium_amount>111.11</premium_amount>
                   <begin_date>#{begin_date}</begin_date>
                 </benefit>
               </enrollee>
            </enrollees>
             <enrollment>
             <individual_market>
               <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
               <applied_aptc_amount>100.00</applied_aptc_amount>
               </individual_market>
             <shop_market>
               <employer_link>
                  <id><id>urn:openhbx:terms:v1:employer:id##{employer_id}</id></id>
               </employer_link>
             </shop_market>
             <premium_total_amount>56.78</premium_total_amount>
             <total_responsible_amount>123.45</total_responsible_amount>
             </enrollment>
             <is_active>true</is_active>
           </policy>
         </enrollment>
         </enrollment_event_body>
     </body>
   </event>
 </enrollment_event>
  EVENTXML
  }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }

  context "Dependent Add to renewal policy" do
    let :subject do
      ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
    end
    context "IVL: dep added to renewal policy" do
      let(:kind) { 'individual' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan2)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return true" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq true
      end
    end

    context "IVL: dep adding to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'individual' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan2)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return false" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep added to renewal policy" do
      let(:kind) { 'shop' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let!(:plan_year) { FactoryGirl.create(:plan_year, employer: employer, start_date: Date.new(Date.today.year, 1, 1), end_date: Date.new(Date.today.year, 12, 31))}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep added to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'shop' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end
  end

  context "Dependent Drop to renewal policy" do
    let :subject do
      ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml2, headers
    end
    context "IVL: dep added to renewal policy" do
      let(:kind) { 'individual' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { Date.today.beginning_of_month}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan2)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return true" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq true
      end
    end

    context "IVL: dep adding to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'individual' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer_id) { nil }
      let(:employer) { nil}
      let(:coverage_end) { nil}

      before do
        allow(subject).to receive(:existing_plan).and_return(plan2)
        allow(subject).to receive(:is_shop?).and_return(false)
      end

      it "should return false" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep added to renewal policy" do
      let(:kind) { 'shop' }
      let(:begin_date) { Date.today.next_year.beginning_of_year.strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let!(:plan_year) { FactoryGirl.create(:plan_year, employer: employer, start_date: Date.new(Date.today.year, 1, 1), end_date: Date.new(Date.today.year, 12, 31))}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end

    context "SHOP: dep added to renewal policy and dependent start date not the renewal start date" do
      let(:kind) { 'shop' }
      let(:begin_date) { (Date.today.next_year.beginning_of_year + 1.month).strftime("%Y%m%d") }
      let(:employer) { FactoryGirl.create(:employer)}
      let(:employer_id) { employer.hbx_id }
      let(:coverage_end) { nil}

      it "should return false" do
        expect(subject.plan_change_dep_add_or_drop_to_renewal_policy?(active_policy, renewal_policy)).to eq false
      end
    end
  end
end

describe "#is_retro_renewal_policy?", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.next_year.year) }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, renewal_plan: plan, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:dep) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:prim_coverage_start) { Date.today.next_year.beginning_of_year }
  let(:dep_coverage_start) { Date.today.next_year.beginning_of_year }

  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: coverage_end)}
  let(:active_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: coverage_end)}

  let(:renewal_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: prim_coverage_start, coverage_end: '')}
  let(:renewal_enrollee2) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'child', coverage_start: dep_coverage_start, coverage_end: '')}

  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, coverage_start: Date.today.beginning_of_month, coverage_end: coverage_end, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1, active_enrollee2])
    policy.save
    policy
  }
  let!(:renewal_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer, carrier_id: carrier_id, plan: plan, coverage_start: Date.today.next_year.beginning_of_year , coverage_end: nil, kind: kind,)
    policy.update_attributes(enrollees: [renewal_enrollee1, renewal_enrollee2], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }

  let(:source_event_xml) { <<-EVENTXML
   <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
   <header>
     <hbx_id>29035</hbx_id>
     <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
   </header>
   <event>
     <body>
       <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
         <affected_members>
           <affected_member>
             <member>
               <id><id>1</id></id>
             </member>
             <benefit>
               <premium_amount>465.13</premium_amount>
               <begin_date>20190101</begin_date>
             </benefit>
           </affected_member>
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>123</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </enrollee>
             <enrollee>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
           <individual_market>
             <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
             <applied_aptc_amount>100.00</applied_aptc_amount>
           </individual_market>
           <shop_market>
             <employer_link>
               <id><id>urn:openhbx:terms:v1:employer:id##{employer_id}</id></id>
             </employer_link>
           </shop_market>
           <premium_total_amount>56.78</premium_total_amount>
           <total_responsible_amount>123.45</total_responsible_amount>
           </enrollment>
           </policy>
         </enrollment>
         </enrollment_event_body>
     </body>
   </event>
 </enrollment_event>
  EVENTXML
  }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let :subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
  end

  context "IVL: renewal policy with initial event has contiguous active coverage" do
    let(:kind) { 'individual' }
    let(:employer_id) { nil }
    let(:employer) { nil}
    let(:coverage_end) { nil}

    before do
      allow(subject).to receive(:existing_plan).and_return(plan)
    end

    it "should return true" do
      expect(subject.is_retro_renewal_policy?).to eq true
    end
  end

  context "IVL: renewal policy with initial event has no contiguous active coverage" do
    let(:kind) { 'individual' }
    let(:dep_coverage_start) { Date.today.next_year.beginning_of_year + 1.month }
    let(:employer) { nil}
    let(:employer_id) { nil }
    let(:coverage_end) { Date.today.end_of_month}

    before do
      allow(subject).to receive(:existing_plan).and_return(plan)
    end

    it "should return false" do
      expect(subject.is_retro_renewal_policy?).to eq false
    end
  end

  context "SHOP: renewal policy with initial event has contiguous active coverage" do
    let(:kind) { 'shop' }
    let(:employer) { FactoryGirl.create(:employer)}
    let!(:plan_year) { FactoryGirl.create(:plan_year, employer: employer, start_date: Date.new(Date.today.year, 1, 1), end_date: Date.new(Date.today.year, 12, 31))}
    let(:employer_id) { employer.hbx_id }
    let(:coverage_end) { nil}

    it "should return false" do
      expect(subject.is_retro_renewal_policy?).to eq false
    end
  end

  context "SHOP: renewal policy with initial event has contiguous active coverage" do
    let(:kind) { 'shop' }
    let(:employer) { FactoryGirl.create(:employer)}
    let(:employer_id) { employer.hbx_id }
    let(:dep_coverage_start) { Date.today.next_year.beginning_of_year + 1.month }
    let(:coverage_end) { nil}

    it "should return false" do
      expect(subject.is_retro_renewal_policy?).to eq false
    end
  end
end
