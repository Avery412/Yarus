require "application_system_test_case"
require "securerandom"

class WarehouseWorkflowTest < ApplicationSystemTestCase
  test "sign in, receive, issue and recover from insufficient stock" do
    password = SecureRandom.hex(18)
    user = User.create!(email: "browser@example.test", password: password)
    Product.create!(name: "Плитка", sku: "UI-01", unit: "м²")
    Warehouse.create!(name: "Северный")

    visit root_path
    click_link "Войти в ЯРУС"
    fill_in "Электронная почта", with: user.email
    fill_in "Пароль", with: password
    click_button "Войти"
    assert_selector "h1", text: "Остатки"

    click_link "＋ Приход"
    select "Плитка · UI-01 (м²)", from: "Товар"
    select "Северный", from: "Склад"
    fill_in "Количество", with: "10"
    click_button "Провести операцию"
    assert_text "+10,000 м²"
    assert_text user.email

    click_link "Оформить обратную операцию"
    assert_field "Количество", with: "10.0"
    assert_select "Тип операции", selected: "Расход"
    fill_in "Количество", with: "3,25"
    click_button "Провести операцию"
    assert_text "−3,250 м²"

    click_link "Проверить остаток"
    assert_text "6,750 м²"
    click_link "− Расход"
    fill_in "Количество", with: "7"
    click_button "Провести операцию"
    assert_text "Недостаточно товара"
    assert_field "Количество", with: "7"

    click_link "Отмена"
    within("table") do
      assert_text "Приход"
      assert_text "Расход"
      assert_selector "tbody tr", count: 2
    end
  end
end
