defmodule SelphiDynatable.Database do
  @moduledoc "Database interactions"
  import Ecto.Query
  alias SelphiDynatable.ParameterError
  alias SelphiDynatable.Validation

  # 单位秒
  @pre_1_hour       -3_600
  @next_1_hour       3_600
  @pre_1_day       -86_400
  @next_1_day       86_400
  @pre_7_day      -604_800
  @next_7_day      604_800
  @pre_30_day   -2_592_000
  @next_30_day   2_592_000
  @pre_1_year  -31_536_000
  @next_1_year   31_536_000


#  @support_ops ["==", "!=", "<=", ">=", "<", ">","in", "like","ilike", "between" ]

  @doc "Get the data using query"
  @spec get_records(map) :: [map]
  def get_records(%{query: query} = params) do
    query
    |> order_query(params)
#    |> search_query(params)
    |> filter_query(params)    # 过滤
    |> paginate_query(params)
    |> get_query(params)
  end
  # Repo.all
  @spec get_query(Ecto.Query.t(), map) :: [map]
  defp get_query(query, %{repo: repo})  do
    IO.puts "构造查询sql："
    IO.inspect query

    repo.all(query)
  end

  @spec order_query(Ecto.Query.t(), map) :: Ecto.Query.t()
  defp order_query(query, %{order: nil}), do: query

  defp order_query(query, %{order: order}) do
    from(q in exclude(query, :order_by), order_by: ^order)
#    from exclude(query, :order_by), order_by: ^order
  end

  @spec remove_order(Ecto.Query.t()) :: Ecto.Query.t()
  defp remove_order(query), do: exclude(query, :order_by)

  @spec order_query(Ecto.Query.t(), map) :: Ecto.Query.t()
  defp filter_query(query, %{filters: nil} ), do: query

  # 过滤条件校验失败，忽略该过滤条件
  defp filter_query(query, %{filters: filters} )  do
#    filter = [{:title, "eq", "Post  1"}, {:read_count, ">", 100}]

    query =  from q in  exclude(query, :where)

    Enum.reduce(filters, query , fn { field, op, value  },query  ->
      # 转化时间字符串，其它不受影响
      value = convert_time(value)
      case op do
        "==" ->
          case Validation.validate_value({field, op, value }) do
            true ->  from q in query, where: field(q, ^field) == ^value   #  value 为 string, integer,  float
            _ ->
              IO.puts "过滤条件校验失败，#{inspect {field, op, value } }"
              query
          end
        "!=" ->
          from q in query, where: field(q, ^field) != ^value  #  value 为 string, integer,  float
        "<=" ->
          from q in query, where: field(q, ^field) <= ^value  #  value 为 string, integer,  float
        ">=" ->
          from q in query, where: field(q, ^field) >= ^value   #  value 为 string,integer,  float
        "<" ->
          from q in query, where: field(q, ^field) < ^value    #  value 为 string, integer,  float
        ">" ->
          from q in query, where: field(q, ^field) > ^value    #  value 为  string, integer,  float
        "in" ->
          case Validation.validate_value({field, op, value }) do
            true -> from q in query, where: field(q, ^field) in ^value     #  value 为list, eg. [1,2,3],["hello","world"]
            _ ->
              IO.puts "过滤条件校验失败，#{inspect {field, op, value } }"
              query
          end

        "between" ->
          case Validation.validate_value({field, op, value }) do
            true ->
              v_start = Enum.at(value, 0)
              v_end  = Enum.at(value, 1)
              from q in query, where: field(q, ^field) >=  ^v_start and  field(q, ^field) <= ^v_end   # 此时value 为list [v_start, v_end] integer
            _ ->
              IO.puts "过滤条件校验失败，#{inspect {field, op, value } }"
              query
          end

        # 字符串专用, 这些操作 value ::  [string],
        #   构造  where     field ilike value1
        #                  and(or)  field ilike value2 查询
        "like" ->
          from q in query, where: like(field(q, ^field), ^value)   #  value 为 string eg. "Chapter%" "%Chapter%"
        "ilike_bgn" ->      # 以字符串str1 | str2 开始，  word%
           case length(value) > 1 do
             true ->
                IO.puts "ilike_bgn list value:  #{inspect value} "
                {first, rest } = List.pop_at(value, 0)
                first = first <> "%"
                query = from q in query, where: ilike(field(q, ^field), ^first)
                Enum.reduce(rest, query, fn v, query ->
                  v_str = v <> "%"
                  from q in query, or_where: ilike(field(q, ^field), ^v_str)
                end)
             _ ->
               IO.puts "ilike_bgn single value:  #{inspect value} "
                value = Enum.at(value, 0) <> "%"
                from q in query, where: ilike(field(q, ^field), ^value)  # value 为 string eg. "Chapter%" "%Chapter%"
           end
        "ilike_end" ->      # 以字符串str1 | str2开始，  word%
           case length(value) > 1 do
             true ->
                IO.puts "ilike_end list value:  #{inspect value} "
                {first, rest } = List.pop_at(value, 0)
                first = "%" <>  first
                query = from q in query, where: ilike(field(q, ^field), ^first)
                Enum.reduce(rest, query, fn v, query ->
                  v_str = "%" <>  v
                  from q in query, or_where: ilike(field(q, ^field), ^v_str)
                end)
             _ ->
               IO.puts "ilike_end single value:  #{inspect value} "
                value =  "%" <> Enum.at(value, 0)
                from q in query, where: ilike(field(q, ^field), ^value)  # value 为 string eg. "Chapter%" "%Chapter%"
           end
        "ilike_or" ->      # 包含字符串 str1 | str2
           case length(value) > 1 do
             true ->
                IO.puts "ilike_end list value:  #{inspect value} "
                {first, rest } = List.pop_at(value, 0)
                first = "%" <>  first <> "%"
                query = from q in query, where: ilike(field(q, ^field), ^first)
                Enum.reduce(rest, query, fn v, query ->
                  v_str = "%" <>  v <> "%"
                  from q in query, or_where: ilike(field(q, ^field), ^v_str)
                end)
             _ ->
               IO.puts "ilike_or single value:  #{inspect value} "
                value =  "%" <> Enum.at(value, 0) <> "%"
                from q in query, where: ilike(field(q, ^field), ^value)  # value 为 string eg. "Chapter%" "%Chapter%"
           end

        "ilike_and" ->      # 包含字符串 str1 & str2
                IO.puts "ilike_and list value:  #{inspect value} "
                Enum.reduce(value, query, fn v, query ->
                  v_str = "%" <>  v <> "%"
                  from q in query, where: ilike(field(q, ^field), ^v_str)
                end)
        # 时间专有选项, 字段必须是 datetime 类型
        "<1h" ->             # 前一小时: 1小时前 - 选择时间
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
            pre_1_hour =  NaiveDateTime.add(naive, @pre_1_hour )
            from q in query, where: field(q, ^field) >=  ^pre_1_hour and  field(q, ^field) <= ^naive
        ">1h" ->             # 后一小时: 从选择时间 - 1小时后
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
            next_1_hour =  NaiveDateTime.add(naive, @next_1_hour )
            from q in query, where: field(q, ^field) >=  ^naive and  field(q, ^field) <= ^next_1_hour
        "<1d" ->             # 前一天: 1天前 - 选择时间
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
              pre_1_day =  NaiveDateTime.add(naive, @pre_1_day )
            from q in query, where: field(q, ^field) >=  ^pre_1_day and  field(q, ^field) <= ^naive
        ">1d" ->             # 后一天: 从选择时间 - 1天后
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
            next_1_day =  NaiveDateTime.add(naive, @next_1_day )
            from q in query, where: field(q, ^field) >=  ^naive and  field(q, ^field) <= ^next_1_day
        "<7d" ->             # 前7天: 7天前 - 选择时间
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
              pre_7_day =  NaiveDateTime.add(naive, @pre_7_day )
            from q in query, where: field(q, ^field) >=  ^pre_7_day and  field(q, ^field) <= ^naive
        ">7d" ->             # 后7天: 从选择时间 - 7天后
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
            next_7_day =  NaiveDateTime.add(naive, @next_7_day )
            from q in query, where: field(q, ^field) >=  ^naive and  field(q, ^field) <= ^next_7_day
        "<30d" ->             # 前30天: 30天前 - 选择时间
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
              pre_30_day =  NaiveDateTime.add(naive, @pre_30_day )
            from q in query, where: field(q, ^field) >=  ^pre_30_day and  field(q, ^field) <= ^naive
        ">30d" ->             # 后30天: 从选择时间 - 30天后
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
            next_30_day =  NaiveDateTime.add(naive, @next_30_day )
            from q in query, where: field(q, ^field) >=  ^naive and  field(q, ^field) <= ^next_30_day
        "<1y" ->             # 前1年: 1年前 - 选择时间
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
            pre_1_year =  NaiveDateTime.add(naive, @pre_1_year )
            from q in query, where: field(q, ^field) >=  ^pre_1_year and  field(q, ^field) <= ^naive
        ">1y" ->             # 后1年: 从选择时间 - 1年后
            {:ok, naive }  =  NaiveDateTime.from_iso8601(value)
            next_1_year =  NaiveDateTime.add(naive, @next_1_year )
            from q in query, where: field(q, ^field) >=  ^naive and  field(q, ^field) <= ^next_1_year
        # 日期专用，和 时间专用的区别是，字段可以是 日期，日期时间。
        # 需要把字段值首先转化为日期，然后进行比较 pgsql 使用 to_char()函数，mysql使用 date_format()函数
        "d==" ->             # 于
            # pgsql
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) ==  ^value
            # mysql
#            from q in query, where: fragment("date_format(?, '%Y-%m-%d')" , field(q, ^field) ) >=  ^value
        "d>" ->             #  晚于
            # pgsql
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >  ^value
        "d<" ->             #  早于
            # pgsql
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <  ^value
        "d<7d" ->             #  前7天,  包含所选 日期
            # pgsql
            {:ok, select_date } = Date.from_iso8601(value)
            pre_7_day = Date.add(select_date, -7)
            str_pre_7_day = Date.to_iso8601(pre_7_day)  # 数据库需要 value 为字符串
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >=  ^str_pre_7_day
                                    and fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <=  ^value
        "d>7d" ->             #  后7天,  包含所选 日期
            # pgsql
            {:ok, select_date } = Date.from_iso8601(value)
            next_7_day = Date.add(select_date, 7)
            str_next_7_day = Date.to_iso8601(next_7_day)  # 数据库需要 value 为字符串
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <=  ^str_next_7_day
                                    and fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >=  ^value
        "d<30d" ->             #  前30天,  包含所选 日期
            # pgsql
            {:ok, select_date } = Date.from_iso8601(value)
            pre_30_day = Date.add(select_date, -30)
            str_pre_30_day = Date.to_iso8601(pre_30_day)  # 数据库需要 value 为字符串
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >=  ^str_pre_30_day
                                    and fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <=  ^value
        "d>30d" ->             #  后70天,  包含所选 日期
            # pgsql
            {:ok, select_date } = Date.from_iso8601(value)
            next_30_day = Date.add(select_date, 30)
            str_next_30_day = Date.to_iso8601(next_30_day)  # 数据库需要 value 为字符串
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <=  ^str_next_30_day
                                    and fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >=  ^value
        "d<1y" ->             #  前1年,  包含所选 日期
            # pgsql
            {:ok, select_date } = Date.from_iso8601(value)
            pre_1_year = Date.add(select_date, -365)
            str_pre_1_year = Date.to_iso8601(pre_1_year)  # 数据库需要 value 为字符串
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >=  ^str_pre_1_year
                                    and fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <=  ^value
        "d>1y" ->             #  后1年,  包含所选 日期
            # pgsql
            {:ok, select_date } = Date.from_iso8601(value)
            next_1_year = Date.add(select_date, 365)
            str_next_1_year = Date.to_iso8601(next_1_year)  # 数据库需要 value 为字符串
            from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <=  ^str_next_1_year
                                    and fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >=  ^value
        # 日期范围
        "d-between" ->  # value 为list
             IO.puts "date-range value: #{inspect value}"
             value =  Enum.sort(value, :asc)
             case Enum.at(value, 0) do
                "" -> query     # 范围的两个参数没有填完，忽略
                _  ->
                   range_start  =  Enum.at(value, 0)
                   range_end  =  Enum.at(value, 1)
                   from q in query, where: fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) >=  ^range_start
                      and fragment("to_char(?, 'yyyy-MM-dd')" , field(q, ^field) ) <=  ^range_end
             end
        # 日期范围
        "dt-between" ->  # value 为list
             IO.puts "datetime-range value: #{inspect value}"
             value =  Enum.sort(value, :asc)
             case Enum.at(value, 0) do
                "" -> query     # 范围的两个参数没有填完，忽略
                _  ->
                   range_start  =  Enum.at(value, 0)
                   range_end  =  Enum.at(value, 1)
                   from q in query, where:  field(q, ^field)  >=  ^range_start
                      and  field(q, ^field)  <=  ^range_end
             end

        _ ->
         IO.puts "not suportted  op!!"
         raise Dynatable.OpError, field: field, op: op, value: value
      end

    end)


#    from q in exclude(query, :where), where: field(q, ^field ) == ^value
#    from   exclude(query, :where), where:  ^conditions

  end

  # 替换过滤条件中 [{:inserted_at, ">", "2022-03-31T08:45:22"}] 时间字符串 T 为 空格 ，
  # 否则时间比较不对
  defp convert_time(value) do
    case  is_list(value) do
      true ->  Enum.map(value, &correct_time_format(&1))
      _ ->  correct_time_format(value)
    end
  end
  #  修正时间格式
  # 前端上报时间，当为0秒时，上报"2022-04-01T09:00" 是不合格的 NaiveDateTime，
  defp  correct_time_format(value) do
    case String.contains?(value,"T") do
      true ->
        case String.length(value) == 19 do
          true -> String.replace(value, "T", " ")
          _ ->   String.replace(value, "T", " ") <>":00"
        end
      _ -> value
    end
  end


  @spec paginate_query(Ecto.Query.t(), map) :: Ecto.Query.t()
  defp paginate_query(query, %{per_page: per_page, page: 1}) do
    from(q in query, limit: ^per_page)
#    from  query, limit: ^per_page
  end

  defp paginate_query(query, %{per_page: per_page, page: page}) do
    offset = (page - 1) * per_page
    from(q in query, limit: ^per_page, offset: ^offset)
#    from  query, limit: ^per_page, offset: ^offset
  end

  @doc "I want to just do a select: count(c.id)"
  @spec get_record_count(map) :: integer
  def get_record_count(%{query: query} = params) do
    query
    |> select_ids()
#    |> search_query(params)
    |> filter_query(params)
    |> remove_order()
    |>  get_query(params)   # [3]
    |> List.first()
  end

  # Filter out the previous selects and preloads, because we only need the ids to get a count
  @spec select_ids(Ecto.Query.t()) :: Ecto.Query.t()
  defp select_ids(query) do
    query =
      query
      |> exclude(:select)
      |> exclude(:preload)

    from(q in query, select: count(q.id))
#    from  query, select: count()
  end


  # \w: 匹配单词字符,匹配字母、数字、下划线。等价于 [A-Za-z0-9_]
  # \s: 匹配空白字符。等价于 [\t\n\r\f]。 \s+ 匹配任意多个空白。
  #         eg. String.replace("wang    qing",~r/\s+/u, ":* & ") == "wang:* & qing"
  # [^...] : 匹配不在方框内的任意字符, eg. [^\w\s], String.replace("wang@*!'",~r/[^\w\s]|_/u, "") == "wang"
  #
  #  Database.prefix_search("wang @_     qing") == "wang:* & qing:*"
  @doc "We only want letters to avoid SQL injection attacks"
  @spec prefix_search(String.t()) :: String.t()
  def prefix_search(terms) do
    terms
    |> String.trim()
    |> String.replace(~r/[^\w\s]|_/u, "")  # 不是字母、数字、下划线、空白的 特殊字符，删除
    |> String.replace(~r/\s+/u, ":* & ")   # 任意连续空白，替换为 ':* & '
    |> Kernel.<>(":*")
  end




end