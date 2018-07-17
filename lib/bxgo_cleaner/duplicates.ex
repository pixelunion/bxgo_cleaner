defmodule BXGOCleaner.Duplicates do
  @moduledoc """
  Documentation for BXGOCleaner.
  """

  @output_headers [
    "BXGO status",
    "USO status",
    "slug",
    "email",
    "shopify_id",
    "shopify_plan_display_name",
    "shopify_plan_name"
  ]

  @doc """
  Hello world.

  ## Examples

      iex> BXGOCleaner.Duplicates.hello
      :world

  """
  def hello do
    file = File.open!("duplicate-customers.csv", [:write, :utf8])

    "~/Downloads/USO & BXGO Customers-2.csv"
    |> Path.expand()
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Stream.map(&check_recurring_charges/1)
    |> CSV.encode(headers: @output_headers)
    |> Enum.each(&IO.write(file, &1))

    File.close(file)
  end

  defp check_recurring_charges(row) do
    row
    |> check_uso_charges()
    |> check_bxgo_charges()
  end

  def check_uso_charges(%{"USO Access Token" => access_token, "slug" => slug} = row) do
    slug
    |> api_request(access_token)
    |> check_response()
    |> prepare_uso_row(row)
  end

  def check_bxgo_charges(%{"BXGO Access Token" => access_token, "slug" => slug} = row) do
    slug
    |> api_request(access_token)
    |> check_response()
    |> prepare_bxgo_row(row)
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

  defp prepare_uso_row(status, row) do
    Map.put_new(row, "USO status", status)
  end

  defp prepare_bxgo_row(status, row) do
    Map.put_new(row, "BXGO status", status)
  end
end
