module Tax2024Schema
  extend Kumi::Schema

  FED_BREAKS_SINGLE = [11_000, 44_725, 95_375, 205_250, 244_050, 609_350, Float::INFINITY]
  FED_BREAKS_MARRIED = [22_000, 89_450, 190_750, 364_200, 462_500, 693_750, Float::INFINITY]
  FED_BREAKS_SEPARATE = [11_000, 44_725, 95_375, 182_100, 231_250, 346_875, Float::INFINITY]
  FED_BREAKS_HOH = [15_700, 59_850, 95_350, 193_350, 244_050, 609_350, Float::INFINITY]
  FED_RATES = [0.10, 0.12, 0.22, 0.24, 0.32, 0.35, 0.37]

  build_syntax_tree do
    input do
      float  :income
      string :filing_status
    end

    trait :single,     input.filing_status == 'single'
    trait :married,    input.filing_status == 'married_joint'
    trait :separate,   input.filing_status == 'married_separate'
    trait :hoh,        input.filing_status == 'head_of_household'

    value :std_deduction do
      on  single,   14_600
      on  married,  29_200
      on  separate, 14_600
      base 21_900
    end

    value :taxable_income,
          fn(:max, [input.income - std_deduction, 0])

    value :fed_breaks do
      on  single,   FED_BREAKS_SINGLE
      on  married,  FED_BREAKS_MARRIED
      on  separate, FED_BREAKS_SEPARATE
      on  hoh,      FED_BREAKS_HOH
    end

    value :fed_rates, FED_RATES
    value :fed_calc,
          fn(:piecewise_sum, taxable_income, fed_breaks, fed_rates)

    value :fed_tax,       fed_calc[0]
    value :fed_marginal,  fed_calc[1]
    value :fed_eff,       fed_tax / fn(:max, [input.income, 1.0])

    value :ss_wage_base, 168_600.0
    value :ss_rate,      0.062

    value :med_base_rate, 0.0145
    value :addl_med_rate, 0.009

    value :addl_threshold do
      on  single,   200_000
      on  married,  250_000
      on  separate, 125_000
      base 200_000
    end

    value :ss_tax,
          fn(:min, [input.income, ss_wage_base]) * ss_rate

    value :med_tax, input.income * med_base_rate

    value :addl_med_tax,
          fn(:max, [input.income - addl_threshold, 0]) * addl_med_rate

    value :fica_tax,  ss_tax + med_tax + addl_med_tax
    value :fica_eff,  fica_tax / fn(:max, [input.income, 1.0])

    value :total_tax,
          fed_tax + fica_tax

    value :total_eff,   total_tax / fn(:max, [input.income, 1.0])
    value :after_tax,   input.income - total_tax
  end
end

# frozen_string_literal: true

RSpec.describe 'Kumi::Parser::TextParser Integration' do
  describe 'diagnostic API methods' do
    let(:tax_2024_schema) do
      <<~KUMI
        schema do
          input do
            float  :income
            string :filing_status
          end

          trait :single,     input.filing_status == "single"
          trait :married,    input.filing_status == "married_joint"
          trait :separate,   input.filing_status == "married_separate"
          trait :hoh,        input.filing_status == "head_of_household"

          value :std_deduction do
            on  single,   14_600
            on  married,  29_200
            on  separate, 14_600
            base 21_900
          end

          value :taxable_income,
                fn(:max, [input.income - std_deduction, 0])

          value :fed_breaks do
            on  single,   [11_000, 44_725, 95_375, 205_250, 244_050, 609_350, Float::INFINITY]
            on  married,  [22_000, 89_450, 190_750, 364_200, 462_500, 693_750, Float::INFINITY]
            on  separate, [11_000, 44_725, 95_375, 182_100, 231_250, 346_875, Float::INFINITY]
            on  hoh,      [15_700, 59_850, 95_350, 193_350, 244_050, 609_350, Float::INFINITY]
          end

          value :fed_rates, [0.10, 0.12, 0.22, 0.24, 0.32, 0.35, 0.37]
          value :fed_calc,
                fn(:piecewise_sum, taxable_income, fed_breaks, fed_rates)

          value :fed_tax,       fed_calc[0]
          value :fed_marginal,  fed_calc[1]
          value :fed_eff,       fed_tax / fn(:max, [input.income, 1.0])

          value :ss_wage_base, 168_600.0
          value :ss_rate,      0.062

          value :med_base_rate, 0.0145
          value :addl_med_rate, 0.009

          value :addl_threshold do
            on  single,   200_000
            on  married,  250_000
            on  separate, 125_000
            base 200_000
          end

          value :ss_tax,
                fn(:min, [input.income, ss_wage_base]) * ss_rate

          value :med_tax, input.income * med_base_rate

          value :addl_med_tax,
                fn(:max, [input.income - addl_threshold, 0]) * addl_med_rate

          value :fica_tax,  ss_tax + med_tax + addl_med_tax
          value :fica_eff,  fica_tax / fn(:max, [input.income, 1.0])

          value :total_tax,
                fed_tax + fica_tax

          value :total_eff,   total_tax / fn(:max, [input.income, 1.0])
          value :after_tax,   input.income - total_tax
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for tax_2024_schema schema' do
        expect(Kumi::Parser::TextParser.valid?(tax_2024_schema)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure' do
        ruby_parsed = Tax2024Schema.__syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(tax_2024_schema)

        expect(text_parsed).to eq(ruby_parsed)
      end
    end

  end
end
