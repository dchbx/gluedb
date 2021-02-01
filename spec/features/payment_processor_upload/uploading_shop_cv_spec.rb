require 'rails_helper'

feature 'uploading show CV', :dbclean => :after_each do
  let(:mock_event_broadcaster) do
    instance_double(Amqp::EventBroadcaster)
  end

  let(:user) { create :user, :admin }

  given(:premium) do
    PremiumTable.new(
      rate_start_date: Date.new(2014, 1, 1),
      rate_end_date: Date.new(2014, 12, 31),
      age: 53,
      amount: 742.47)
  end
  background do
    visit root_path
    sign_in_with(user.email, user.password)

    # Note: The file fixture is dependent on this record.
    plan = Plan.new(coverage_type: 'health', hios_plan_id: '11111111111111-11', year: 2014)
    plan.premium_tables << premium
    plan.save!
    employer = Employer.create!(fein: 111111111)
    plan_year = PlanYear.create!(start_date: Date.new(2014,05,01), end_date: Date.new(2015, 4, 30), employer: employer)
  end

  scenario 'no file is selected' do
    visit new_payment_processor_upload_path

    choose 'Initial Enrollment'

    click_button "Upload"

    expect(page).not_to have_content 'Uploaded successfully.'
  end

  scenario 'a successful upload' do
    file_path = Rails.root + "spec/support/fixtures/shop_enrollment/correct.xml"
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(mock_event_broadcaster)
    allow(mock_event_broadcaster).to receive(:broadcast).with(
      {
        :routing_key => "info.events.legacy_enrollment_vocabulary.payment_processor_vocabulary_uploaded",
        :app_id =>  "gluedb",
        :headers =>  {
          "file_name" => File.basename(file_path),
          "kind" => 'initial_enrollment',
          "submitted_by"  => user.email,
          "type"=>"payment_processor_vocab_uploaded",
          "csl_number" => "1234"
        }
      },
      File.read(file_path)
    )
    visit new_payment_processor_upload_path

    choose 'Initial Enrollment'
    fill_in "payment_processor_upload[csl_number]", with: "1234"

    attach_file('payment_processor_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'Uploaded successfully.'
  end

  scenario 'an enrollee\'s premium is incorrect' do
    visit new_payment_processor_upload_path

    choose 'Initial Enrollment'
    fill_in "payment_processor_upload[redmine_ticket]", with: "1234"

    file_path = Rails.root + "spec/support/fixtures/shop_enrollment/incorrect_premium.xml"
    attach_file('payment_processor_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'premium_amount is incorrect'
    expect(page).to have_content 'Failed to Upload.'

  end

  scenario 'premium amount total is incorrect' do
    visit new_payment_processor_upload_path

    choose 'Initial Enrollment'
    fill_in "payment_processor_upload[redmine_ticket]", with: "1234"

    file_path = Rails.root + "spec/support/fixtures/shop_enrollment/incorrect_total.xml"
    attach_file('payment_processor_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'premium_amount_total is incorrect'
    expect(page).to have_content 'Failed to Upload.'
  end

  scenario 'responsible amount is incorrect' do
    visit new_payment_processor_upload_path

    choose 'Initial Enrollment'
    fill_in "payment_processor_upload[redmine_ticket]", with: "1234"

    file_path = Rails.root + "spec/support/fixtures/shop_enrollment/incorrect_responsible.xml"
    attach_file('payment_processor_upload_vocab', file_path)

    click_button "Upload"

    expect(page).to have_content 'total_responsible_amount is incorrect'
    expect(page).to have_content 'Failed to Upload.'
  end

  feature 'Handling premium not found error' do
    given(:premium) { nil }
    scenario 'premium table is not in the system' do
      visit new_payment_processor_upload_path

      choose 'Initial Enrollment'
      fill_in "payment_processor_upload[redmine_ticket]", with: "1234"

      file_path = Rails.root + "spec/support/fixtures/shop_enrollment/correct.xml"
      attach_file('payment_processor_upload_vocab', file_path)

      click_button "Upload"

      expect(page).to have_content 'Premium was not found in the system.'
      expect(page).to have_content 'Failed to Upload.'
    end
  end
end
