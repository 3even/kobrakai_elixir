defmodule KobrakaiWeb.OneToManyForm do
  use KobrakaiWeb, :live_view
  alias KobrakaiWeb.OneToManyForm.GroceriesList

  @impl true
  def render(assigns) do
    ~H"""
    <.simple_form :let={form} id={@id} for={@form} phx-change="validate" phx-submit="submit" as="form">
      <.input field={form[:email]} label="Email" />
      <fieldset class="flex flex-col gap-2">
        <legend>Groceries</legend>
        <.inputs_for :let={f_line} field={form[:lines]}>
          <.line f={f_line} />
        </.inputs_for>
        <.button class="mt-2" type="button" phx-click="add-line">Add</.button>
      </fieldset>

      <:actions>
        <.button>Save</.button>
      </:actions>
    </.simple_form>

    <details id="static" class="mt-4">
      <summary>Open to see saved value</summary>
      <.base base={@base} inspect />
    </details>
    """
  end

  defp line(assigns) do
    assigns =
      assigns
      |> assign(:deleted, Phoenix.HTML.Form.input_value(assigns.f, :delete) == true)

    ~H"""
    <div class={if(@deleted, do: "opacity-50")}>
      <input
        type="hidden"
        name={Phoenix.HTML.Form.input_name(@f, :delete)}
        value={to_string(Phoenix.HTML.Form.input_value(@f, :delete))}
      />
      <div class="flex gap-4 items-end">
        <div class="grow">
          <.input class="mt-0" field={@f[:item]} readonly={@deleted} label="Item" />
        </div>
        <div class="grow">
          <.input class="mt-0" field={@f[:amount]} type="number" readonly={@deleted} label="Amount" />
        </div>
        <.button
          class="grow-0"
          type="button"
          phx-click="delete-line"
          phx-value-index={@f.index}
          disabled={@deleted}
        >
          Delete
        </.button>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_, _, socket) do
    base = %GroceriesList{
      id: "4e4d0944-60b3-4a09-a075-008a94ce9b9e",
      email: "friend@example.com",
      lines: [
        %GroceriesList.Line{
          id: "26d59961-3b19-4602-b40c-77a0703cedb5",
          item: "Melon",
          amount: 1
        },
        %GroceriesList.Line{
          id: "330a8f72-3fb1-4352-acf2-d871803cd152",
          item: "Grapes",
          amount: 3
        }
      ]
    }

    {:ok, init(socket, base), layout: false}
  end

  @impl true

  def handle_event("add-line", _, socket) do
    socket =
      update(socket, :form, fn %{source: changeset} ->
        existing = Ecto.Changeset.get_embed(changeset, :lines)
        changeset = Ecto.Changeset.put_embed(changeset, :lines, existing ++ [%{}])
        to_form(changeset)
      end)

    {:noreply, socket}
  end

  def handle_event("delete-line", %{"index" => index}, socket) do
    index = String.to_integer(index)

    socket =
      update(socket, :form, fn %{source: changeset} ->
        existing = Ecto.Changeset.get_embed(changeset, :lines)
        {to_delete, rest} = List.pop_at(existing, index)

        lines =
          if Ecto.Changeset.change(to_delete).data.id do
            List.replace_at(existing, index, Ecto.Changeset.change(to_delete, delete: true))
          else
            rest
          end

        changeset
        |> Ecto.Changeset.put_embed(:lines, lines)
        |> to_form()
      end)

    {:noreply, socket}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    changeset =
      socket.assigns.base
      |> GroceriesList.changeset(params)
      |> struct!(action: :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    changeset = GroceriesList.changeset(socket.assigns.base, params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, data} ->
        socket = put_flash(socket, :info, "Submitted successfully")
        {:noreply, init(socket, data)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp init(socket, base) do
    base = autogenerate_missing_ids(base)
    changeset = GroceriesList.changeset(base, %{})

    assign(socket,
      base: base,
      form: to_form(changeset),
      id: "form-#{System.unique_integer()}"
    )
  end

  defp autogenerate_missing_ids(%mod{} = schema) do
    schema =
      Enum.reduce(mod.__schema__(:embeds), schema, fn field, schema ->
        Map.update!(schema, field, fn
          list when is_list(list) -> Enum.map(list, &autogenerate_missing_ids/1)
          value -> autogenerate_missing_ids(value)
        end)
      end)

    {field, _source, :binary_id} = mod.__schema__(:autogenerate_id)

    Map.update!(schema, field, fn
      nil -> Ecto.UUID.generate()
      id -> id
    end)
  end
end
