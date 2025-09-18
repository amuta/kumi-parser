schema do
  input do
    string :name
    string :state
  end

  value :data, {
    key_name: input.name,
    key_state: input.state
  }
end
