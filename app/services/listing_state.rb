ListingState = Data.define(:title, :currency, :base_price_cents, :availability, :variants, :image_url) do
  def as_json(*)
    {
      "title" => title.to_s,
      "currency" => currency.to_s,
      "base_price_cents" => base_price_cents,
      "availability" => availability.to_s,
      "variants" => variants.sort_by { |variant| variant.external_id.to_s }.map(&:as_json)
    }
  end

  def self.from_hash(hash)
    hash = hash.stringify_keys
    new(
      title: hash["title"],
      currency: hash["currency"],
      base_price_cents: hash["base_price_cents"],
      availability: hash["availability"],
      image_url: nil,
      variants: Array(hash["variants"]).map do |variant|
        variant = variant.stringify_keys
        VariantState.new(
          external_id: variant["external_id"], name: variant["name"],
          price_cents: variant["price_cents"], availability: variant["availability"],
          visible_quantity: variant["visible_quantity"]
        )
      end
    )
  end
end
