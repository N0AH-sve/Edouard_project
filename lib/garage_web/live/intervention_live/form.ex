defmodule GarageWeb.InterventionLive.Form do
  @moduledoc "Saisie d'une intervention."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Intervention

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} reglages={@reglages} titre={@page_title} actif={:interventions}>
      <:onglets>
        <Layouts.onglet navigate={~p"/interventions"} icone="hero-wrench-screwdriver" actif>
          {@page_title}
        </Layouts.onglet>
      </:onglets>

      <.form for={@form} id="formulaire-intervention" phx-change="valider" phx-submit="enregistrer">
        <div class="space-y-6 p-6">
          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Véhicule et date</h2>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-2">
              <.input
                field={@form[:vehicule_id]}
                type="select"
                label="Véhicule"
                prompt="Choisir un véhicule"
                options={@vehicules}
                required
              />
              <.input field={@form[:date]} type="date" label="Date" required />
            </div>
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Intervention</h2>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-3">
              <.input
                field={@form[:type]}
                type="select"
                label="Type"
                options={Intervention.types()}
                required
              />
              <.input field={@form[:kilometrage]} type="number" label="Kilométrage relevé" />
              <.input
                field={@form[:statut]}
                type="select"
                label="Statut"
                options={Intervention.statuts()}
                required
              />
            </div>
            <.input field={@form[:description]} type="textarea" label="Description" rows="3" />
            <.input
              field={@form[:pieces]}
              type="textarea"
              label="Pièces utilisées"
              rows="2"
              placeholder="Filtre à huile, 5 L d'huile 5W30…"
            />
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Montant</h2>
            <div class="sm:max-w-xs">
              <.input
                field={@form[:montant_euros]}
                type="text"
                label="Montant TTC (€)"
                placeholder="149,90"
              />
            </div>
            <p class="text-xs text-base-content/50">
              Virgule ou point acceptés. Le montant est conservé au centime près.
            </p>
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
            {if @live_action == :new, do: "Créer l'intervention", else: "Enregistrer"}
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
     |> assign(:vehicules, Atelier.options_vehicules())
     |> appliquer(socket.assigns.live_action, params)}
  end

  defp appliquer(socket, :new, params) do
    intervention = %Intervention{
      vehicule_id: entier(params["vehicule"]),
      date: Date.utc_today(),
      statut: :devis
    }

    socket
    |> assign(:page_title, "Nouvelle intervention")
    |> assign(:intervention, intervention)
    |> assign(:annulation, annulation(params["vehicule"]))
    |> assign(:form, to_form(Atelier.change_intervention(intervention)))
  end

  defp appliquer(socket, :edit, %{"id" => id}) do
    intervention = Atelier.get_intervention!(id)

    # Le champ virtuel est rempli depuis les centimes stockés, sinon le
    # formulaire s'ouvrirait avec un montant vide.
    changeset =
      Atelier.change_intervention(intervention, %{
        "montant_euros" => euros(intervention.montant_centimes)
      })

    socket
    |> assign(:page_title, "Intervention du #{Calendar.strftime(intervention.date, "%d/%m/%Y")}")
    |> assign(:intervention, intervention)
    |> assign(:annulation, ~p"/interventions/#{intervention}")
    |> assign(:form, to_form(changeset))
  end

  defp annulation(nil), do: ~p"/interventions"
  defp annulation(vehicule_id), do: ~p"/vehicules/#{vehicule_id}"

  defp euros(nil), do: ""

  defp euros(centimes) do
    centimes
    |> Kernel./(100)
    |> :erlang.float_to_binary(decimals: 2)
    |> String.replace(".", ",")
  end

  defp entier(nil), do: nil

  defp entier(valeur) do
    case Integer.parse(valeur) do
      {n, ""} -> n
      _ -> nil
    end
  end

  @impl true
  def handle_event("valider", %{"intervention" => params}, socket) do
    changeset = Atelier.change_intervention(socket.assigns.intervention, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("enregistrer", %{"intervention" => params}, socket) do
    enregistrer(socket, socket.assigns.live_action, params)
  end

  defp enregistrer(socket, :new, params) do
    case Atelier.create_intervention(params) do
      {:ok, intervention} ->
        {:noreply,
         socket
         |> put_flash(:info, "Intervention enregistrée.")
         |> push_navigate(to: ~p"/interventions/#{intervention}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp enregistrer(socket, :edit, params) do
    case Atelier.update_intervention(socket.assigns.intervention, params) do
      {:ok, intervention} ->
        {:noreply,
         socket
         |> put_flash(:info, "Intervention enregistrée.")
         |> push_navigate(to: ~p"/interventions/#{intervention}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end
end
