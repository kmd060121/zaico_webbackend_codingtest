class PerformanceDatasetSeeder
  # アカウント規模の定義（本番用）
  ACCOUNT_SCALES_REALISTIC = {
    small: {
      count: 700,
      inventories_range: 10..100,
      purchases_range: 50..500,
      deliveries_range: 50..500
    },
    medium: {
      count: 250,
      inventories_range: 1_000..10_000,
      purchases_range: 5_000..50_000,
      deliveries_range: 5_000..50_000
    },
    large: {
      count: 40,
      inventories_range: 50_000..100_000,
      purchases_range: 250_000..500_000,
      deliveries_range: 250_000..500_000
    },
    max: {
      count: 10,
      inventories_range: 200_000..200_000,
      purchases_range: 1_000_000..1_000_000,
      deliveries_range: 1_000_000..1_000_000
    }
  }.freeze

  # アカウント規模の定義（テスト用）
  ACCOUNT_SCALES_TEST = {
    small: {
      count: 10,
      inventories_range: 10..100,
      purchases_range: 50..500,
      deliveries_range: 50..500
    },
    medium: {
      count: 5,
      inventories_range: 1_000..10_000,
      purchases_range: 5_000..50_000,
      deliveries_range: 5_000..50_000
    },
    large: {
      count: 2,
      inventories_range: 50_000..100_000,
      purchases_range: 250_000..500_000,
      deliveries_range: 250_000..500_000
    },
    max: {
      count: 1,
      inventories_range: 200_000..200_000,
      purchases_range: 1_000_000..1_000_000,
      deliveries_range: 1_000_000..1_000_000
    }
  }.freeze

  def initialize(mode: :test, items_batch_size: 10_000)
    @mode = mode
    @items_batch_size = items_batch_size
    @account_scales = mode == :realistic ? ACCOUNT_SCALES_REALISTIC : ACCOUNT_SCALES_TEST
  end

  def call
    require "factory_bot"

    total_accounts = account_scales.values.sum { |config| config[:count] }

    puts "=== パフォーマンステストデータセット生成開始 ==="
    puts "モード: #{mode == :realistic ? '本番' : 'テスト'}"
    puts "合計アカウント数: #{total_accounts}"
    puts ""

    total_start_time = Time.current
    now = Time.current

    account_counter = 0

    account_scales.each do |scale_name, config|
      scale_start_time = Time.current
      puts "【#{scale_name.upcase}】規模のアカウント生成開始 (#{config[:count]}アカウント)"

      config[:count].times do |idx|
        account_counter += 1

        # ランダムで各パラメータを決定
        inventories_count = rand(config[:inventories_range])
        purchases_count = rand(config[:purchases_range])
        deliveries_count = rand(config[:deliveries_range])

        company = FactoryBot.create(:company, name: "Company#{account_counter}")

        # Inventories生成
        inventories = Array.new(inventories_count) do
          FactoryBot.attributes_for(:inventory, company_id: company.id).merge(created_at: now, updated_at: now)
        end
        Inventory.insert_all!(inventories) if inventories.any?
        inventory_ids = company.inventories.order(:id).pluck(:id)

        # Purchases生成
        purchases = Array.new(purchases_count) do |i|
          FactoryBot.attributes_for(:purchase, company_id: company.id, num: "P#{company.id}-#{i + 1}").merge(created_at: now, updated_at: now)
        end
        Purchase.insert_all!(purchases) if purchases.any?
        purchase_ids = company.purchases.order(:id).pluck(:id)

        # Deliveries生成
        deliveries = Array.new(deliveries_count) do |i|
          FactoryBot.attributes_for(:delivery, company_id: company.id, num: "D#{company.id}-#{i + 1}").merge(created_at: now, updated_at: now)
        end
        Delivery.insert_all!(deliveries) if deliveries.any?
        delivery_ids = company.deliveries.order(:id).pluck(:id)

        # PurchaseItems生成
        if purchase_ids.any? && inventory_ids.any?
          build_and_insert_items(
            klass: PurchaseItem,
            factory_key: :purchase_item,
            company_id: company.id,
            parent_ids: purchase_ids,
            inventory_ids: inventory_ids,
            batch_size: items_batch_size,
            parent_key: :purchase_id,
            now: now
          )
        end

        # DeliveryItems生成
        if delivery_ids.any? && inventory_ids.any?
          build_and_insert_items(
            klass: DeliveryItem,
            factory_key: :delivery_item,
            company_id: company.id,
            parent_ids: delivery_ids,
            inventory_ids: inventory_ids,
            batch_size: items_batch_size,
            parent_key: :delivery_id,
            now: now
          )
        end

        if (idx + 1) % 10 == 0 || (idx + 1) == config[:count]
          puts "  進捗: #{idx + 1}/#{config[:count]} アカウント (累計: #{account_counter}/#{total_accounts})"
        end
      end

      scale_elapsed = Time.current - scale_start_time
      puts "【#{scale_name.upcase}】完了 (所要時間: #{scale_elapsed.round(2)}秒)"
      puts ""
    end

    total_elapsed = Time.current - total_start_time

    puts "=== データセット生成完了 ==="
    puts "総所要時間: #{total_elapsed.round(2)}秒"
    puts ""
    print_statistics
  end

  private

  attr_reader :mode, :items_batch_size, :account_scales

  def build_and_insert_items(klass:, factory_key:, company_id:, parent_ids:, inventory_ids:, batch_size:, parent_key:, now:)
    buffer = []

    parent_ids.each do |parent_id|
      inventory_id = inventory_ids.sample
      attrs = FactoryBot.attributes_for(
        factory_key,
        company_id: company_id,
        inventory_id: inventory_id,
        parent_key => parent_id
      ).merge(created_at: now, updated_at: now)

      buffer << attrs

      if buffer.size >= batch_size
        klass.insert_all!(buffer)
        buffer.clear
      end
    end

    klass.insert_all!(buffer) if buffer.any?
  end

  def print_statistics
    puts "【最終データ統計】"
    puts "  Companies: #{Company.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Inventories: #{Inventory.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Purchases: #{Purchase.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  PurchaseItems: #{PurchaseItem.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Deliveries: #{Delivery.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  DeliveryItems: #{DeliveryItem.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

    total_records = Company.count + Inventory.count + Purchase.count + PurchaseItem.count + Delivery.count + DeliveryItem.count
    puts "  合計レコード数: #{total_records.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
end
