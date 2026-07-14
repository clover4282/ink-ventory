ListingState = Data.define(:title, :currency, :base_price_cents, :availability, :variants, :image_url) do
  def as_json(*)
    {
      "title" => title.to_s,
      "currency" => currency.to_s,
      "base_price_cents" => base_price_cents,
      "availability" => availability.to_s
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
      variants: []
    )
  end
end
