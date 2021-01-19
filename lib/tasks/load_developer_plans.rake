namespace :developer do
  desc "Load Demo Plans"
  task :load_plans => "developer:load_carriers" do
    plan_0 = Plan.create!(
      name: "Seed Carrier Plan",
      hios_plan_id: "86545CT1400003-01",
      hios_base_id: "86545CT1400003",
      coverage_type: "health",
      metal_level: "silver",
      market_type: "shop",
      year: 1.year.ago.year.to_s,
      carrier_id: Carrier.where(hbx_carrier_id: "20014").first.id,
      renewal_plan_id: nil,
      employer_ids: nil,
    )
    plan_1 = Plan.create!(
      name: "Seed Carrier Plan",
      hios_plan_id: "86545CT1400003-01",
      hios_base_id: "86545CT1400003",
      coverage_type: "health",
      metal_level: "silver",
      market_type: "shop",
      year: Time.now.year.to_s,
      carrier_id: Carrier.where(hbx_carrier_id: "20014").first.id,
      renewal_plan_id: nil,
      employer_ids: nil,
    )
    plan_2 = Plan.create!(
      name: "Seed Carrier Plan",
      hios_plan_id: "86545CT1400003-01",
      hios_base_id: "86545CT1400003",
      coverage_type: "health",
      metal_level: "silver",
      market_type: "shop",
      year: 1.year.from_now.year.to_s,
      carrier_id: Carrier.where(hbx_carrier_id: "20014").first.id,
      renewal_plan_id: nil,
      employer_ids: nil,
    )
    puts("#{Plan.count} plans created.") unless Rails.env.test?
  end
end
