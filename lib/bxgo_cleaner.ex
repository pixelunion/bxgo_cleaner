defmodule BXGOCleaner do
  @moduledoc """
  Documentation for BXGOCleaner.
  """

  @doc """
  Hello world.

  ## Examples

      iex> BXGOCleaner.hello
      :world

  """
  def hello do
    file = File.open!("test.csv", [:write, :utf8])

    "~/Downloads/BXGO Users.csv"
    |> Path.expand()
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Stream.map(&check_recurring_charge/1)
    |> CSV.encode(headers: ["Slug", "status"])
    |> Enum.each(&IO.write(file, &1))

    File.close(file)
  end

  defp check_recurring_charge(%{"BXGO Access Token" => access_token, "Slug" => slug} = row) do
    slug
    |> api_request(access_token)
    |> check_response()
    |> prepare_row(row)
  end

  defp api_request(slug, access_token) do
    HTTPoison.get!(
      "https://#{slug}.myshopify.com/admin/recurring_application_charges.json",
      [{"X-Shopify-Access-Token", access_token}]
    )
  end

  defp check_response(%HTTPoison.Response{status_code: 200, body: body}) do
    body
    |> Jason.decode!()
    |> Map.get("recurring_application_charges")
    |> Enum.any?(fn charge ->
      Map.get(charge, "status") == "active"
    end)
    |> (fn is_active ->
          case is_active do
            true -> "has active recurring charge"
            _ -> "no active charges"
          end
        end).()
  end

  defp check_response(%HTTPoison.Response{status_code: code, body: body}) when code != 200 do
    "response code #{code} - body: #{body}"
  end

  defp prepare_row(status, row) do
    Map.put_new(row, "status", status)
  end
end
