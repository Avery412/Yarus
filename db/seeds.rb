if !Rails.env.production? && ENV['YARUS_DEMO_PASSWORD'].present?
  email = ENV.fetch("YARUS_DEMO_EMAIL", "operator@example.test").strip.downcase
  password = ENV["YARUS_DEMO_PASSWORD"]
  user = User.find_or_initialize_by(email: email)

  if user.new_record? || user.encrypted_password.blank?
    abort "Задайте YARUS_DEMO_PASSWORD (не менее 12 символов)" if password.to_s.length < 12
    user.password = password
    user.save!
  end

  tile = Product.find_or_create_by!(sku: "TL-001") { |item| item.assign_attributes(name: "Плитка «Терраццо»", unit: "м²", description: "Керамогранит для пола и стен") }
  brick = Product.find_or_create_by!(sku: "BR-012") { |item| item.assign_attributes(name: "Кирпич керамический", unit: "шт.") }
  north = Warehouse.find_or_create_by!(name: "Северный") { |item| item.address = "Промышленная улица, 10" }
  south = Warehouse.find_or_create_by!(name: "Южный") { |item| item.address = "Складская улица, 5" }

  entries = [
    [tile, north, "receipt", "10", "Поступление плитки"],
    [tile, north, "issue", "3.25", "Выдача со склада"],
    [brick, south, "receipt", "48", "Поступление кирпича"]
  ]

  StockMovement.transaction do
    entries.each do |product, warehouse, type, quantity, note|
      next if StockMovement.exists?(product: product, warehouse: warehouse, user: user, movement_type: type, quantity: quantity, note: note)

      StockMovements::Create.new(product: product, warehouse: warehouse, user: user, movement_type: type, quantity: quantity, note: note).call
    end
  end
end
