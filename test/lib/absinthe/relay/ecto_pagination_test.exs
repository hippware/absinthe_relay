defmodule Absinthe.Relay.Foo do
  use Ecto.Schema

  schema "foos" do
    field :index, :integer
  end
end

defmodule Absinthe.Relay.EctoPaginationTest do

  use Absinthe.Relay.Case, async: true

  alias Absinthe.Relay.Foo
  alias Absinthe.Relay.Repo

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :classic
    import Ecto.Query

    node object :foo do
      field :index, non_null(:integer)
    end

    query do
      connection field :foos, node_type: :foo do
        resolve fn pagination_args, _ ->
          Foo
          |> order_by(asc: :id)
          |> Absinthe.Relay.Connection.from_query(&Repo.all/1, pagination_args)
        end
      end

      node field do
        resolve fn %{type: :foo, id: id}, _ ->
          {:ok, Relay.Repo.get(Foo, id)}
        end
      end
    end

    node interface do
      resolve_type fn _, _ -> :foo end
    end

    connection node_type: :foo

  end

  setup_all do
    [:poolboy, :decimal, :connection, :db_connection, :postgrex, :ecto]
    |> Enum.each(fn app -> :ok = Application.start(app) end)

    {:ok, _pid} = start_supervised(Repo)

    Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)

    Repo.delete_all(Foo)
    Enum.map(0..9, &Repo.insert(%Foo{id: &1, index: &1}))

    :ok
  end

  test "It handles forward pagination correctly" do
    query = """
    query FirstSupportingNullAfter($first: Int!) {
      foos(first: $first, after: null) {
        page_info {
          start_cursor
          end_cursor
          has_previous_page
          has_next_page
        }
        edges {
          cursor
          node {
            index
          }
        }
      }
    }
    """
    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"first" => 3})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => cursor0,
        "end_cursor" => cursor2,
        "has_previous_page" => false,
        "has_next_page" => true,
      },
      "edges" => [
        %{
          "cursor" => cursor0,
          "node" => %{"index" => 0},
        },
        %{
          "cursor" => cursor1,
          "node" => %{"index" => 1},
        },
        %{
          "cursor" => cursor2,
          "node" => %{"index" => 2},
        },
      ],
    }} = result


    query = """
    query firstSupportingNonNullAfter($first: Int!, $after: ID!) {
      foos(first: $first, after: $after) {
        page_info {
          start_cursor
          end_cursor
          has_previous_page
          has_next_page
        }
        edges {
          cursor
          node {
            index
          }
        }
      }
    }
    """
    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"first" => 3, "after" => cursor1})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => ^cursor2,
        "end_cursor" => cursor4,
        "has_previous_page" => false,
        "has_next_page" => true,
      },
      "edges" => [
        %{
          "cursor" => ^cursor2,
          "node" => %{"index" => 2},
        },
        %{
          "cursor" => _cursor3,
          "node" => %{"index" => 3},
        },
        %{
          "cursor" => cursor4,
          "node" => %{"index" => 4},
        },
      ],
    }} = result


    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"first" => 100, "after" => cursor4})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => cursor5,
        "end_cursor" => cursor9,
        "has_previous_page" => false,
        "has_next_page" => false,
      },
      "edges" => [
        %{
          "cursor" => cursor5,
          "node" => %{"index" => 5},
        },
        %{
          "cursor" => _cursor6,
          "node" => %{"index" => 6},
        },
        %{
          "cursor" => _cursor7,
          "node" => %{"index" => 7},
        },
        %{
          "cursor" => _cursor8,
          "node" => %{"index" => 8},
        },
        %{
          "cursor" => cursor9,
          "node" => %{"index" => 9},
        },
      ],
    }} = result

    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"first" => 100, "after" => cursor9})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => nil,
        "end_cursor" => nil,
        "has_previous_page" => false,
        "has_next_page" => false,
      },
      "edges" => [],
    }} = result
  end


  test "It handles backward pagination correctly" do
    query = """
    query LastSupportingNullBefore($last: Int!) {
      foos(last: $last, before: null) {
        page_info {
          start_cursor
          end_cursor
          has_previous_page
          has_next_page
        }
        edges {
          cursor
          node {
            index
          }
        }
      }
    }
    """
    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"last" => 3})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => cursor7,
        "end_cursor" => cursor9,
        "has_previous_page" => true,
        "has_next_page" => false,
      },
      "edges" => [
        %{
          "cursor" => cursor7,
          "node" => %{"index" => 7},
        },
        %{
          "cursor" => cursor8,
          "node" => %{"index" => 8},
        },
        %{
          "cursor" => cursor9,
          "node" => %{"index" => 9},
        },
      ],
    }} = result


    query = """
    query LastSupportingNonNullBefore($last: Int!, $before: ID!) {
      foos(last: $last, before: $before) {
        page_info {
          start_cursor
          end_cursor
          has_previous_page
          has_next_page
        }
        edges {
          cursor
          node {
            index
          }
        }
      }
    }
    """
    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"last" => 3, "before" => cursor8})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => cursor5,
        "end_cursor" => ^cursor7,
        "has_previous_page" => true,
        "has_next_page" => false,
      },
      "edges" => [
        %{
          "cursor" => cursor5,
          "node" => %{"index" => 5},
        },
        %{
          "cursor" => _cursor6,
          "node" => %{"index" => 6},
        },
        %{
          "cursor" => ^cursor7,
          "node" => %{"index" => 7},
        },
      ],
    }} = result


    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"last" => 100, "before" => cursor5})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => cursor0,
        "end_cursor" => cursor4,
        "has_previous_page" => false,
        "has_next_page" => false,
      },
      "edges" => [
        %{
          "cursor" => cursor0,
          "node" => %{"index" => 0},
        },
        %{
          "cursor" => _cursor1,
          "node" => %{"index" => 1},
        },
        %{
          "cursor" => _cursor2,
          "node" => %{"index" => 2},
        },
        %{
          "cursor" => _cursor3,
          "node" => %{"index" => 3},
        },
        %{
          "cursor" => cursor4,
          "node" => %{"index" => 4},
        },
      ],
    }} = result

    assert {:ok, %{data: result}} = Absinthe.run(query, Schema, variables: %{"last" => 100, "before" => cursor0})

    assert %{"foos" => %{
      "page_info" => %{
        "start_cursor" => nil,
        "end_cursor" => nil,
        "has_previous_page" => false,
        "has_next_page" => false,
      },
      "edges" => [],
    }} = result
  end

  test "It returns an error if pagination parameters are missing" do
    query = """
    {
      foos {
        page_info {
          start_cursor
          end_cursor
          has_previous_page
          has_next_page
        }
        edges {
          cursor
          node {
            index
          }
        }
      }
    }
    """
    assert {:ok, result} = Absinthe.run(query, Schema)
    assert %{data: %{},
        errors: [%{locations: [%{column: 0, line: 2}],
                   message: "You must either supply `:first` or `:last`"}]}
      = result

 end

end
