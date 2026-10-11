class CreateCurrencyPairs < ActiveRecord::Migration[8.1]
  def change
    create_table :currency_pairs do |t|
      t.string :symbol, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false
      t.timestamps
    end
    add_index :currency_pairs, :symbol, unique: true
  end
end
