defmodule SelphiDynatable.OpError do
  defexception [:op, :message]

  @support_ops ["==", "!=", "<=", ">=", "<", ">","in", "like","ilike", "between", "d-between" ]

  def exception(opts) do
    field = Keyword.fetch!(opts, :field)
    op  = Keyword.fetch!(opts, :op)
    value   = Keyword.fetch!(opts, :value)
    message = "字段`#{inspect field}`，操作 `#{inspect op}` value: `#{inspect value}`，不支持的操作 `#{inspect op}`，可选操作  #{inspect  @support_ops}"
    %__MODULE__{message: message, op: op}
  end

end

defmodule SelphiDynatable.ValueError do
  defexception [:field, :op, :value, :message]

  def exception(opts) do
    field = Keyword.fetch!(opts, :field)
    op  = Keyword.fetch!(opts, :op)
    value   = Keyword.fetch!(opts, :value)
    msg   = Keyword.fetch!(opts, :message)
    message = "字段`#{inspect field}`，操作 `#{inspect op}` value: `#{inspect value}`，#{inspect msg}"
    %__MODULE__{message: message, field: field, op: op, value: value}
  end
end