require "test_helper"

class ApplicationRepositoryTest < ActiveSupport::TestCase
  # Небольшая тестовая модель заменяет ActiveRecord: здесь проверяется только
  # контракт передачи аргументов из репозитория, а не работа базы данных.
  class FakeModel
    class << self
      attr_accessor :received_attributes

      def create!(attributes)
        self.received_attributes = attributes
      end
    end
  end

  class FakeRecord
    attr_reader :received_attributes

    def update!(attributes)
      @received_attributes = attributes
    end
  end

  setup do
    FakeModel.received_attributes = nil
  end

  test "create! accepts keyword attributes" do
    repository = ApplicationRepository.new(FakeModel)

    repository.create!(product: "Товар", movement_type: "receipt")

    assert_equal(
      { product: "Товар", movement_type: "receipt" },
      FakeModel.received_attributes
    )
  end

  test "create! accepts a positional hash" do
    repository = ApplicationRepository.new(FakeModel)

    repository.create!({ name: "Товар" })

    assert_equal({ name: "Товар" }, FakeModel.received_attributes)
  end

  test "update! accepts keyword attributes and returns the record" do
    repository = ApplicationRepository.new(FakeModel)
    record = FakeRecord.new

    result = repository.update!(record, quantity: 12)

    assert_same record, result
    assert_equal({ quantity: 12 }, record.received_attributes)
  end

  test "update! accepts a positional hash" do
    repository = ApplicationRepository.new(FakeModel)
    record = FakeRecord.new

    repository.update!(record, { quantity: 7 })

    assert_equal({ quantity: 7 }, record.received_attributes)
  end
end

