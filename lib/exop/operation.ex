defmodule Exop.Operation do
  @moduledoc """
  Provides macros for an operation's contract definition and process/1 function.

  ## Example

      defmodule SomeOperation do
        use Exop.Operation

        parameter :param1, type: :integer, required: true
        parameter :param2, type: :string, length: %{max: 3}, format: ~r/foo/

        def process(params) do
          "This is the operation's result with one of the params = " <> params[:param1]
        end
      end
  """

  alias Exop.Validation

  @callback process(Keyword.t | Map.t) :: any

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :contract, accumulate: true)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias Exop.Validation

      @spec contract :: list(Map.t)
      def contract do
        @contract
      end

      @doc """
      Runs an operation's process/1 function after a contract's validation
      """
      @spec run(Keyword.t | Map.t) :: Validation.validation_error | any
      @spec run :: Validation.validation_error | any
      def run(received_params \\ []) do
        params = resolve_defaults(@contract, received_params, received_params)
        output(Validation.valid?(@contract, params), params)
      end

      @spec resolve_defaults(list(%{name: atom, opts: Keyword.t}), Keyword.t | Map.t, Keyword.t | Map.t) :: Keyword.t | Map.t
      defp resolve_defaults([], _received_params, resolved_params), do: resolved_params
      defp resolve_defaults([%{name: contract_item_name, opts: contract_item_opts} | contract_tail], received_params, resolved_params) do
        resolved_params =
          if Keyword.has_key?(contract_item_opts, :default) &&
             Exop.ValidationChecks.get_check_item(received_params, contract_item_name) == nil do
               contract_item_opts |> Keyword.get(:default) |> put_into_collection(resolved_params, contract_item_name)
          else
            resolved_params
          end

        resolve_defaults(contract_tail, received_params, resolved_params)
      end

      @spec put_into_collection(any, Keyword.t | Map.t, atom) :: Keyword.t | Map.t
      defp put_into_collection(value, collection, item_name) when is_map(collection) do
        Map.put(collection, item_name, value)
      end
      defp put_into_collection(value, collection, item_name) when is_list(collection) do
        Keyword.put(collection, item_name, value)
      end
      defp put_into_collection(_value, collection, _item_name), do: collection

      @spec output(Map.t | :ok, Keyword.t | Map.t) :: Validation.validation_error | any
      defp output(validation_result = :ok, params), do: process(params)
      defp output(validation_result, _params), do: validation_result
    end
  end

  @spec parameter(atom, Keyword.t) :: none
  defmacro parameter(name, opts \\ []) when is_atom(name) do
    quote bind_quoted: [name: name, opts: opts] do
      @contract %{name: name, opts: opts}
    end
  end
end
