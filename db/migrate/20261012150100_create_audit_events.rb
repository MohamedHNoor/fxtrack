class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false
      t.jsonb :changes_made, null: false, default: {}
      t.string :reason, limit: 500
      t.datetime :created_at, null: false
    end
  end
end
