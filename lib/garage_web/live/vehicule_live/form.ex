defmodule GarageWeb.VehiculeLive.Form do
  @moduledoc "Création et modification d'un véhicule."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Vehicule

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} reglages={@reglages} titre={@page_title} actif={:vehicules}>
      <:onglets>
        <Layouts.onglet navigate={~p"/vehicules"} icone="hero-truck" actif>
          {@page_title}
        </Layouts.onglet>
      </:onglets>

      <.form for={@form} id="formulaire-vehicule" phx-change="valider" phx-submit="enregistrer">
        <div class="space-y-6 p-6">
          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Identification</h2>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-2">
              <.input
                field={@form[:immatriculation]}
                type="text"
                label="Immatriculation"
                placeholder="AB-123-CD"
                required
              />
              <.input
                field={@form[:client_id]}
                type="select"
                label="Propriétaire"
                prompt="Choisir un client"
                options={@clients}
                required
              />
            </div>
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Caractéristiques</h2>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-2">
              <.input field={@form[:marque]} type="text" label="Marque" placeholder="Renault" />
              <.input field={@form[:modele]} type="text" label="Modèle" placeholder="Clio IV" />
            </div>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-3">
              <.input field={@form[:annee]} type="number" label="Année" />
              <.input
                field={@form[:carburant]}
                type="select"
                label="Carburant"
                prompt="—"
                options={Vehicule.carburants()}
              />
              <.input field={@form[:kilometrage]} type="number" label="Kilométrage" />
            </div>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-2">
              <.input field={@form[:vin]} type="text" label="VIN (17 caractères)" />
              <.input
                field={@form[:date_prochain_ct]}
                type="date"
                label="Prochain contrôle technique"
              />
            </div>
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Remarques</h2>
            <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
          </section>
        </div>

        <footer class="flex items-center justify-end gap-3 border-t border-base-300 px-6 py-4">
          <.link
            navigate={@annulation}
            class="rounded-full px-5 py-2.5 text-sm font-medium text-base-content/60 hover:bg-base-200"
          >
            Annuler
          </.link>
          <button
            type="submit"
            phx-disable-with="Enregistrement…"
            class="rounded-full bg-primary px-6 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
          >
            {if @live_action == :new, do: "Créer le véhicule", else: "Enregistrer"}
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
     |> assign(:clients, Atelier.options_clients())
     |> appliquer(socket.assigns.live_action, params)}
  end

  defp appliquer(socket, :new, params) do
    # Arrivée depuis la fiche d'un client : le propriétaire est pré-rempli.
    vehicule = %Vehicule{client_id: entier(params["client"])}

    socket
    |> assign(:page_title, "Nouveau véhicule")
    |> assign(:vehicule, vehicule)
    |> assign(:annulation, annulation(params["client"]))
    |> assign(:form, to_form(Atelier.change_vehicule(vehicule)))
  end

  defp appliquer(socket, :edit, %{"id" => id}) do
    vehicule = Atelier.get_vehicule!(id)

    socket
    |> assign(:page_title, vehicule.immatriculation)
    |> assign(:vehicule, vehicule)
    |> assign(:annulation, ~p"/vehicules/#{vehicule}")
    |> assign(:form, to_form(Atelier.change_vehicule(vehicule)))
  end

  defp annulation(nil), do: ~p"/vehicules"
  defp annulation(client_id), do: ~p"/clients/#{client_id}"

  defp entier(nil), do: nil

  defp entier(valeur) do
    case Integer.parse(valeur) do
      {n, ""} -> n
      _ -> nil
    end
  end

  @impl true
  def handle_event("valider", %{"vehicule" => params}, socket) do
    changeset = Atelier.change_vehicule(socket.assigns.vehicule, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("enregistrer", %{"vehicule" => params}, socket) do
    enregistrer(socket, socket.assigns.live_action, params)
  end

  defp enregistrer(socket, :new, params) do
    case Atelier.create_vehicule(params) do
      {:ok, vehicule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Véhicule #{vehicule.immatriculation} enregistré.")
         |> push_navigate(to: ~p"/vehicules/#{vehicule}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp enregistrer(socket, :edit, params) do
    case Atelier.update_vehicule(socket.assigns.vehicule, params) do
      {:ok, vehicule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Véhicule enregistré.")
         |> push_navigate(to: ~p"/vehicules/#{vehicule}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end
end
