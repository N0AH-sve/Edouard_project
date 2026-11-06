defmodule GarageWeb.ClientLive.Form do
  @moduledoc "Création et modification d'une fiche client."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Client

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} reglages={@reglages} titre={@page_title} actif={:clients}>
      <:onglets>
        <Layouts.onglet navigate={~p"/clients"} icone="hero-users" actif>
          {@page_title}
        </Layouts.onglet>
      </:onglets>

      <.form for={@form} id="formulaire-client" phx-change="valider" phx-submit="enregistrer">
        <div class="space-y-6 p-6">
          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Identité</h2>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-2">
              <.input field={@form[:nom]} type="text" label="Nom" required />
              <.input field={@form[:prenom]} type="text" label="Prénom" />
            </div>
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Contact</h2>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-2">
              <.input
                field={@form[:telephone]}
                type="tel"
                label="Téléphone"
                placeholder="06 12 34 56 78"
              />
              <.input field={@form[:email]} type="email" label="E-mail" />
            </div>
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Adresse</h2>
            <.input field={@form[:adresse]} type="textarea" label="Adresse" rows="2" />
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-3">
              <.input field={@form[:code_postal]} type="text" label="Code postal" placeholder="74000" />
              <div class="sm:col-span-2">
                <.input field={@form[:ville]} type="text" label="Ville" />
              </div>
            </div>
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Remarques</h2>
            <.input field={@form[:notes]} type="textarea" label="Notes internes" rows="3" />
          </section>
        </div>

        <footer class="flex items-center justify-end gap-3 border-t border-base-300 px-6 py-4">
          <.link
            navigate={retour(@retour_vers, @client)}
            class="rounded-full px-5 py-2.5 text-sm font-medium text-base-content/60 hover:bg-base-200"
          >
            Annuler
          </.link>
          <button
            type="submit"
            phx-disable-with="Enregistrement…"
            class="rounded-full bg-primary px-6 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
          >
            {if @live_action == :new, do: "Créer le client", else: "Enregistrer"}
          </button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:retour_vers, retour_vers(params["retour"]))
     |> appliquer(socket.assigns.live_action, params)}
  end

  defp retour_vers("fiche"), do: "fiche"
  defp retour_vers(_), do: "liste"

  defp appliquer(socket, :new, _params) do
    client = %Client{}

    socket
    |> assign(:page_title, "Nouveau client")
    |> assign(:client, client)
    |> assign(:form, to_form(Atelier.change_client(client)))
  end

  defp appliquer(socket, :edit, %{"id" => id}) do
    client = Atelier.get_client!(id)

    socket
    |> assign(:page_title, Client.nom_complet(client))
    |> assign(:client, client)
    |> assign(:form, to_form(Atelier.change_client(client)))
  end

  @impl true
  def handle_event("valider", %{"client" => params}, socket) do
    changeset = Atelier.change_client(socket.assigns.client, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("enregistrer", %{"client" => params}, socket) do
    enregistrer(socket, socket.assigns.live_action, params)
  end

  defp enregistrer(socket, :new, params) do
    case Atelier.create_client(params) do
      {:ok, client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client créé.")
         |> push_navigate(to: ~p"/clients/#{client}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp enregistrer(socket, :edit, params) do
    case Atelier.update_client(socket.assigns.client, params) do
      {:ok, client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Fiche enregistrée.")
         |> push_navigate(to: retour(socket.assigns.retour_vers, client))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp retour("fiche", %Client{id: id} = client) when not is_nil(id), do: ~p"/clients/#{client}"
  defp retour(_, _), do: ~p"/clients"
end
