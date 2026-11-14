class ChangeMeasureValueToStringInMeasurements < ActiveRecord::Migration[8.1]
  def change
    change_column :measurements, :measure_value, :string
  end
end
