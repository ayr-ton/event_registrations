class RemoveInvoicerTypeFromPaymentNotifications < ActiveRecord::Migration
  def change
    remove_column :payment_notifications, :invoicer_type, :string
  end
end
