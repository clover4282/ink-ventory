class FountainPenFilter
  def self.match?(title, trusted_category: false)
    explicit_fountain_pen = title.match?(/만년필|fountain\s*pen/i)
    return false if title.match?(/만년필\s*(?:전용|용|구호용품)/i)
    return false if title.match?(/만년필\s*(?:전용|용)?\s*(?:잉크|컨버터|카트리지|세척|클리너|펜촉|닙|부속품|리필)/i)
    return explicit_fountain_pen unless trusted_category
    return true if explicit_fountain_pen

    !title.match?(/볼펜|샤프|롤러볼|수성펜|딥펜|캘리그라피|펜촉|\b닙\b|nib|컨버터|카트리지|파우치|케이스|펜벨로프|펜슬리브|펜\s*인서트|세척|클리너|부속품|리필|클립|홀더|서랍장|이레이저/i)
  end
end
