module MoneyHelper
  def nzd(amount, signed: false)
    return "None" if amount.nil?
    sign = signed && amount.positive? ? "+" : ""
    "#{sign}#{amount.negative? ? "-" : ""}NZD #{number_with_precision(amount.abs, precision: 2, delimiter: ",")}"
  end
end
