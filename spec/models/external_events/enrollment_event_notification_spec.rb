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

        before do
          allow(enrollment_event_notification).to receive('existing_policy').and_return(nil)
          allow(enrollment_event_notification).to receive(:is_reterm_with_earlier_date?).and_return(false)
        end

        it 'sets @bogus_termination to existing_policy.nil?' do
          subject
          expect(enrollment_event_notification).to have_received('existing_policy')
        end

        it 'sets @bogus_termination to is_reterm_with_earlier_date?' do
          subject
          expect(enrollment_event_notification).to have_received('is_reterm_with_earlier_date?')
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

describe "#is_reterm_with_earlier_date?", :dbclean => :after_each do
  let(:start_date) {Date.today.beginning_of_month - 1.month}
  let(:enrollee) {double}
  let(:subscriber_id) {"11"}
  let!(:policy_cv) { instance_double(::Openhbx::Cv2::Policy, :previous_policy_id => "1234", :enrollees => [enrollee]) }
  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:e_xml) { double('e_xml') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let :subject do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, e_xml, headers
  end
  let(:coverage_start) { start_date }
  let(:coverage_end) { end_date - 10.day }
  let!(:policy) do
    enrollee = FactoryGirl.build(:subscriber_enrollee, coverage_start: coverage_start, coverage_end: coverage_end)
    enrollee.m_id = "11"
    policy = FactoryGirl.create(:policy, enrollees: [ enrollee ])
    policy.hbx_enrollment_ids << "1234"
    policy.save!
    policy
  end
  let(:existing_policy) { instance_double(Policy, :terminated? => true) }

  before :each do
    allow(subject).to receive(:enrollment_action).and_return("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(subject).to receive(:existing_policy).and_return(existing_policy)
    allow(subject).to receive(:subscriber).and_return(enrollee)
    allow(subject).to receive(:extract_enrollee_end).with(enrollee).and_return(end_date)
    allow(subject).to receive(:extract_enrollee_start).with(enrollee).and_return(start_date)
    allow(subject).to receive(:policy_cv).and_return(policy_cv)
    allow(subject).to receive(:all_member_ids).and_return([subscriber_id])
    allow(subject).to receive(:subscriber_id).and_return(subscriber_id)
    allow(subject).to receive(:extract_member_id).with(enrollee).and_return(subscriber_id)
  end

  context "with new past date", :dbclean => :after_each do
    let(:end_date) {Date.today.beginning_of_month}

    it "should return true" do
      expect(subject.is_reterm_with_earlier_date?).to be_truthy
    end
  end

  context "with today's date" do
    let(:end_date) {Date.today}

    it "should return true" do
      expect(subject.is_reterm_with_earlier_date?).to be_truthy
    end
  end

  context "with new future end date" do
    let!(:end_date) {Date.today.end_of_month}

    it "should return false" do
      expect(subject.is_reterm_with_earlier_date?).to be_falsey
    end
  end

  context "with no end date" do
    let!(:coverage_end) {start_date}
    let!(:end_date) {''}

    it "should return false" do
      expect(subject.is_reterm_with_earlier_date?).to be_falsey
    end
  end
end
