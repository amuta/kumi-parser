schema do
  input do
    hash :organization do
      string :name
      array :regions do
        string :region_name
        hash :headquarters do
          string :city
          array :buildings do
            string :building_name
            hash :facilities do
              string :facility_type
              integer :capacity
              float :utilization_rate
            end
          end
        end
      end
    end
  end

  # Deep access across 5 levels
  value :org_name, input.organization.name
  value :region_names, input.organization.regions.region_name
  value :hq_cities, input.organization.regions.headquarters.city
  value :building_names, input.organization.regions.headquarters.buildings.building_name
  value :facility_types, input.organization.regions.headquarters.buildings.facilities.facility_type
  value :capacities, input.organization.regions.headquarters.buildings.facilities.capacity
  value :utilization_rates, input.organization.regions.headquarters.buildings.facilities.utilization_rate

  # Traits using deep nesting - avoiding cross-scope issues
  trait :large_organization, fn(:size, input.organization.regions) > 1

  # Simple cascade using traits that work within same scope
  value :org_classification do
    on large_organization, 'Enterprise'
    base 'Standard'
  end

  # Aggregations that work properly
  value :total_capacity, fn(:sum, input.organization.regions.headquarters.buildings.facilities.capacity)
end
