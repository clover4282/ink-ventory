VariantState = Data.define(:external_id, :name, :price_cents, :availability, :visible_quantity) do
  def as_json(*)
    {
      "external_id" => external_id.to_s,
      "name" => name.to_s,
      "price_cents" => price_cents,
      "availability" => availability.to_s,
      "visible_quantity" => visible_quantity
    }
  end
end
