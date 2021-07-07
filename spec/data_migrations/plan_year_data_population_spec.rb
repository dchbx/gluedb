require "rails_helper"
require File.join(Rails.root, "script", "migrations", "plan_year_data_population_script")

describe 'PlanYearDataPopulationScript', :dbclean => :after_each do
  describe '.export_csv' do

    employer = FactoryGirl.create(:employer_with_plan_year)
    employer1 = FactoryGirl.create(:employer_with_plan_year)
    employer2 = FactoryGirl.create(:employer_with_plan_year)
    employer3 = FactoryGirl.create(:employer_with_plan_year)

    field_names = %w(employer_hbx_id employer_fein effective_period_start_on effective_period_end_on carrier_hbx_id carrier_fein)
    export_csv_path = File.expand_path("#{Rails.root}/plan_year_data_test.csv")

    CSV.open(export_csv_path, 'w', write_headers: true, headers: field_names) do |csv|
      csv << [employer.hbx_id, employer.fein, employer.plan_years.first.start_date, employer.plan_years.first.end_date, "", ""]
      csv << [employer1.hbx_id, employer1.fein, employer1.plan_years.first.start_date, employer1.plan_years.first.end_date + 1.month, "", ""]
      csv << [employer2.hbx_id, employer2.fein, employer2.plan_years.first.start_date + 1.year, employer2.plan_years.first.end_date, "", ""]
      csv << [employer3.hbx_id, employer3.fein, employer3.plan_years.first.start_date + 1.month, employer3.plan_years.first.end_date + 1.month, "", ""]
    end

    PlanYearDataPopulationScript.new("#{Rails.root}/plan_year_data_test.csv").export_csv

    timestamp = Time.now.strftime('%Y%m%d%H%M')
    csv_output = File.read "#{Rails.root}/plan_year_data_population_#{timestamp}.csv"
    let(:csv) {CSV.parse(csv_output, :headers => true)}

    it 'first record matches to original plan year' do
      expect(csv[0]['status']).to eq("matched")
      expect(csv[0]['results']).to eq("not updated")
    end

    it 'second record matches to original plan year but end date is not matched' do
      expect(csv[1]['status']).to eq("matched")
      expect(csv[1]['results']).to eq("updated dates")
    end

    it 'third record start date greater than a year' do
      expect(csv[2]['status']).to eq("unmatched")
      expect(csv[2]['results']).to eq("found too many plan years with given start date or bad data")
    end

    it 'fourth record start date less than a year' do
      expect(csv[3]['status']).to eq("unmatched")
      expect(csv[3]['results']).to eq("udpated both start date and end date")
    end

    File.delete("#{Rails.root}/plan_year_data_population_#{timestamp}.csv") if File.exist?("#{Rails.root}/plan_year_data_population_#{timestamp}.csv")
    File.delete("#{Rails.root}/plan_year_data_test.csv") if File.exist?("#{Rails.root}/plan_year_data_test.csv")
  end
end
