require 'rails_helper'

describe EndCoverage, :dbclean => :after_each do
  subject(:end_coverage) { EndCoverage.new(action_factory, policy_repo) }

  let(:request) do
    {
      policy_id: policy.id,
      affected_enrollee_ids: affected_enrollee_ids,
      coverage_end: coverage_end,
      operation: operation,
      reason: 'terminate',
      current_user: current_user,
      transmit: true
    }
  end

  let(:action_request) do
    {
      policy_id: policy.id,
      operation: request[:operation],
      reason: request[:reason],
      affected_enrollee_ids: request[:affected_enrollee_ids],
      include_enrollee_ids: enrollees.map(&:m_id),
      current_user: current_user
    }
  end

  let(:affected_enrollee_ids) { [subscriber.m_id, member.m_id] }
  let(:coverage_end) { Date.new(2015, 1, 14)}
  let(:operation) { 'terminate' }
  let(:current_user) { 'joe.kramer@dc.gov' }
  let(:policy_repo) { double(find: policy) }
  let(:policy) { Policy.create!(eg_id: '1', enrollees: enrollees, pre_amt_tot: premium_total, plan_id: "1", plan: plan) }
  let(:plan) { Plan.create!(coverage_type: 'health', year: 2015, premium_tables: premium_tables) }
  let(:premium_tables) { [premium_table_for_subscriber, premium_table_for_member, premium_table_for_inactive_member]}
  let(:premium_total) { 300.00 }
  let(:enrollees) { [ subscriber, member ]}
  let(:subscriber) { Enrollee.new(rel_code: 'self', coverage_start: coverage_start, pre_amt: 100.00, coverage_status: 'active', emp_stat: 'active',  m_id: '1') }
  let(:member) { Enrollee.new(rel_code: 'child', coverage_start: coverage_start, pre_amt: 200.00, coverage_status: 'active', emp_stat: 'active',  m_id: '2') }
  let(:action_factory) { double(create_for: action) }
  let(:action) { double(execute: nil) }
  let(:coverage_start) { Date.new(2015, 1, 2)}
  let(:premium_start) { Date.new(2000,1,1) }
  let(:premium_end) { Date.new(2020,1,1) }
  let(:subscriber_member) { double(dob: Date.new(1955,1,1))}
  let(:subscriber_rate_amount) { 100 }
  let(:subscriber_age) { 60 }
  let(:premium_table_for_subscriber) { PremiumTable.new(rate_start_date: premium_start, rate_end_date: premium_end, age: subscriber_age, amount: subscriber_rate_amount) }
  let(:member_member) { double(dob: Date.new(1975,1,1))}
  let(:member_rate_amount) { 200 }
  let(:member_age) { 40 }
  let(:premium_table_for_member) { PremiumTable.new(rate_start_date: premium_start, rate_end_date: premium_end, age: member_age, amount: member_rate_amount) }
  let(:inactive_member_member) { double(dob: Date.new(1985,1,1)) }
  let(:inactive_member_rate_amount) { 250 }
  let(:inactive_member_age) { 30 }
  let(:premium_table_for_inactive_member) { PremiumTable.new(rate_start_date: premium_start, rate_end_date: premium_end, age: inactive_member_age, amount: inactive_member_rate_amount) }

  before do
    allow(subscriber).to receive(:member) { subscriber_member }
    allow(member).to receive(:member) { member_member }
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end


  shared_examples_for "coverage ended with correct responsible amount" do
    describe "when a shop enrollment" do
      let(:employer) { double(name: "Fakery", fein: 000000000, plan_years: [plan_year], __bson_dump__: nil) }
      let(:plan_year) { double( contribution_strategy: contribution_strategy, __bson_dump__: nil, start_date: Date.new(2015, 1, 2))}

      before {
        allow(policy).to receive(:employer) { employer }
        allow(employer).to receive(:plan_year_of) { plan_year }
        policy.employer_id = 1
      }

      it "should properly re-calculate the employer contribution amount" do
        end_coverage.execute(request)
        expect(policy.employer_contribution).to eql(expected_employer_contribution)
      end

      it "should set the total responsible amount to the premium total minus the employer contribution" do
        end_coverage.execute(request)
        expect(policy.tot_res_amt).to eql(policy.total_premium_amount - expected_employer_contribution)
      end
    end

    describe "when an individual enrollment" do
      it "should set the responsible amount equal to the new premium total" do
        end_coverage.execute(request)
        expect(policy.total_responsible_amount).to eql(policy.total_premium_amount)
      end
    end
  end

  context 'from button on UI' do
    it "notifies of the coverage end" do
      expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
      end_coverage.execute(request)
    end

    it 'finds the policy' do
      expect(policy_repo).to receive(:find).with(policy.id)
      end_coverage.execute(request)
    end

    it 'labels policy as updated by user' do
      end_coverage.execute(request)
      expect(policy.updated_by).to eq current_user
    end

    it 'creates a resulting action' do
      expect(action_factory).to receive(:create_for).with(request)
      end_coverage.execute(request)
    end

    it 'invokes the resulting action' do
      expect(action).to receive(:execute).with(action_request)
      end_coverage.execute(request)
    end

    it 'does not change the enrollees relationships' do
      end_coverage.execute(request)
      e_hash = policy.enrollees.map{ |e| [e.m_id,e.rel_code] }
      expected_enrollees = [[subscriber.m_id,"self"],[member.m_id,"child"]]
      expect(e_hash).to match_array(expected_enrollees)
    end

    context 'no one is affected' do
      let(:affected_enrollee_ids) { [] }
      it "doesn't execute the resulting action" do
        expect(action).not_to receive(:execute)
        end_coverage.execute(request)
      end
    end

    context "on an IVL policy terminated 12/31" do
      let(:coverage_end) { Date.new(coverage_start.year, 12, 31) }

      it "doesn't notify" do
        expect(Observers::PolicyUpdated).not_to receive(:notify).with(policy)
        end_coverage.execute(request)
      end
    end

    context "on shop 2016 enrollments" do
      let(:affected_enrollee_ids) { [ subscriber.m_id ] }
      let(:operation) { 'cancel' }
      let(:coverage_start) { Date.new(2016, 1, 2)}

      before{
        plan.update_attribute(:year, 2016)
        policy.update_attributes!(total_responsible_amount: 300, total_premium_amount: 300)
      }

      after{
        plan.update_attribute(:year, 2015)
        policy.update_attributes!(total_responsible_amount: 0)
      }

      it "shouldn't touch any of the premiums" do
        end_coverage.execute(request)
        expect(policy.total_responsible_amount).to eql(policy.total_premium_amount)
      end
    end

    context "on shop 2017 enrollments" do
      let(:affected_enrollee_ids) { [ subscriber.m_id ] }
      let(:operation) { 'cancel' }
      let(:coverage_start) { Date.new(2017, 1, 2)}

      before{
        plan.update_attribute(:year, 2017)
        policy.update_attributes!(total_responsible_amount: 300, total_premium_amount: 300)
      }

      after{
        plan.update_attribute(:year, 2015)
        policy.update_attributes!(total_responsible_amount: 0)
      }

      it "shouldn't touch any of the premiums" do
        end_coverage.execute(request)
        expect(policy.total_responsible_amount).to eql(policy.total_premium_amount)
      end
    end

    context 'when subscriber\'s coverage ends' do
      let(:affected_enrollee_ids) { [ subscriber.m_id ] }

      before { end_coverage.execute(request) }

      it 'affects all enrollees' do
        policy.enrollees.each do |e|
          expect(e.coverage_status).to eq 'inactive'
          expect(e.employment_status_code).to eq 'terminated'
          expect(e.coverage_end).to eq request[:coverage_end]
        end
      end

      context 'by cancelation' do
        let(:operation) { 'cancel' }
        let(:coverage_start) { Date.new(2015, 1, 2)}
        let(:coverage_end) { coverage_start }
        let(:contribution_strategy) { double(contribution_for: 248.33 )}
        let(:expected_employer_contribution) { 248.33 }

        it 'adjusts premium total to be the sum of all enrollees\' premiums' do
          sum = 0
          policy.enrollees.each do |e|
            sum += e.pre_amt
          end
          expect(policy.pre_amt_tot.to_f).to eq sum.to_f
        end

        it 'updates policy status' do
          expect(policy.aasm_state).to eq 'canceled'
        end

        it_behaves_like "coverage ended with correct responsible amount"
      end

      context 'by termination' do
        let(:operation) { 'terminate' }
        let(:coverage_start) { Date.new(2015, 1, 2)}
        let(:coverage_end) { Date.new(2015, 1, 14)}
        let(:contribution_strategy) { double(contribution_for: 82.77 )}
        let(:expected_employer_contribution) { 82.77 }

        context 'when member\'s coverage ended previously' do
          let(:member) { Enrollee.new(rel_code: 'child', pre_amt: 250.00, coverage_status: 'inactive', coverage_start: Date.new(2015, 1, 2), coverage_end:  Date.new(2015, 1, 2), ben_stat: 'active', emp_stat: 'terminated',  m_id: '2') }
          let(:expected_employer_contribution) { 82.77 }

          it 'new policy premium total doesnt include member' do
            allow(member).to receive(:member) { inactive_member_member }
            sum = 0
            policy.enrollees.each do |e|
              sum += e.pre_amt if e.coverage_end == subscriber.coverage_end
            end

            expect(policy.pre_amt_tot.to_f).to eq sum.to_f
          end
        end

        it 'updates policy status' do
          expect(policy.aasm_state).to eq 'terminated'
        end

        it_behaves_like "coverage ended with correct responsible amount"
      end
    end

    context 'when a member\'s coverage is ended' do
      let(:affected_enrollee_ids) { [member.m_id] }
      let(:contribution_strategy) { double(contribution_for: 82.77 )}
      let(:expected_employer_contribution) { 82.77 }

      it 'doesn\'t end the subscribers coverage' do
        end_coverage.execute(request)
        expect(subscriber.coverage_status).to eq 'active'
        expect(subscriber.employment_status_code).to eq 'active'
      end

      it 'ends the member\'s coverage' do
        end_coverage.execute(request)
        expect(member.coverage_status).to eq 'inactive'
        expect(member.employment_status_code).to eq 'terminated'
        expect(member.coverage_end).to eq request[:coverage_end]
      end

      it 'deducts member\'s premium from policy\'s total'  do
        end_coverage.execute(request)
        expect(policy.pre_amt_tot.to_f).to eq(100.00)
      end

      it_behaves_like "coverage ended with correct responsible amount"

      context 'by cancelation' do
        let(:operation) { 'cancel' }
        it 'sets the benefit end date to be equal to benefit begin date' do
          end_coverage.execute(request)
          expect(member.coverage_end).to eq member.coverage_start
        end
      end

      context 'and the members coverage is already ended' do
        let(:inactive_member) { Enrollee.new(rel_code: 'child', coverage_status: 'inactive', coverage_start: coverage_start, coverage_end: already_ended_date, pre_amt: 250.00, ben_stat: 'active', emp_stat: 'active',  m_id: '3') }
        let(:already_ended_date) { request[:coverage_end].prev_year }
        before do
          allow(inactive_member).to receive(:member) { inactive_member_member }
          affected_enrollee_ids << inactive_member.m_id
          policy.enrollees << inactive_member
          policy.save
        end

        it 'does not change their coverage end date' do
          expect { end_coverage.execute(request) }.not_to change{ inactive_member.coverage_end }
        end
      end
    end
  end

  context 'from csv upload from UI' do
    let(:bulk_cancel_term_listener) { double("listener") }
    let(:policy_repo) { double(where: [policy]) }

    context 'when policy is nil' do
      let(:policy_repo) { double(where: []) }

      it 'listener logs fail errors and finds no such policy' do
        expect(bulk_cancel_term_listener).to receive(:no_such_policy).with(policy_id: 1)
        expect(bulk_cancel_term_listener).to receive(:fail)
        end_coverage.execute_csv(request,bulk_cancel_term_listener)
      end
    end

    context 'when affected_enrollee_ids are nil' do
      let(:affected_enrollee_ids) { [] }

      it 'listener logs fail errors' do
        expect(bulk_cancel_term_listener).to receive(:fail)
        end_coverage.execute_csv(request,bulk_cancel_term_listener)
      end
    end

    context 'when policy is inactive' do

      it 'listener logs fail errors with inactive policy id' do
        allow(subscriber).to receive(:coverage_ended?) {true}
        allow(subscriber).to receive(:canceled?) {true}
        expect(bulk_cancel_term_listener).to receive(:policy_inactive).with(policy_id: 1)
        expect(bulk_cancel_term_listener).to receive(:fail)
        end_coverage.execute_csv(request,bulk_cancel_term_listener)
      end
    end

    context 'when end date is invalid' do
      let(:coverage_end) { Date.new(2001, 1, 14)}

      it 'listener logs fail errors with invalid end date' do
        expect(bulk_cancel_term_listener).to receive(:end_date_invalid).with(end_date: coverage_end)
        expect(bulk_cancel_term_listener).to receive(:fail)
        end_coverage.execute_csv(request,bulk_cancel_term_listener)
      end
    end

    context 'when no contribution strategy is found' do
      let(:employer) { double(name: "Fakery", fein: 101010101, plan_years: [plan_year], __bson_dump__: nil) }
      let(:plan_year) { double( contribution_strategy: contribution_strategy, __bson_dump__: nil, start_date: Date.new(2015, 1, 2))}
      let(:contribution_strategy) { nil }

      before {
        allow(policy).to receive(:employer) { employer }
        allow(employer).to receive(:plan_year_of) { plan_year }
        policy.employer_id = 1
      }

      it 'listener logs fail errors with error message' do
        expect(bulk_cancel_term_listener).to receive(:no_contribution_strategy).with({:message=>"No contribution data found for Fakery (fein: 101010101) in plan year 2015"})
        expect(bulk_cancel_term_listener).to receive(:fail)
        end_coverage.execute_csv(request,bulk_cancel_term_listener)
      end
    end

  end
end
