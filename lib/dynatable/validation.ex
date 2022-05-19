defmodule SelphiDynatable.Validation do



  @doc """
  校验成功返回true
  """
  @spec validate_value(tuple) :: boolean
  def validate_value({field, "between", value}) do
#    ( is_list(value) && length(value) == 2 ) || raise Dynatable.ValueError, field: field, op: "between", value: value , message: "value不是list错误, 或个数不为2"
     is_list(value) && length(value) == 2
  end
  def validate_value({field, "in", value}) do
#    is_list(value) || raise Dynatable.ValueError, field: field, op: "in", value: value , message: "value不是list错误"
    is_list(value)
  end
  def validate_value({field, "==", value}) do
#    is_binary(value) ||  is_number(value)  || raise Dynatable.ValueError, field: field, op: "==", value: value , message: "value不是字符串或数字错误"
    is_binary(value) ||  is_number(value)
  end


end