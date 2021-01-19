require "rails_helper"

describe User, "given an update" do
  let(:existing_user) do
    User.create!({
      role: "user",
      email: "some.dude@place.com",
      password: "WHATEVER",
      password_confirmation: "WHATEVER"
    })
  end

  after :each do
    User.where({}).delete_all
  end

  describe "when a user is provide for the update" do

    let(:admin_email) { "some.other.dude@admins.com" }

    let(:current_user) do
      instance_double(
        User,
        {
          :email => admin_email
        }
      )
    end

    it "updates correctly" do
      expect(existing_user.update_attributes_as({}, current_user)).to be_truthy
    end

    it "records #updated_by" do
      existing_user.update_attributes_as({}, current_user)
      existing_user.reload
      expect(existing_user.updated_by).to eq admin_email
    end
  end
end