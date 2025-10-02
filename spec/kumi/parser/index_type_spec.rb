# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Index Type Keyword Support' do
  describe 'basic index parsing' do
    let(:basic_index_text) do
      <<~KUMI
        schema do
          input do
            array :items do
              string :name
              index :position
            end
          end

          value :item_names, input.items.name
          value :item_positions, input.items.position
        end
      KUMI
    end

    it 'parses index declarations successfully' do
      expect { Kumi::Parser::TextParser.parse(basic_index_text) }.not_to raise_error
    end

    it 'validates as valid' do
      expect(Kumi::Parser::TextParser.valid?(basic_index_text)).to be true
    end

    it 'creates correct AST structure with index type' do
      ast = Kumi::Parser::TextParser.parse(basic_index_text)

      items = ast.inputs[0]
      expect(items.name).to eq(:items)
      expect(items.type).to eq(:array)
      expect(items.children.length).to eq(2)

      name_child = items.children[0]
      expect(name_child.name).to eq(:name)
      expect(name_child.type).to eq(:string)

      position_child = items.children[1]
      expect(position_child.name).to eq(:position)
      expect(position_child.type).to eq(:index)
    end

    it 'does not affect access_mode when mixed with fields' do
      ast = Kumi::Parser::TextParser.parse(basic_index_text)

      items = ast.inputs[0]
      expect(items.access_mode).to eq(:field)
    end
  end

  describe 'index with element syntax' do
    let(:index_with_element_text) do
      <<~KUMI
        schema do
          input do
            array :coordinates do
              element :float, :value
              index :idx
            end
          end

          value :coord_values, input.coordinates.value
          value :coord_indices, input.coordinates.idx
        end
      KUMI
    end

    it 'parses index alongside element declarations' do
      expect { Kumi::Parser::TextParser.parse(index_with_element_text) }.not_to raise_error
    end

    it 'validates as valid' do
      expect(Kumi::Parser::TextParser.valid?(index_with_element_text)).to be true
    end

    it 'creates correct AST structure' do
      ast = Kumi::Parser::TextParser.parse(index_with_element_text)

      coordinates = ast.inputs[0]
      expect(coordinates.name).to eq(:coordinates)
      expect(coordinates.type).to eq(:array)
      expect(coordinates.children.length).to eq(2)

      value_child = coordinates.children[0]
      expect(value_child.name).to eq(:value)
      expect(value_child.type).to eq(:float)

      idx_child = coordinates.children[1]
      expect(idx_child.name).to eq(:idx)
      expect(idx_child.type).to eq(:index)
    end

    it 'does not affect element access_mode' do
      ast = Kumi::Parser::TextParser.parse(index_with_element_text)

      coordinates = ast.inputs[0]
      expect(coordinates.access_mode).to eq(:element)
    end
  end

  describe 'nested arrays with indices' do
    let(:nested_index_text) do
      <<~KUMI
        schema do
          input do
            array :matrix do
              array :row do
                element :integer, :cell
                index :col_idx
              end
              index :row_idx
            end
          end

          value :cell_values, input.matrix.row.cell
          value :row_indices, input.matrix.row_idx
          value :col_indices, input.matrix.row.col_idx
        end
      KUMI
    end

    it 'parses nested arrays with indices at each level' do
      expect { Kumi::Parser::TextParser.parse(nested_index_text) }.not_to raise_error
    end

    it 'validates as valid' do
      expect(Kumi::Parser::TextParser.valid?(nested_index_text)).to be true
    end

    it 'creates correct nested structure with indices' do
      ast = Kumi::Parser::TextParser.parse(nested_index_text)

      matrix = ast.inputs[0]
      expect(matrix.name).to eq(:matrix)
      expect(matrix.type).to eq(:array)
      expect(matrix.children.length).to eq(2)

      row = matrix.children[0]
      expect(row.name).to eq(:row)
      expect(row.type).to eq(:array)
      expect(row.children.length).to eq(2)

      cell = row.children[0]
      expect(cell.name).to eq(:cell)
      expect(cell.type).to eq(:integer)

      col_idx = row.children[1]
      expect(col_idx.name).to eq(:col_idx)
      expect(col_idx.type).to eq(:index)

      row_idx = matrix.children[1]
      expect(row_idx.name).to eq(:row_idx)
      expect(row_idx.type).to eq(:index)
    end

    it 'maintains correct access_mode at each level' do
      ast = Kumi::Parser::TextParser.parse(nested_index_text)

      matrix = ast.inputs[0]
      expect(matrix.access_mode).to eq(:field)

      row = matrix.children[0]
      expect(row.access_mode).to eq(:element)
    end
  end

  describe 'practical example: paginated data with row/column indices' do
    let(:paginated_table_text) do
      <<~KUMI
        schema do
          input do
            array :pages do
              array :rows do
                string :name
                float :value
                boolean :active
                index :col_num
              end
              index :row_num
            end
          end

          value :all_names, input.pages.rows.name
          value :all_values, input.pages.rows.value
          value :active_flags, input.pages.rows.active
          value :row_numbers, input.pages.row_num
          value :col_numbers, input.pages.rows.col_num
        end
      KUMI
    end

    it 'parses complex table structure with indices' do
      expect { Kumi::Parser::TextParser.parse(paginated_table_text) }.not_to raise_error
    end

    it 'validates as valid' do
      expect(Kumi::Parser::TextParser.valid?(paginated_table_text)).to be true
    end

    it 'creates correct structure with multiple fields and indices' do
      ast = Kumi::Parser::TextParser.parse(paginated_table_text)

      pages = ast.inputs[0]
      expect(pages.name).to eq(:pages)
      expect(pages.children.length).to eq(2)

      rows = pages.children[0]
      expect(rows.name).to eq(:rows)
      expect(rows.children.length).to eq(4)

      fields = rows.children[0..2]
      expect(fields.map(&:name)).to eq([:name, :value, :active])
      expect(fields.map(&:type)).to eq([:string, :float, :boolean])

      col_num = rows.children[3]
      expect(col_num.name).to eq(:col_num)
      expect(col_num.type).to eq(:index)

      row_num = pages.children[1]
      expect(row_num.name).to eq(:row_num)
      expect(row_num.type).to eq(:index)
    end
  end

  describe 'error handling: mixing element and field syntax' do
    let(:mixed_without_index_text) do
      <<~KUMI
        schema do
          input do
            array :items do
              string :name
              element :integer, :value
            end
          end
        end
      KUMI
    end

    it 'raises error when mixing element and field without index' do
      expect {
        Kumi::Parser::TextParser.parse(mixed_without_index_text)
      }.to raise_error(Kumi::Errors::SyntaxError, /mixes.*element.*field/)
    end
  end
end
