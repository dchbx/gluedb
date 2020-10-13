require 'rails_helper'

describe Family, :dbclean => :after_each do

  let(:p0) { Person.create!(name_first: "Dan", name_last: "Aurbach") }
  let(:p1) { Person.create!(name_first: "Patrick", name_last: "Carney") }
  let(:a0) { family_member = FamilyMember.new(is_primary_applicant: true, is_consent_applicant: true);
  family_member.person=p0;
  family_member }
  let(:a1) { family_member = FamilyMember.new();
  family_member.person=p1;
  family_member }

  describe "instantiates object." do
    it "sets and gets all basic model fields" do
      now = DateTime.now.utc
      ag = Family.new(
          e_case_id: "6754632abc",
          renewal_consent_through_year: 2017,
          family_members: [a0, a1],
          submitted_at: now,
          is_active: true,
          updated_by: "rspec"
      )

      expect(ag.e_case_id).to eql("6754632abc")
      expect(ag.is_active).to eql(true)
      expect(ag.renewal_consent_through_year).to eql(2017)
      expect(ag.submitted_at.to_s).to eql(now.to_s)
      expect(ag.updated_by).to eql("rspec")

      expect(ag.family_members.size).to eql(2)
      expect(ag.primary_applicant.id).to eql(a0.id)
      expect(ag.primary_applicant.person.name_first).to eql("Dan")
      expect(ag.consent_applicant.person.name_last).to eql("Aurbach")
    end
  end

  describe "manages embedded associations." do

    it "sets family_members" do


      family = Family.create!(
          e_case_id: "6754632abc",
          renewal_consent_through_year: 2017,
          submitted_at: Date.today,
          family_members: [a0, a1],
          irs_groups: [IrsGroup.new()]
      );

      expect(family.family_members.size).to eql(2)

    end

  end
end
